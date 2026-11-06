import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if iap
import 'package:skeleton_iap/skeleton_iap.dart';
// #endif
// #if notifications realtime
import 'package:starter/inbox_realtime.dart';
// #endif
import 'package:starter/main.dart';
import 'package:starter/wiring.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};
const _principal = {
  'accountId': 'acc_user',
  'email': 'user@example.com',
  'roles': ['USER'],
  'permissions': <String>[],
};

/// The part of the backend the starter talks to.
final _backend = FakeAdapter((options) {
  switch (options.path) {
    case '/auth/login':
      final body = options.data as Map<String, Object?>;
      if (body['password'] != 'password') {
        return FakeAdapter.json(401, {
          'code': 'AUTH.INVALID_CREDENTIALS',
          'title': 'Invalid credentials',
          'status': 401,
        });
      }
      return FakeAdapter.json(200, {
        'value': {
          'accessToken': 'access-1',
          'tokenType': 'Bearer',
          'expiresAt': '2026-01-01T00:15:00Z',
          'principal': _principal,
          'refreshToken': 'refresh-1',
        },
        'meta': _meta,
      });
    case '/auth/me':
      return FakeAdapter.json(200, {'value': _principal, 'meta': _meta});
    case '/auth/logout':
      return FakeAdapter.empty(204);
  }
  return FakeAdapter.json(404, {
    'code': 'COMMON.NOT_FOUND',
    'title': 'Not found',
    'status': 404,
  });
});

Widget _app(TokenStore store) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(store),
    httpAdapterProvider.overrideWithValue(_backend),
    ...starterWiring,
    // #if iap
    // no store on the test host
    iapPlatformProvider.overrideWithValue(null),
    // #endif
    // #if notifications realtime
    // no event stream in a test
    inboxRealtimeProvider.overrideWithValue(null),
    // #endif
  ],
  child: const StarterApp(),
);

Future<void> _signIn(WidgetTester tester, String password) async {
  await tester.enterText(find.byKey(LoginForm.emailKey), 'user@example.com');
  await tester.enterText(find.byKey(LoginForm.passwordKey), password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign in, see my account, sign out', (tester) async {
    final store = MemoryTokenStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);

    await _signIn(tester, 'password');

    expect(find.text('user@example.com'), findsOneWidget);
    expect(await store.read(), isNotNull);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('user@example.com'), findsNothing);
    expect(await store.read(), isNull);
  });

  testWidgets('a wrong password shows the invalid-credentials text', (
    tester,
  ) async {
    await tester.pumpWidget(_app(MemoryTokenStore()));
    await tester.pumpAndSettle();

    await _signIn(tester, 'wrong');

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a restart with stored tokens goes straight to my account', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    await store.save(
      const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.byKey(LoginForm.emailKey), findsNothing);
  });
}
