import 'dart:convert';
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
        'app-sample',
        kind: 'app',
        package: 'sample',
        path: 'apps/sample',
        needs: ['b'],
        included: 'never',
      ),
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
    'pubspec.yaml': 'name: flutter_skeleton_workspace\ndescription: Root.\nworkspace:\n  - packages/a\n  - packages/b\n  - apps/starter\n  - apps/sample\n  - tool\n',
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
    '$app/lib/screens/login_screen.dart': "title: 'Starter',\n",
    '$app/test/app_test.dart': "import 'package:starter/main.dart';\n",
    '$app/test/account_flow_test.dart': "import 'package:starter/main.dart';\nimport 'package:starter/router.dart';\n",
    '$app/README.md': '# starter\n\n## Screens of the optional packages\n\nmarkers\n\n## Run\n',
    '.github/workflows/ci.yml': '      - run: flutter build apk --debug\n        working-directory: apps/starter\n      - run: flutter build apk --debug\n        working-directory: apps/sample\n      # The catalog says what the repo is.\n      - run: dart tool/build_capabilities.dart --check\n',
    '.github/workflows/new-project.yml': 'name: new-project\n',
    'apps/sample/pubspec.yaml': pubspec('sample', deps: ['skeleton_b']),
    'tool/x.dart': '',
    'scripts/new-project.sh': '',
    'scripts/test-new-project.sh': '',
    'docs/superpowers/spec.md': '',
    'capabilities.json': json(catalog),
    'docs/capabilities.schema.json': File('../docs/capabilities.schema.json')
        .readAsStringSync(),
  };
}

/// The fake skeleton plus package f, which the starter has screens for: its pubspec line, a
/// block in main.dart and a file of its own sit between markers.
Map<String, String> fakeSkeletonWithFeature() {
  final files = fakeSkeleton();
  files['packages/f/pubspec.yaml'] = pubspec('skeleton_f');
  files['apps/starter/pubspec.yaml'] = 'name: starter\ndescription: Starter app.\nresolution: workspace\ndependencies:\n  skeleton_a: any\n  # #if f\n  skeleton_f: any\n  # #endif\n';
  files['apps/starter/lib/main.dart'] = "title: 'Starter'\n// #if f\nimport 'package:skeleton_f/skeleton_f.dart';\n// #endif\n";
  files['apps/starter/lib/screens/f_screen.dart'] =
      '// #file f\nclass FScreen {}\n';
  files['apps/starter/lib/l10n/app_en.arb'] = '{\n  "@@locale": "en",\n  "hello": "Hello {name}",\n  "@hello": {\n    "placeholders": {"name": {"type": "String"}}\n  },\n  "fTitle": "F",\n  "@fTitle": {"x-feature": "f"}\n}\n';
  files['apps/starter/lib/tidy.dart'] =
      'class A {\n  int a = 1;\n\n  // #if f\n  int b = 2;\n  // #endif\n}\n';
  final catalog =
      jsonDecode(files['capabilities.json']!) as Map<String, Object?>;
  (catalog['capabilities']! as List).add(entry('f', included: 'flag'));
  files['capabilities.json'] = json(catalog);
  files['pubspec.yaml'] = files['pubspec.yaml']!.replaceFirst(
    '  - packages/b\n',
    '  - packages/b\n  - packages/f\n',
  );
  return files;
}

void main() {
  group('feature blocks', () {
    const text = 'a\n// #if x y\nxy\n// #endif\nb\n# #if x\nonly x\n# #endif\n';

    test(
      'a block stays when all its ids are kept, without its marker lines',
      () {
        expect(applyFeatureBlocks(text, {'x', 'y'}, 'f'), 'a\nxy\nb\nonly x\n');
      },
    );

    test('a block goes when one id is not kept', () {
      expect(applyFeatureBlocks(text, {'x'}, 'f'), 'a\nb\nonly x\n');
      expect(applyFeatureBlocks(text, {}, 'f'), 'a\nb\n');
    });

    test('null keeps no block (what the starter needs without options)', () {
      expect(applyFeatureBlocks(text, null, 'f'), 'a\nb\n');
    });

    test('an open, a stray or a nested marker stops', () {
      for (final bad in [
        '// #if x\nx\n',
        '// #endif\n',
        '// #if x\n// #if y\n// #endif\n// #endif\n',
      ]) {
        expect(
          () => applyFeatureBlocks(bad, {'x'}, 'f'),
          throwsA(isA<FeatureMarkerError>()),
        );
      }
    });

    test('a line that looks like a marker but is not well formed stops', () {
      for (final bad in [
        '// #if Board\nx\n// #endif\n',
        '# #if social_login\nx\n# #endif\n',
        '// #if board\nx\n// #endif now\n',
        'a\nb\nc\nd\n// #file board\n',
      ]) {
        expect(
          () => applyFeatureBlocks(bad, {'board'}, 'f'),
          throwsA(isA<FeatureMarkerError>()),
          reason: bad,
        );
      }
      // a C preprocessor line is not a marker
      expect(applyFeatureBlocks('#if X\n#endif\n', {}, 'f'), '#if X\n#endif\n');
    });

    test('markers of xml and yaml comments are read', () {
      expect(
        featureIdsIn(
          '<!-- #if storage -->\n<k/>\n<!-- #endif -->\n# #if board\n# #endif\n',
        ),
        {'storage', 'board'},
      );
    });
  });

  group('the starter\'s optional screens in a stamp', () {
    late Directory target;
    setUp(() {
      target = Directory.systemTemp.createTempSync('stamp-feature');
      writeTree(target, fakeSkeletonWithFeature());
    });
    tearDown(() => target.deleteSync(recursive: true));

    String read(String rel) =>
        File('${target.path}/apps/acme_app/$rel').readAsStringSync();
    bool exists(String rel) =>
        File('${target.path}/apps/acme_app/$rel').existsSync();

    test('without the package nothing of it is left', () {
      applyStamp(
        target,
        const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
      );

      expect(exists('lib/screens/f_screen.dart'), isFalse);
      expect(read('pubspec.yaml'), isNot(contains('skeleton_f')));
      expect(read('lib/main.dart'), isNot(contains('skeleton_f')));
      expect(read('lib/main.dart'), isNot(contains('#')));
      // the blank line a removed block leaves is tidied like dart format would
      expect(read('lib/tidy.dart'), 'class A {\n  int a = 1;\n}\n');
      // the texts of the package go with it, the others stay (and the attribute is gone)
      expect(
        read('lib/l10n/app_en.arb'),
        allOf(
          contains('Hello'),
          isNot(contains('fTitle')),
          isNot(contains('x-feature')),
        ),
      );
      final catalog = readJson(File('${target.path}/capabilities.json'));
      final app = (catalog['capabilities']! as List).firstWhere(
        (e) => (e as Map)['id'] == 'app-acme-app',
      ) as Map;
      expect(app['needs'], ['a']);
    });

    test('with the package its screen and block stay and the markers go', () {
      applyStamp(
        target,
        const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a', 'f']),
      );

      expect(read('lib/screens/f_screen.dart'), 'class FScreen {}\n');
      expect(
        read('lib/l10n/app_en.arb'),
        allOf(contains('fTitle'), isNot(contains('x-feature'))),
      );
      expect(read('pubspec.yaml'), contains('  skeleton_f: any\n'));
      expect(
        read('lib/main.dart'),
        contains("import 'package:skeleton_f/skeleton_f.dart';"),
      );
      expect(read('lib/main.dart'), isNot(contains('#')));
      final catalog = readJson(File('${target.path}/capabilities.json'));
      final app = (catalog['capabilities']! as List).firstWhere(
        (e) => (e as Map)['id'] == 'app-acme-app',
      ) as Map;
      expect(app['needs'], ['a', 'f']);
    });

    test(
      'a target inside a folder named build or .claude is still processed',
      () {
        final inner = Directory('${target.path}/build/.claude/proj')
          ..createSync(recursive: true);
        writeTree(inner, fakeSkeletonWithFeature());
        applyStamp(
          inner,
          const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
        );
        expect(
          File('${inner.path}/apps/acme_app/lib/screens/f_screen.dart')
              .existsSync(),
          isFalse,
        );
        expect(
          File('${inner.path}/apps/acme_app/lib/main.dart').readAsStringSync(),
          isNot(contains('#')),
        );
      },
    );

    test('a marker in a file type the stamp does not read stops it', () {
      File('${target.path}/apps/starter/lib/x.txt')
          .writeAsStringSync('# #if f\nx\n# #endif\n');
      expect(
        () => applyStamp(
          target,
          const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
        ),
        throwsA(
          isA<StampError>().having(
            (e) => e.message,
            'message',
            contains('x.txt'),
          ),
        ),
      );
    });

    test('the README names only the screens that came along', () {
      applyStamp(
        target,
        const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
      );
      expect(read('README.md'), contains('No optional package was picked'));
    });

    test('the README lists the picked packages', () {
      applyStamp(
        target,
        const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a', 'f']),
      );
      expect(
        read('README.md'),
        contains('picked when this project was made (f)'),
      );
      expect(read('README.md'), isNot(contains('FIREBASE')));
    });

    test('a marker that names no package stops the stamp', () {
      File('${target.path}/apps/starter/lib/main.dart')
          .writeAsStringSync('// #if nope\nx\n// #endif\n');
      expect(
        () => applyStamp(
          target,
          const StampOptions(name: 'acme_app', org: 'com.acme', keep: ['a']),
        ),
        throwsA(
          isA<StampError>().having(
            (e) => e.message,
            'message',
            contains('nope'),
          ),
        ),
      );
    });

    test('the starter itself does not count a block as something it needs', () {
      final all = readPackages(target);
      expect(all.firstWhere((p) => p.dir == 'apps/starter').deps, {
        'skeleton_a',
      });
    });
  });

  group('the real starter', () {
    String starter(String rel) =>
        File('../apps/starter/$rel').readAsStringSync();
    String stamped(String rel, Set<String> kept) =>
        applyFeatureBlocks(starter(rel), kept, rel);
    const traced = [
      'lib/router.dart',
      'lib/wiring.dart',
      'lib/config.dart',
      'lib/screens/me_screen.dart',
      'lib/screens/account_screen.dart',
      'lib/main.dart',
      'test/app_test.dart',
      'test/account_flow_test.dart',
      'android/app/build.gradle.kts',
      'android/.gitignore',
      'ios/.gitignore',
      'ios/Runner/AppDelegate.swift',
      'ios/Runner/SceneDelegate.swift',
      'ios/Flutter/Debug.xcconfig',
      'ios/Flutter/Release.xcconfig',
      'pubspec.yaml',
    ];

    test(
      'every marker in the starter is well formed and names a package folder',
      () {
        final folders = {
          for (final d in Directory(
            '../packages',
          ).listSync().whereType<Directory>())
            d.path.split('/').last.replaceAll('_', '-'),
        };
        for (final f in Directory(
          '../apps/starter',
        ).listSync(recursive: true).whereType<File>()) {
          if (f.path.contains('/build/') ||
              f.path.contains('/.dart_tool/') ||
              !RegExp(r'\.(dart|yaml|plist|xml)$').hasMatch(f.path)) {
            continue;
          }
          final text = f.readAsStringSync();
          expect(
            featureIdsIn(text).difference(folders),
            isEmpty,
            reason: f.path,
          );
          applyFeatureBlocks(text, {}, f.path);
          applyFeatureBlocks(text, folders, f.path);
        }
      },
    );

    test('picking no package leaves no trace of the board or photos', () {
      for (final rel in traced) {
        expect(
          stamped(rel, {}),
          isNot(
            contains(
              RegExp(
                'board|storage|Board|otification|ealtime|push|Push|irebase|iap|Iap|i18n|LanguageMenu|localeProvider|ocial|akao|aver|NidThirdParty|skeleton_ads|AdBanner|AdUnitIds|AdsPrivacy|AdsLabels|adsController|adsSdk|adsBanner|FakeAdsSdk',
              ),
            ),
          ),
          reason: rel,
        );
      }
      for (final plist in [
        'ios/Runner/Info.plist',
        'ios/Runner/Info-Debug.plist',
      ]) {
        expect(
          stamped(plist, {}),
          isNot(contains('NSPhotoLibrary')),
          reason: plist,
        );
      }
      expect(fileFeatures(starter('lib/screens/board_screens.dart')), [
        'board',
      ]);
    });

    test('picking board gives the screens, the routes and the entry, not the photo field', () {
      final kept = {'board'};
      expect(
        stamped('lib/router.dart', kept),
        allOf(
          contains("path: '/board'"),
          contains("path: 'new'"),
          contains("path: 'edit'"),
        ),
      );
      expect(
        stamped('lib/screens/me_screen.dart', kept),
        contains("context.push('/board')"),
      );
      expect(stamped('lib/wiring.dart', kept), contains('boardApiProvider'));
      expect(
        stamped('pubspec.yaml', kept),
        allOf(contains('skeleton_board'), isNot(contains('skeleton_storage'))),
      );
      final screens = stamped('lib/screens/board_screens.dart', kept);
      expect(
        screens,
        allOf(
          contains('PostEditor('),
          isNot(contains('skeleton_storage')),
          isNot(contains('attachment')),
        ),
      );
      expect(
        stamped('ios/Runner/Info.plist', kept),
        isNot(contains('NSPhotoLibraryUsageDescription')),
      );
    });

    test(
      'picking board and storage adds the photo field and the photo permission',
      () {
        final kept = {'board', 'storage'};
        final screens = stamped('lib/screens/board_screens.dart', kept);
        expect(
          screens,
          allOf(contains('ImageUploadField('), contains('attachmentBuilder')),
        );
        expect(
          stamped('lib/wiring.dart', kept),
          contains('storageApiProvider'),
        );
        expect(
          stamped('lib/screens/account_screen.dart', kept),
          contains('ProfilePictureSection('),
        );
        for (final plist in [
          'ios/Runner/Info.plist',
          'ios/Runner/Info-Debug.plist',
        ]) {
          expect(
            stamped(plist, kept),
            contains('NSPhotoLibraryUsageDescription'),
            reason: plist,
          );
        }
      },
    );

    test('notifications gives the inbox screen, its route and the badge button; realtime adds the stream', () {
      final inbox = {'notifications'};
      expect(
        stamped('lib/router.dart', inbox),
        contains("path: '/notifications'"),
      );
      expect(
        stamped('lib/screens/me_screen.dart', inbox),
        contains('UnreadBadge'),
      );
      expect(
        stamped('lib/wiring.dart', inbox),
        contains('notificationsAccountProvider'),
      );
      expect(
        stamped('lib/main.dart', inbox),
        isNot(contains('inboxRealtimeProvider')),
      );
      // the board's way to a post is only there with the board
      expect(stamped('lib/wiring.dart', inbox), isNot(contains("'/board/")));
      expect(
        stamped('lib/wiring.dart', {'notifications', 'board'}),
        contains("'/board/"),
      );
      expect(fileFeatures(starter('lib/inbox_realtime.dart')), [
        'notifications',
        'realtime',
      ]);
      final both = {'notifications', 'realtime'};
      expect(
        stamped('lib/main.dart', both),
        contains('ref.watch(inboxRealtimeProvider)'),
      );
      expect(
        stamped('pubspec.yaml', both),
        allOf(
          contains('skeleton_notifications'),
          contains('skeleton_realtime'),
        ),
      );
      // a stream with no inbox has nothing to tell
      expect(
        stamped('lib/main.dart', {'realtime'}),
        isNot(contains('inboxRealtimeProvider')),
      );
    });

    test('push gives Firebase start, the hook, the settings screen and the Android permission', () {
      final kept = {'push'};
      expect(
        stamped('lib/main.dart', kept),
        allOf(
          contains('await initFirebaseIfConfigured()'),
          contains('_pushSetupProvider'),
          contains('scaffoldMessengerKey'),
        ),
      );
      expect(
        stamped('lib/main.dart', kept),
        isNot(contains('notificationsChanged')),
      );
      expect(
        stamped('lib/main.dart', {'push', 'notifications'}),
        contains('notificationsChanged(ref)'),
      );
      expect(
        stamped('lib/router.dart', kept),
        contains("'/settings/notifications'"),
      );
      expect(
        stamped('lib/screens/me_screen.dart', kept),
        contains('PushPrompt'),
      );
      expect(
        stamped('lib/wiring.dart', kept),
        allOf(contains('pushApiProvider'), contains("import 'router.dart'")),
      );
      expect(
        stamped('lib/wiring.dart', kept),
        isNot(contains('pushFallbackLinkProvider')),
      );
      expect(
        stamped('lib/wiring.dart', {'push', 'notifications'}),
        contains('pushFallbackLinkProvider'),
      );
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', kept),
        contains('POST_NOTIFICATIONS'),
      );
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', {}),
        isNot(contains('POST_NOTIFICATIONS')),
      );
      expect(
        stamped('ios/Runner/Info.plist', kept),
        contains('remote-notification'),
      );
      expect(fileFeatures(starter('lib/firebase_setup.dart')), ['push']);
    });

    test('iap gives the store screen, its route, the outcome message and the notice before deleting', () {
      final kept = {'iap'};
      expect(stamped('lib/router.dart', kept), contains("path: '/store'"));
      expect(
        stamped('lib/screens/me_screen.dart', kept),
        contains("context.push('/store')"),
      );
      expect(
        stamped('lib/wiring.dart', kept),
        allOf(contains('iapApiProvider'), contains('iapSignedInProvider')),
      );
      expect(
        stamped('lib/main.dart', kept),
        allOf(
          contains('ref.watch(iapServiceProvider)'),
          contains('scaffoldMessengerKey'),
        ),
      );
      expect(
        stamped('lib/screens/account_screen.dart', kept),
        contains('iapStoreSubscriptionToCancelProvider'),
      );
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', kept),
        contains('url_launcher'),
      );
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', {}),
        isNot(contains('url_launcher')),
      );
      expect(fileFeatures(starter('lib/screens/store_screen.dart')), ['iap']);
    });

    test('ads gives the banner, the consent entry and the native app id; without it none is left', () {
      final kept = {'ads'};
      expect(stamped('pubspec.yaml', kept), contains('skeleton_ads'));
      expect(
        stamped('lib/config.dart', kept),
        allOf(contains('ADS_BANNER_ANDROID'), contains('ADS_BANNER_IOS')),
      );
      expect(
        stamped('lib/main.dart', kept),
        contains('ref.watch(adsControllerProvider)'),
      );
      expect(
        stamped('lib/screens/me_screen.dart', kept),
        contains('AdBanner('),
      );
      expect(
        stamped('lib/screens/account_screen.dart', kept),
        contains('AdsPrivacyOptionsButton('),
      );
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', kept),
        contains('com.google.android.gms.ads.APPLICATION_ID'),
      );
      for (final plist in [
        'ios/Runner/Info.plist',
        'ios/Runner/Info-Debug.plist',
      ]) {
        expect(
          stamped(plist, kept),
          allOf(
            contains('GADApplicationIdentifier'),
            contains('SKAdNetworkItems'),
            contains('NSUserTrackingUsageDescription'),
          ),
          reason: plist,
        );
        expect(
          stamped(plist, {}),
          isNot(
            anyOf(
              contains('GADApplicationIdentifier'),
              contains('SKAdNetwork'),
              contains('NSUserTracking'),
            ),
          ),
          reason: plist,
        );
      }
      expect(
        stamped('android/app/src/main/AndroidManifest.xml', {}),
        isNot(contains('gms.ads')),
      );
    });

    test('the ad removal needs both ads and iap', () {
      const files = ['lib/wiring.dart', 'lib/config.dart'];
      for (final rel in files) {
        final both = stamped(rel, {'ads', 'iap'});
        expect(
          both,
          anyOf(
            contains('adsRemovedProvider.overrideWith'),
            contains('ADS_REMOVAL_ITEM_TYPE'),
          ),
          reason: rel,
        );
        for (final one in [
          {'ads'},
          {'iap'},
        ]) {
          expect(
            stamped(rel, one),
            isNot(
              anyOf(
                contains('adsRemovedProvider'),
                contains('ADS_REMOVAL_ITEM_TYPE'),
              ),
            ),
            reason: '$rel $one',
          );
        }
      }
      expect(fileFeatures(starter('lib/ads_removal.dart')), ['ads', 'iap']);
      expect(fileFeatures(starter('test/ads_removal_test.dart')), [
        'ads',
        'iap',
      ]);
      expect(
        stamped('lib/screens/store_screen.dart', {'iap'}),
        contains('iapEntitlementsProvider'),
      );
    });

    test('the ARB texts of a package go with it, in both languages', () {
      Set<String> keys(String lang, Set<String> kept) => (jsonDecode(
        pruneFeatureArb(starter('lib/l10n/app_$lang.arb'), kept),
      ) as Map<String, Object?>).keys.where((k) => !k.startsWith('@')).toSet();
      for (final kept in [
        <String>{},
        {'board'},
        {'board', 'storage'},
        {'iap', 'i18n'},
        {'push', 'notifications', 'board', 'storage', 'iap', 'i18n'},
      ]) {
        expect(keys('ko', kept), keys('en', kept), reason: '$kept');
      }
      final none = keys('en', {});
      expect(
        none,
        containsAll(['createAccount', 'accountSettings', 'rolesLabel']),
      );
      expect(none, isNot(contains('boardTitle')));
      expect(none, isNot(contains('storeTitle')));
      expect(none, isNot(contains('language')));
      expect(
        pruneFeatureArb(starter('lib/l10n/app_en.arb'), {}),
        isNot(contains('x-feature')),
      );
      expect(
        keys('en', {'board'}),
        allOf(contains('boardTitle'), isNot(contains('photoBeingPrepared'))),
      );
      expect(keys('en', {'board', 'storage'}), contains('photoBeingPrepared'));
      expect(keys('en', {'iap'}), contains('purchaseConfirmed'));
      expect(keys('en', {'i18n'}), contains('language'));
    });

    test('i18n gives the saved language, the menu and its tests', () {
      final kept = {'i18n'};
      expect(stamped('pubspec.yaml', kept), contains('skeleton_i18n'));
      expect(
        stamped('lib/main.dart', kept),
        allOf(
          contains('loadSavedLocale'),
          contains('locale: ref.watch(localeProvider)'),
        ),
      );
      expect(
        stamped('lib/screens/me_screen.dart', kept),
        contains('LanguageMenu'),
      );
      expect(
        stamped('test/app_test.dart', kept),
        contains('the language menu changes the language'),
      );
      expect(fileFeatures(starter('test/i18n_arb_test.dart')), ['i18n']);
      // without it the app still follows the device language, Korean first
      expect(
        stamped('lib/main.dart', {}),
        contains("supportedLocales: const [Locale('ko'), Locale('en')]"),
      );
    });

    test(
      'social sign-in: no trace without it, each provider brings only its own',
      () {
        for (final plist in [
          'ios/Runner/Info.plist',
          'ios/Runner/Info-Debug.plist',
        ]) {
          expect(
            stamped(plist, {}),
            isNot(
              contains(
                RegExp(
                  'CFBundleURLTypes|GIDClientID|NidClientID|LSApplicationQueriesSchemes',
                ),
              ),
            ),
            reason: plist,
          );
        }
        expect(
          stamped('android/app/src/main/AndroidManifest.xml', {}),
          isNot(contains('kakao')),
        );
        expect(
          stamped('ios/Runner/Runner.entitlements', {}),
          isNot(contains('applesignin')),
        );
        for (final own in [
          'lib/social_support.dart',
          'lib/screens/social_buttons.dart',
          'test/social_test.dart',
        ]) {
          expect(fileFeatures(starter(own)), ['social-login'], reason: own);
        }
        for (final own in [
          'android/social.properties.example',
          'ios/Flutter/Social.xcconfig.example',
        ]) {
          expect(fileFeatures(starter(own)), isNotNull, reason: own);
        }

        const core = 'social-login';
        final kakao = {core, 'social-login-kakao'};
        expect(
          stamped('pubspec.yaml', kakao),
          allOf(
            contains('skeleton_social_login_kakao'),
            contains('kakao_flutter_sdk_user'),
            isNot(contains('skeleton_social_login_naver')),
            isNot(contains('sign_in_with_apple')),
          ),
        );
        expect(
          stamped('lib/main.dart', kakao),
          allOf(
            contains('KakaoSdk.init'),
            contains('buildSocialProviders'),
            contains('socialSignOutHookProvider'),
          ),
        );
        expect(
          stamped('lib/screens/login_screen.dart', kakao),
          contains('SocialButtons'),
        );
        expect(
          stamped('lib/config.dart', kakao),
          allOf(
            contains('kakaoNativeAppKey'),
            isNot(contains('googleServerClientId')),
          ),
        );
        expect(
          stamped('android/app/build.gradle.kts', kakao),
          allOf(
            contains('kakaoNativeAppKey'),
            contains('import java.util.Properties'),
            isNot(contains('naverClientId')),
          ),
        );
        expect(
          stamped('android/app/src/main/AndroidManifest.xml', kakao),
          allOf(
            contains('AuthCodeHandlerActivity'),
            isNot(contains('naver.sdk')),
          ),
        );
        expect(
          stamped('android/.gitignore', kakao),
          contains('social.properties'),
        );
        expect(
          stamped('ios/Runner/Info.plist', kakao),
          allOf(
            contains('kakao\$(KAKAO_NATIVE_APP_KEY)'),
            contains('kakaolink'),
            isNot(contains('GIDClientID')),
            isNot(contains('Nid')),
          ),
        );
        expect(
          stamped('ios/Runner/AppDelegate.swift', kakao),
          isNot(contains('NidThirdPartyLogin')),
        );
        expect(
          stamped('ios/Flutter/Debug.xcconfig', kakao),
          contains('Social.xcconfig'),
        );
        expect(
          stamped('android/social.properties.example', kakao),
          allOf(
            contains('kakaoNativeAppKey'),
            isNot(contains('naverClientId')),
          ),
        );
        expect(
          stamped('lib/social_support.dart', kakao),
          allOf(
            contains('KakaoSocialProvider'),
            isNot(contains('NaverSocialProvider')),
            isNot(contains('revokeAppleBeforeDelete')),
          ),
        );
        expect(
          stamped('lib/screens/account_screen.dart', kakao),
          allOf(
            contains('reauthWithLinkedProvider'),
            isNot(contains('revokeAppleBeforeDelete')),
          ),
        );

        final naver = {core, 'social-login-naver'};
        expect(
          stamped('ios/Runner/AppDelegate.swift', naver),
          contains('NidOAuth.shared.handleURL'),
        );
        expect(
          stamped('ios/Runner/SceneDelegate.swift', naver),
          contains('openURLContexts'),
        );
        expect(
          stamped('ios/Runner/Info.plist', naver),
          allOf(
            contains('NidClientID'),
            contains('naversearchapp'),
            isNot(contains('kakaolink')),
          ),
        );
        expect(
          stamped('android/app/src/main/AndroidManifest.xml', naver),
          allOf(
            contains('naver.sdk.clientId'),
            isNot(contains('AuthCodeHandlerActivity')),
          ),
        );

        final google = {core, 'social-login-google'};
        expect(
          stamped('ios/Runner/Info.plist', google),
          allOf(
            contains('GIDClientID'),
            contains(r'GOOGLE_REVERSED_CLIENT_ID'),
            isNot(contains('LSApplicationQueriesSchemes')),
          ),
        );
        expect(
          stamped('lib/config.dart', google),
          allOf(
            contains('googleServerClientId'),
            isNot(contains('kakaoNativeAppKey')),
          ),
        );
        expect(
          stamped('android/app/build.gradle.kts', google),
          isNot(contains('Properties')),
        );

        final apple = {core, 'social-login-apple'};
        expect(stamped('pubspec.yaml', apple), contains('sign_in_with_apple'));
        expect(
          stamped('lib/screens/account_screen.dart', apple),
          contains('revokeAppleBeforeDelete'),
        );
        expect(
          stamped('lib/screens/social_buttons.dart', apple),
          allOf(
            contains('SignInWithAppleButton'),
            isNot(contains('_BrandButton')),
          ),
        );
        expect(
          stamped('ios/Runner/Runner.entitlements', apple),
          contains('applesignin'),
        );
        expect(
          stamped('ios/Runner/Info.plist', apple),
          isNot(contains('CFBundleURLTypes')),
        );
      },
    );

    test('the ARB texts of social sign-in follow the providers', () {
      Set<String> keys(Set<String> kept) => (jsonDecode(
        pruneFeatureArb(starter('lib/l10n/app_en.arb'), kept),
      ) as Map<String, Object?>).keys.where((k) => !k.startsWith('@')).toSet();
      expect(keys({}), isNot(contains('orDivider')));
      expect(
        keys({'social-login'}),
        allOf(
          contains('orDivider'),
          contains('socialSdk'),
          isNot(contains('signInWithKakao')),
        ),
      );
      expect(
        keys({'social-login', 'social-login-kakao'}),
        allOf(contains('signInWithKakao'), isNot(contains('signInWithNaver'))),
      );
      expect(
        keys({'social-login', 'social-login-apple'}),
        contains('appleUnreachable'),
      );
    });

    test('storage alone does not give a photo field: it lives in the board screens', () {
      expect(
        stamped('lib/wiring.dart', {'storage'}),
        contains('storageApiProvider'),
      );
      expect(
        stamped('lib/router.dart', {'storage'}),
        isNot(contains('/board')),
      );
    });
  });

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
      expect(root, isNot(contains('apps/sample')));
      expect(Directory('${target.path}/apps/sample').existsSync(), isFalse);
      final ci = File('${target.path}/.github/workflows/ci.yml')
          .readAsStringSync();
      expect(ci, isNot(contains('sample')));
      expect(ci, contains('working-directory: apps/acme_app'));
      final catalog = readJson(File('${target.path}/capabilities.json'));
      expect(
        [for (final o in catalog['omitted']! as List) (o as Map)['id']],
        ['b', 'app-sample'],
      );
      expect(
        [for (final e in catalog['capabilities']! as List) (e as Map)['id']],
        ['a', 'app-acme-app'],
      );
      expect(
        checkSchema(
          catalog,
          readJson(File('../docs/capabilities.schema.json')),
        ),
        isEmpty,
      );
      expect(
        File('${target.path}/apps/acme_app/test/account_flow_test.dart')
            .readAsStringSync(),
        allOf(
          contains('package:acme_app/router.dart'),
          isNot(contains('starter')),
        ),
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
        'apps/s/android/social.properties': 'naverClientSecret=real',
        'apps/s/android/social.properties.example': 'x',
        'apps/s/ios/Flutter/Social.xcconfig': 'NAVER_CLIENT_SECRET = real',
        'apps/s/ios/Flutter/Social.xcconfig.example': 'x',
        'apps/x/lib/l10n/app_localizations.dart': 'x',
        'apps/x/lib/l10n/app_localizations_ko.dart': 'x',
        'apps/x/lib/l10n/app_ko.arb': '{}',
        'apps/x/lib/l10n/l10n.dart': 'x',
      });
      copyTree(src, dst);
      final copied = [
        for (final f in dst.listSync(recursive: true).whereType<File>())
          f.path.substring(dst.path.length + 1),
      ]..sort();
      // gen_l10n output is written again by `flutter pub get`, from the ARB files that survive
      expect(copied, [
        '.vscode/extensions.json',
        'apps/s/android/social.properties.example',
        'apps/s/ios/Flutter/Social.xcconfig.example',
        'apps/x/lib/l10n/app_ko.arb',
        'apps/x/lib/l10n/l10n.dart',
        'keep.txt',
      ]);
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
