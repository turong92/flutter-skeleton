// #file social-login
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:starter/screens/login_screen.dart';

class _FakeProvider implements SocialProvider {
  _FakeProvider(this.id);

  @override
  final String id;

  @override
  Future<SocialCredential> obtain(String nonce) async =>
      const SocialCredential.accessToken('opaque-token');

  @override
  Future<void> signOut() async {}
}

/// The sign-in page with the providers the build has and the ids the server
/// lists in `GET /auth/methods`.
Widget _login({
  required List<SocialProvider> providers,
  required List<String> listed,
}) {
  final adapter = FakeAdapter((RequestOptions options) {
    if (options.path == '/auth/methods') {
      return FakeAdapter.json(200, {
        'value': {
          'social': [
            for (final id in listed)
              {'provider': id, 'nativeToken': 'access_token'},
          ],
        },
        'meta': {'timestamp': '2026-01-01T00:00:00Z'},
      });
    }
    return FakeAdapter.json(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'Not found',
      'status': 404,
    });
  });
  return ProviderScope(
    overrides: [
      authConfigProvider.overrideWithValue(
        const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
      ),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      httpAdapterProvider.overrideWithValue(adapter),
      socialProvidersProvider.overrideWithValue(providers),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

// #if social-login-apple|social-login-google|social-login-kakao|social-login-naver
Finder _button(String id) => find.byKey(ValueKey('social.button.$id'));
// #endif

void main() {
  testWidgets('the server lists no provider: no social buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _login(providers: [_FakeProvider('kakao')], listed: const []),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('social.error')), findsNothing);
    expect(find.text('or'), findsNothing);
  });

  // #if social-login-kakao
  testWidgets('a provider the build has and the server lists gets its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _login(
        // naver is in the build but the server does not list it
        providers: [_FakeProvider('kakao'), _FakeProvider('naver')],
        listed: const ['kakao', 'google'],
      ),
    );
    await tester.pumpAndSettle();

    expect(_button('kakao'), findsOneWidget);
    expect(_button('naver'), findsNothing);
    expect(_button('google'), findsNothing);
  });
  // #endif
  // #if social-login-naver
  testWidgets('Naver gets its button', (tester) async {
    await tester.pumpWidget(
      _login(providers: [_FakeProvider('naver')], listed: const ['naver']),
    );
    await tester.pumpAndSettle();

    expect(_button('naver'), findsOneWidget);
  });
  // #endif
  // #if social-login-google
  testWidgets('Google gets its button', (tester) async {
    await tester.pumpWidget(
      _login(providers: [_FakeProvider('google')], listed: const ['google']),
    );
    await tester.pumpAndSettle();

    expect(_button('google'), findsOneWidget);
  });
  // #endif
  // #if social-login-apple
  testWidgets('Apple gets its own button', (tester) async {
    await tester.pumpWidget(
      _login(providers: [_FakeProvider('apple')], listed: const ['apple']),
    );
    await tester.pumpAndSettle();

    expect(_button('apple'), findsOneWidget);
  });
  // #endif
}
