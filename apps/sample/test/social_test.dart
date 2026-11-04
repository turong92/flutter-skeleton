import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample/screens/login_screen.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

class _FakeProvider implements SocialProvider {
  _FakeProvider(this.id, {this.cancel = false});

  @override
  final String id;
  final bool cancel;

  @override
  Future<SocialCredential> obtain(String nonce) async {
    if (cancel) throw const SocialCancelled();
    return const SocialCredential.accessToken('opaque-token');
  }

  @override
  Future<void> signOut() async {}
}

Widget _login({
  required List<SocialProvider> providers,
  required int tokenStatus,
  Object? tokenBody,
  List<String> listed = const ['kakao', 'naver'],
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
    if (options.path.startsWith('/auth/social/')) {
      return FakeAdapter.json(tokenStatus, tokenBody);
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

void main() {
  testWidgets('shows only the providers the build has and the server lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _login(
        // google is listed by the server but not in this build; naver is in
        // the build but the server does not list it
        providers: [_FakeProvider('kakao'), _FakeProvider('naver')],
        listed: ['kakao', 'google'],
        tokenStatus: 500,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('social.button.kakao')), findsOneWidget);
    expect(find.byKey(const ValueKey('social.button.naver')), findsNothing);
    expect(find.byKey(const ValueKey('social.button.google')), findsNothing);
  });

  testWidgets('an email conflict tells the person to link in settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _login(
        providers: [_FakeProvider('kakao')],
        tokenStatus: 409,
        tokenBody: {
          'code': 'ACCOUNT.SOCIAL_EMAIL_CONFLICT',
          'title': 'Conflict',
          'status': 409,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('social.button.kakao')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('link this provider in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('a sign-in nobody registered says so', (tester) async {
    await tester.pumpWidget(
      _login(
        providers: [_FakeProvider('kakao')],
        tokenStatus: 409,
        tokenBody: {
          'code': 'AUTH_SOCIAL.ACCOUNT_LINK_NOT_FOUND',
          'title': 'Conflict',
          'status': 409,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('social.button.kakao')));
    await tester.pumpAndSettle();

    expect(
      find.text('No account is registered for this sign-in.'),
      findsOneWidget,
    );
  });

  testWidgets('backing out of the provider shows no error', (tester) async {
    await tester.pumpWidget(
      _login(
        providers: [_FakeProvider('kakao', cancel: true)],
        tokenStatus: 500,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('social.button.kakao')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('social.error')), findsNothing);
  });
}
