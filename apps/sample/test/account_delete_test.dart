import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sample/screens/account_screen.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_social_login_apple/skeleton_social_login_apple.dart';

/// Counts the Apple sheets; the revoke POST itself is the real one.
class _FakeApple extends AppleSocialProvider {
  _FakeApple() : super(isIOS: () => true);

  var sheets = 0;

  @override
  Future<SocialCredential> obtain(String nonce) async {
    sheets++;
    return const SocialCredential.idToken('id-token', nonce: 'n');
  }

  @override
  Future<AppleDeleteProof> obtainForDelete(String nonce) async {
    sheets++;
    return const AppleDeleteProof(
      SocialCredential.idToken('id-token', nonce: 'n'),
      'one-sheet-code',
    );
  }

  @override
  Future<void> revokeBeforeDelete(ApiClient client) async {
    sheets++;
    await revokeWithCode(client, 'second-sheet-code');
  }
}

ResponseBody _value(int status, Object? value) => FakeAdapter.json(status, {
  'value': value,
  'meta': {'timestamp': '2026-01-01T00:00:00Z'},
});

void main() {
  testWidgets('an Apple-only account without an address sees one Apple sheet '
      'and the revoke goes out before the delete call', (tester) async {
    final apple = _FakeApple();
    final adapter = FakeAdapter((options) {
      switch (options.path) {
        case '/auth/me':
          return _value(200, {
            'accountId': 'acc_user',
            'roles': <String>[],
            'permissions': <String>[],
          });
        case '/account/me':
          return _value(200, {
            'hasPassword': false,
            'email': null,
            'methods': [
              {'method': 'apple'},
            ],
          });
        case '/auth/methods':
          return _value(200, {
            'social': [
              {'provider': 'apple', 'nativeToken': 'id_token'},
            ],
          });
        case '/auth/social/apple/revoke':
          return FakeAdapter.empty(204);
        case '/account/delete':
          return _value(202, {'purgeAfter': '2026-02-01T00:00:00Z'});
      }
      return FakeAdapter.json(404, {
        'code': 'COMMON.NOT_FOUND',
        'title': 'Not found',
        'status': 404,
      });
    });
    final store = MemoryTokenStore();
    await store.save(const TokenPair(accessToken: 'a', refreshToken: 'r'));
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AccountScreen()),
        GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authConfigProvider.overrideWithValue(
            const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
          ),
          tokenStoreProvider.overrideWithValue(store),
          httpAdapterProvider.overrideWithValue(adapter),
          socialProvidersProvider.overrideWithValue([apple]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
    await tester.pumpAndSettle();

    expect(apple.sheets, 1);
    final paths = adapter.requests.map((r) => r.path).toList();
    expect(paths, contains('/auth/social/apple/revoke'));
    expect(
      paths.indexOf('/auth/social/apple/revoke'),
      lessThan(paths.indexOf('/account/delete')),
    );
    expect(find.text('login page'), findsOneWidget);
  });
}
