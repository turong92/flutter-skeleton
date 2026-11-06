import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sample/l10n/l10n.dart';
import 'package:sample/screens/login_screen.dart';
import 'package:sample/screens/settings_screen.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_i18n/skeleton_i18n.dart';
import 'package:skeleton_i18n/testing.dart';

/// The sign-in page in a router, in the language the providers choose.
Widget _app({
  required List<Locale> device,
  MemoryLocaleStore? store,
  String start = '/',
}) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    httpAdapterProvider.overrideWithValue(
      FakeAdapter(
        (_) => FakeAdapter.json(404, {
          'code': 'COMMON.NOT_FOUND',
          'title': 'x',
          'status': 404,
        }),
      ),
    ),
    deviceLocalesProvider.overrideWithValue(device),
    localeStoreProvider.overrideWithValue(store ?? MemoryLocaleStore()),
  ],
  child: Consumer(
    builder: (context, ref, _) => MaterialApp.router(
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: GoRouter(
        initialLocation: start,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ),
  ),
);

void main() {
  test('the Korean and English texts have the same keys and placeholders', () {
    expect(
      arbProblems(
        readArb('lib/l10n/app_ko.arb'),
        readArb('lib/l10n/app_en.arb'),
      ),
      isEmpty,
    );
  });

  testWidgets(
    'a Korean device gets Korean: the app texts and the package forms',
    (tester) async {
      await tester.pumpWidget(_app(device: const [Locale('ko', 'KR')]));
      await tester.pumpAndSettle();

      expect(find.text('가입하기'), findsOneWidget);
      // LoginLabels.ko() on the package's form
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
    },
  );

  testWidgets('an English device gets English', (tester) async {
    await tester.pumpWidget(_app(device: const [Locale('en', 'US')]));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('a language nobody supports falls back to Korean', (
    tester,
  ) async {
    await tester.pumpWidget(_app(device: const [Locale('ja')]));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('the menu in settings changes the language and remembers it', (
    tester,
  ) async {
    final store = MemoryLocaleStore();
    await tester.pumpWidget(
      _app(device: const [Locale('en')], store: store, start: '/settings'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsWidgets);

    await tester.tap(find.byType(LanguageMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어').last);
    await tester.pumpAndSettle();

    expect(find.text('로그아웃'), findsWidgets);
    expect(find.text('Sign out'), findsNothing);
    expect(store.code, 'ko');
  });
}
