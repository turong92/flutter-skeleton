import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

import 'support/fake_backend.dart';

const _secretToken = 'eyJ.secret-id-token.sig';

ProviderContainer _container(
  FakeSocialBackend backend,
  List<SocialProvider> providers,
  MemoryTokenStore store,
) {
  final container = ProviderContainer(
    overrides: [
      authConfigProvider.overrideWithValue(
        const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
      ),
      tokenStoreProvider.overrideWithValue(store),
      httpAdapterProvider.overrideWithValue(backend.adapter),
      socialProvidersProvider.overrideWithValue(providers),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SocialLoginState> _signIn(
  ProviderContainer container,
  SocialProvider provider,
) async {
  await container.read(socialLoginControllerProvider.notifier).signIn(provider);
  return container.read(socialLoginControllerProvider);
}

void main() {
  late FakeSocialBackend backend;
  late MemoryTokenStore store;
  late FakeSocialProvider google;

  setUp(() {
    backend = FakeSocialBackend();
    store = MemoryTokenStore();
    google = FakeSocialProvider('google', idToken: _secretToken);
  });

  test(
    'success: the token and a fresh nonce go to the server, then SignedIn',
    () async {
      final container = _container(backend, [google], store);

      final state = await _signIn(container, google);

      expect(state, isA<SocialLoginIdle>());
      expect(container.read(authSessionProvider), isA<SignedIn>());
      expect((await store.read())?.accessToken, 'access-1');
      final request = backend.requests.single;
      expect(request.path, '/auth/social/google/token');
      final body = request.data as Map<String, Object?>;
      expect(body['idToken'], _secretToken);
      expect(body['nonce'], google.lastNonce);
      expect(body.containsKey('accessToken'), isFalse);
      // the 32 random bytes as base64url: 43 chars, a shape the server accepts (8-256)
      expect(google.lastNonce, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    },
  );

  test(
    'cancel is not an error: back to idle, nothing sent, still signed out',
    () async {
      final container = _container(backend, [google], store);
      google.cancel = true;

      final state = await _signIn(container, google);

      expect(state, isA<SocialLoginIdle>());
      expect(backend.requests, isEmpty);
      expect(container.read(authSessionProvider), isNot(isA<SignedIn>()));
    },
  );

  group('server answers', () {
    final cases = <String, (int, String, SocialFailure)>{
      'email already has an account': (
        409,
        'ACCOUNT.SOCIAL_EMAIL_CONFLICT',
        SocialFailure.emailConflict,
      ),
      'not linked and sign-up closed': (
        409,
        'AUTH_SOCIAL.ACCOUNT_LINK_NOT_FOUND',
        SocialFailure.notLinked,
      ),
      'token refused': (
        401,
        'AUTH.SOCIAL_ID_TOKEN_INVALID',
        SocialFailure.tokenRejected,
      ),
    };
    for (final entry in cases.entries) {
      test(
        '${entry.key}: ${entry.value.$2} is ${entry.value.$3.name}, never signed in',
        () async {
          final container = _container(backend, [google], store);
          backend.loginError = (entry.value.$1, entry.value.$2);

          final state = await _signIn(container, google);

          expect(state, isA<SocialLoginFailed>());
          expect((state as SocialLoginFailed).failure, entry.value.$3);
          expect(container.read(authSessionProvider), isNot(isA<SignedIn>()));
          expect(await store.read(), isNull);
        },
      );
    }
  });

  test('a token never shows in toString, in the failed state, or in what is logged', () async {
    final credential = SocialCredential.idToken(_secretToken, nonce: 'n' * 43);
    expect('$credential', isNot(contains(_secretToken)));
    expect('$credential', isNot(contains('nnnn')));

    final container = _container(backend, [google], store);
    backend.loginError = (401, 'AUTH.SOCIAL_ID_TOKEN_INVALID');
    final logged = <String>[];
    final oldPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    addTearDown(() => debugPrint = oldPrint);

    final state = await _signIn(container, google);

    expect('$state', isNot(contains(_secretToken)));
    expect(logged.join(), isNot(contains(_secretToken)));
    expect(
      jsonEncode(backend.requests.map((r) => r.uri.toString()).toList()),
      isNot(contains(_secretToken)),
    );
    // the failure the app reads carries a code, not the request
    expect(const SocialCancelled().toString(), isNot(contains(_secretToken)));
  });

  test('/auth/methods: only providers with a nativeToken are shown', () async {
    final apple = FakeSocialProvider('apple', idToken: 'x');
    final kakao = FakeSocialProvider('kakao', accessToken: 'y');
    final container = _container(backend, [google, apple, kakao], store);
    backend.methodsSocial = [
      {'provider': 'google', 'nativeToken': 'id_token'},
      {'provider': 'apple', 'nativeToken': null},
      {'provider': 'kakao', 'nativeToken': 'access_token'},
      {
        'provider': 'naver',
        'nativeToken': 'access_token',
      }, // the app has no naver
    ];

    final shown = await container.read(availableSocialProvidersProvider.future);

    expect([for (final p in shown) p.id], ['google', 'kakao']);
  });
}
