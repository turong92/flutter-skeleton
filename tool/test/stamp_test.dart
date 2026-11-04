import 'dart:io';

import 'package:test/test.dart';

import '../build_capabilities.dart';
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

/// Every file applyStamp reads or rewrites, with only the text it looks for. Package a is
/// used by the starter, package b is not.
Map<String, String> fakeSkeleton() {
  const app = 'apps/starter';
  const plist = '<string>Starter</string>\n<string>starter</string>\n';
  final catalog = {
    r'$schema': 'docs/capabilities.schema.json',
    'schemaVersion': 1,
    'mode': 'skeleton',
    'name': 'fake-skeleton',
    'summary': 'A fake skeleton.',
    'capabilities': [
      entry('a'),
      entry('b'),
      entry(
        'app-starter',
        kind: 'app',
        package: 'starter',
        path: app,
        needs: ['a'],
        docs: ['$app/README.md'],
      ),
    ],
  };
  return {
    'pubspec.yaml': 'name: flutter_skeleton_workspace\ndescription: Root.\nworkspace:\n  - packages/a\n  - packages/b\n  - apps/starter\n  - tool\n',
    'packages/a/pubspec.yaml': pubspec('skeleton_a'),
    'packages/b/pubspec.yaml': pubspec('skeleton_b'),
    '$app/pubspec.yaml': 'name: starter\ndescription: Starter app.\nresolution: workspace\ndependencies:\n  skeleton_a: any\n',
    '$app/android/app/build.gradle.kts': 'namespace = "com.example.starter"\napplicationId = "com.example.starter"\n',
    '$app/android/app/src/main/AndroidManifest.xml':
        'android:label="starter"\n',
    '$app/android/app/src/main/kotlin/com/example/starter/MainActivity.kt':
        'package com.example.starter\n',
    '$app/ios/Runner.xcodeproj/project.pbxproj':
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.starter;\n',
    '$app/ios/Runner/Info.plist': plist,
    '$app/ios/Runner/Info-Debug.plist': plist,
    '$app/lib/main.dart': "title: 'Starter'\n",
    '$app/lib/screens/login_screen.dart': "Text('Starter')\n",
    '$app/test/app_test.dart': "import 'package:starter/main.dart';\n",
    '$app/README.md': '# starter\n',
    '.github/workflows/ci.yml': 'working-directory: apps/starter\n      # The catalog says what the repo is.\n      - run: dart tool/build_capabilities.dart --check\n',
    '.github/workflows/new-project.yml': 'name: new-project\n',
    'tool/x.dart': '',
    'scripts/new-project.sh': '',
    'scripts/test-new-project.sh': '',
    'docs/superpowers/spec.md': '',
    'capabilities.json': json(catalog),
    'docs/capabilities.schema.json': File('../docs/capabilities.schema.json')
        .readAsStringSync(),
  };
}

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

  group('a whole stamp of a fake workspace', () {
    late Directory target;
    setUp(() {
      target = Directory.systemTemp.createTempSync('stamp-full');
      writeTree(target, fakeSkeleton());
    });
    tearDown(() => target.deleteSync(recursive: true));

    test('drops the package that was not kept and leaves a catalog that passes the schema', () {
      applyStamp(
        target,
        const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
      );
      expect(Directory('${target.path}/packages/b').existsSync(), isFalse);
      expect(Directory('${target.path}/packages/a').existsSync(), isTrue);
      final root = File('${target.path}/pubspec.yaml').readAsStringSync();
      expect(root, contains('  - packages/a\n'));
      expect(root, contains('  - apps/acme_app\n'));
      expect(root, isNot(contains('packages/b')));
      expect(root, isNot(contains('  - tool')));
      final catalog = readJson(File('${target.path}/capabilities.json'));
      expect((catalog['omitted']! as List).single, containsPair('id', 'b'));
      expect(
        checkSchema(
          catalog,
          readJson(File('../docs/capabilities.schema.json')),
        ),
        isEmpty,
      );
      expect(
        File(
          '${target.path}/apps/acme_app/ios/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync(),
        contains('com.acme.acmeApp'),
      );
    });

    test('does not copy secrets, signing keys or editor settings', () {
      final src = Directory.systemTemp.createTempSync('stamp-src');
      final dst = Directory('${src.path}-out');
      addTearDown(() {
        src.deleteSync(recursive: true);
        if (dst.existsSync()) dst.deleteSync(recursive: true);
      });
      writeTree(src, {
        'keep.txt': 'x',
        '.env': 'SECRET=1',
        'release.jks': 'x',
        'upload.keystore': 'x',
        'server.key': 'x',
        '.vscode/settings.json': '{}',
        '.vscode/extensions.json': '{}',
        'coverage/lcov.info': 'x',
      });
      copyTree(src, dst);
      final copied = [
        for (final f in dst.listSync(recursive: true).whereType<File>())
          f.path.substring(dst.path.length + 1),
      ]..sort();
      expect(copied, ['.vscode/extensions.json', 'keep.txt']);
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
