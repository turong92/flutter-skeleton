import 'dart:io';

import 'package:test/test.dart';

import '../build_capabilities.dart';
import 'support.dart';

/// Two packages (b needs a) and a starter that uses b.
Map<String, String> fakeRepo() => {
  'packages/a/pubspec.yaml': pubspec('skeleton_a'),
  'packages/a/README.md': '# a',
  'packages/b/pubspec.yaml': pubspec('skeleton_b', deps: ['skeleton_a']),
  'apps/starter/pubspec.yaml': pubspec('starter', deps: ['skeleton_b']),
};

Map<String, Object?> fakeCatalog() => {
  'capabilities': [
    entry('a', docs: ['packages/a/README.md']),
    entry('b', needs: ['a']),
    entry(
      'app-starter',
      kind: 'app',
      package: 'starter',
      path: 'apps/starter',
      needs: ['b'],
    ),
  ],
};

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('caps-test'));
  tearDown(() => root.deleteSync(recursive: true));

  List<String> check(
    Map<String, Object?> catalog, [
    Map<String, String>? repo,
  ]) {
    writeTree(root, repo ?? fakeRepo());
    return checkCatalog(root, catalog);
  }

  test('a catalog that matches the repo has no problems', () {
    expect(check(fakeCatalog()), isEmpty);
  });

  test('a package folder without an entry is reported', () {
    final repo = fakeRepo()
      ..['packages/c/pubspec.yaml'] = pubspec('skeleton_c');
    expect(check(fakeCatalog(), repo), contains(contains('packages/c')));
  });

  test('an entry whose folder is gone is reported', () {
    final catalog = fakeCatalog();
    (catalog['capabilities']! as List).add(entry('ghost'));
    expect(check(catalog), contains(contains('ghost')));
  });

  test(
    'needs that differ from the pubspec skeleton_* dependencies are reported',
    () {
      final catalog = fakeCatalog();
      ((catalog['capabilities']! as List)[1] as Map)['needs'] = <String>[];
      expect(check(catalog), contains(allOf(contains('needs'), contains('b'))));
    },
  );

  test('a docs path that does not exist is reported', () {
    final catalog = fakeCatalog();
    ((catalog['capabilities']! as List)[0] as Map)['docs'] = [
      'packages/a/NOPE.md',
    ];
    expect(check(catalog), contains(contains('NOPE.md')));
  });

  test('included "always" must be exactly what the starter pulls in', () {
    final catalog = fakeCatalog();
    // a stampFlag that says "pick with a flag" while the starter already needs it
    ((catalog['capabilities']! as List)[0] as Map)['stampFlag'] = {
      'flag': '--packages a',
      'included': 'flag',
    };
    expect(
      check(catalog),
      contains(allOf(contains('stampFlag'), contains('a'))),
    );
  });

  test('the generated docs differ from the catalog when they are stale', () {
    final catalog = {
      ...fakeCatalog(),
      'mode': 'skeleton',
      'name': 'n',
      'summary': 's',
    };
    writeTree(root, {'docs/capabilities.md': 'old', 'llms.txt': 'old'});
    expect(checkGenerated(root, catalog), hasLength(2));
    writeGenerated(root, catalog);
    expect(checkGenerated(root, catalog), isEmpty);
  });

  group('sibling repos', () {
    late Directory parent;
    late Directory mine;
    setUp(() {
      parent = Directory.systemTemp.createTempSync('caps-sib');
      mine = Directory('${parent.path}/flutter-skeleton')..createSync();
    });
    tearDown(() => parent.deleteSync(recursive: true));

    Map<String, Object?> catalogWith({
      String module = 'platform',
      String reactId = 'ui',
    }) => {
      'siblings': {
        'kotlin': {'repo': 'kotlin-skeleton', 'catalog': 'capabilities.json'},
        'react': {'repo': 'react-skeleton', 'catalog': 'capabilities.json'},
      },
      'capabilities': [
        entry(
          'api-client',
          backend: {
            'modules': [module],
            'oneOfModules': <List<String>>[],
            'optionalModules': <String>[],
            'basePaths': ['/api/v1'],
            'docs': ['docs/modules/platform.md'],
          },
          reactIds: [reactId],
        ),
      ],
    };

    void kotlin() => writeTree(Directory('${parent.path}/kotlin-skeleton'), {
      'docs/modules/README.md':
          '| `platform` | x | [platform](platform.md) |\n',
      'docs/modules/platform.md': '# platform',
    });
    void react() => writeTree(Directory('${parent.path}/react-skeleton'), {
      'capabilities.json': json({
        'capabilities': [
          {'id': 'ui'},
        ],
      }),
    });

    test(
      'without the sibling clones nothing is read and nothing is reported',
      () {
        expect(
          checkSiblings(
            mine,
            catalogWith(module: 'no-such-module', reactId: 'nope'),
          ),
          isEmpty,
        );
      },
    );

    test('with the clones present the real names pass', () {
      kotlin();
      react();
      expect(checkSiblings(mine, catalogWith()), isEmpty);
    });

    test('a backend module kotlin-skeleton does not list is reported', () {
      kotlin();
      expect(
        checkSiblings(mine, catalogWith(module: 'no-such-module')),
        contains(contains('no-such-module')),
      );
    });

    test('a pairsWith.react id react-skeleton does not have is reported', () {
      react();
      expect(
        checkSiblings(mine, catalogWith(reactId: 'nope')),
        contains(contains('nope')),
      );
    });
  });
}
