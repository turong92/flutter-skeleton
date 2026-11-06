import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_i18n/skeleton_i18n.dart';
import 'package:skeleton_i18n/testing.dart';

const _supported = [Locale('ko'), Locale('en')];

void main() {
  group('resolveLocale', () {
    Locale resolve({Locale? saved, List<Locale> device = const []}) =>
        resolveLocale(
          supported: _supported,
          fallback: const Locale('ko'),
          saved: saved,
          device: device,
        );

    test('the saved pick wins over the device', () {
      expect(
        resolve(saved: const Locale('en'), device: const [Locale('ko', 'KR')]),
        const Locale('en'),
      );
    });

    test('without a pick the first supported device language is used', () {
      expect(
        resolve(device: const [Locale('ja'), Locale('en', 'US')]),
        const Locale('en'),
      );
    });

    test('nothing supported falls back to Korean', () {
      expect(resolve(device: const [Locale('ja')]), const Locale('ko'));
      expect(resolve(), const Locale('ko'));
    });

    test('a saved pick the app does not support is ignored', () {
      expect(
        resolve(saved: const Locale('ja'), device: const [Locale('en')]),
        const Locale('en'),
      );
    });
  });

  group('the saved pick', () {
    test('SharedPreferences keeps the language code', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesLocaleStore();

      expect(await loadSavedLocale(store), isNull);
      await store.save('en');
      expect(await loadSavedLocale(store), const Locale('en'));
      await store.clear();
      expect(await loadSavedLocale(store), isNull);
    });
  });

  group('LocaleController', () {
    ProviderContainer container({
      List<Locale> device = const [Locale('en')],
      Locale? saved,
      MemoryLocaleStore? store,
    }) {
      final c = ProviderContainer(
        overrides: [
          deviceLocalesProvider.overrideWithValue(device),
          savedLocaleProvider.overrideWithValue(saved),
          localeStoreProvider.overrideWithValue(store ?? MemoryLocaleStore()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('starts from the device language', () {
      expect(
        container(device: const [Locale('en', 'US')]).read(localeProvider),
        const Locale('en'),
      );
    });

    test('starts from the saved pick', () {
      expect(
        container(
          saved: const Locale('ko'),
          device: const [Locale('en')],
        ).read(localeProvider),
        const Locale('ko'),
      );
    });

    test('pick changes the language and remembers it', () async {
      final store = MemoryLocaleStore();
      final c = container(store: store);

      await c.read(localeProvider.notifier).pick(const Locale('ko'));

      expect(c.read(localeProvider), const Locale('ko'));
      expect(store.code, 'ko');
    });

    test('followDevice forgets the pick', () async {
      final store = MemoryLocaleStore('ko');
      final c = container(saved: const Locale('ko'), store: store);

      await c.read(localeProvider.notifier).followDevice();

      expect(c.read(localeProvider), const Locale('en'));
      expect(store.code, isNull);
    });
  });

  testWidgets('the menu shows the current language and picks another', (
    tester,
  ) async {
    final store = MemoryLocaleStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceLocalesProvider.overrideWithValue(const [Locale('ko')]),
          localeStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: Scaffold(body: LanguageMenu())),
      ),
    );
    expect(find.text('한국어'), findsOneWidget);

    await tester.tap(find.byType(LanguageMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(store.code, 'en');
  });

  group('arbProblems', () {
    test('equal keys and placeholders are no problem', () {
      expect(
        arbProblems(
          {'@@locale': 'ko', 'hi': 'Hi {name}', '@hi': {}},
          {'@@locale': 'en', 'hi': '{name}님', '@hi': {}},
        ),
        isEmpty,
      );
    });

    test('words inside a plural branch are not placeholders', () {
      expect(
        arbProblems(
          {'n': '{count, plural, =0{none} other{{count} items}}'},
          {'n': '{count, plural, =0{없어요} other{{count}개}}'},
        ),
        isEmpty,
      );
      expect(
        arbProblems(
          {'n': '{count, plural, =0{none} other{many}}'},
          {'n': '{total, plural, =0{없어요} other{많아요}}'},
        ),
        ['placeholders differ: n'],
      );
    });

    test('a missing key, an extra key and different placeholders', () {
      expect(
        arbProblems(
          {'a': 'x', 'b': '{n} items', 'c': 'y'},
          {'a': 'x', 'b': '{count} items', 'd': 'z'},
        ),
        [
          'missing in translation: c',
          'not in the base: d',
          'placeholders differ: b',
        ],
      );
    });
  });
}
