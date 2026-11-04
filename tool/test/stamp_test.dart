import 'dart:io';

import 'package:test/test.dart';

import '../new_project/stamp.dart';
import '../workspace.dart';
import 'support.dart';

/// lints (root tooling), a <- b, c alone; the starter uses b.
List<PubPackage> fakePackages() => [
  PubPackage('skeleton_lints', 'packages/lints', {}),
  PubPackage('skeleton_a', 'packages/a', {}),
  PubPackage('skeleton_b', 'packages/b', {'skeleton_a'}),
  PubPackage('skeleton_c_d', 'packages/c_d', {}),
  PubPackage('starter', 'apps/starter', {'skeleton_b'}),
];

void main() {
  group('replaceOrFail', () {
    test('replaces every occurrence', () {
      expect(
        replaceOrFail('x.starter y.starter', 'starter', 'acme', 'f'),
        'x.acme y.acme',
      );
    });

    test('stops when the text to change is not there', () {
      expect(
        () => replaceOrFail(
          'nothing here',
          'com.example.starter',
          'a.b',
          'android/app/build.gradle.kts',
        ),
        throwsA(
          isA<StampError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('com.example.starter'),
              contains('build.gradle.kts'),
            ),
          ),
        ),
      );
    });
  });

  group('plan', () {
    test(
      'keeps what the starter needs and the root tooling, and drops the rest',
      () {
        expect(planKeep(fakePackages(), []).keep, ['a', 'b', 'lints']);
      },
    );

    test('a requested package comes with what it needs, and says why', () {
      final all = fakePackages()
        ..add(PubPackage('skeleton_e', 'packages/e', {'skeleton_c_d'}));
      final plan = planKeep(all, ['e']);
      expect(plan.keep, ['a', 'b', 'c-d', 'e', 'lints']);
      expect(plan.why['e'], 'requested');
      expect(plan.why['c-d'], contains('needed by e'));
    });

    test('an unknown package is an error that lists the valid ones', () {
      expect(
        () => planKeep(fakePackages(), ['nope']),
        throwsA(
          isA<StampError>().having(
            (e) => e.message,
            'message',
            allOf(contains('nope'), contains('c-d')),
          ),
        ),
      );
    });
  });

  test('applying to a tree without the files it must change stops instead of skipping', () {
    final target = Directory.systemTemp.createTempSync('stamp-test');
    addTearDown(() => target.deleteSync(recursive: true));
    writeTree(target, {
      'pubspec.yaml': 'name: ws\nworkspace:\n  - apps/starter\n',
      'apps/starter/pubspec.yaml': pubspec('starter'),
      'apps/starter/android/app/build.gradle.kts':
          'namespace = "something.else"\n',
    });
    expect(
      () => applyStamp(
        target,
        const StampOptions(name: 'acme', org: 'com.example', keep: []),
      ),
      throwsA(isA<StampError>()),
    );
  });
}
