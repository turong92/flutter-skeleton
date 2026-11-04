import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

ProviderContainer _container(
  FakeAuthBackend backend,
  TokenStore store, {
  HttpClientAdapter? adapter,
}) {
  final container = ProviderContainer(
    overrides: [
      authConfigProvider.overrideWithValue(
        const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
      ),
      tokenStoreProvider.overrideWithValue(store),
      httpAdapterProvider.overrideWithValue(adapter ?? backend.adapter),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<AuthState> _settled(ProviderContainer container) async {
  container.read(authSessionProvider); // starts the restore
  while (container.read(authSessionProvider) is AuthChecking) {
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(authSessionProvider);
}

void main() {
  late FakeAuthBackend backend;
  late MemoryTokenStore store;

  setUp(() {
    backend = FakeAuthBackend();
    store = MemoryTokenStore();
  });

  group('restore on start', () {
    test('no stored tokens: signed out without calling the backend', () async {
      final container = _container(backend, store);

      expect(container.read(authSessionProvider), isA<AuthChecking>());
      expect(await _settled(container), isA<SignedOut>());
      expect(backend.requests, isEmpty);
    });

    test('stored tokens and a good access token: signed in with the principal from /auth/me', () async {
      await store.save(
        const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final container = _container(backend, store);

      final state = await _settled(container);

      expect(
        state,
        isA<SignedIn>().having(
          (s) => s.principal.email,
          'email',
          'user@example.com',
        ),
      );
    });

    test('an expired access token is refreshed silently on start', () async {
      await store.save(
        const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1'),
      );
      final container = _container(backend, store);

      final state = await _settled(container);

      expect(state, isA<SignedIn>());
      expect(backend.refreshCalls, 1);
      expect((await store.read())!.refreshToken, 'refresh-2');
    });

    test(
      'a refresh token the server rejects: signed out and the store is empty',
      () async {
        await store.save(
          const TokenPair(accessToken: 'expired', refreshToken: 'revoked'),
        );
        final container = _container(backend, store);

        final state = await _settled(container);

        expect(state, isA<SignedOut>());
        expect(await store.read(), isNull);
      },
    );

    test('server unreachable on start: signed out, but the tokens are kept for the next start', () async {
      await store.save(
        const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      final down = FakeAdapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        ),
      );
      final container = _container(backend, store, adapter: down);

      final state = await _settled(container);

      expect(state, isA<SignedOut>());
      expect(await store.read(), isNotNull);
    });
  });

  test('a store that cannot be read: signed out (not stuck on the splash) and the error is reported', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final container = _container(backend, _BrokenStore());

    final state = await _settled(container);
    await Future<void>.delayed(Duration.zero);

    expect(state, isA<SignedOut>());
    expect(reported.single.exception, isA<StateError>());
  });

  group('login and logout', () {
    test('login stores the tokens and signs in', () async {
      final container = _container(backend, store);
      await _settled(container);

      await container
          .read(authSessionProvider.notifier)
          .login(email: 'user@example.com', password: 'password');

      expect(container.read(authSessionProvider), isA<SignedIn>());
      expect((await store.read())!.accessToken, 'access-1');
    });

    test(
      'wrong password: the error reaches the caller and nothing is stored',
      () async {
        final container = _container(backend, store);
        await _settled(container);

        await expectLater(
          container
              .read(authSessionProvider.notifier)
              .login(email: 'user@example.com', password: 'nope'),
          throwsA(
            isA<ApiRequestError>().having(
              (e) => e.code,
              'code',
              ErrorCodes.authInvalidCredentials,
            ),
          ),
        );

        expect(container.read(authSessionProvider), isA<SignedOut>());
        expect(await store.read(), isNull);
      },
    );

    test(
      'logout tells the server the refresh token, then clears the store',
      () async {
        await store.save(
          const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
        );
        final container = _container(backend, store);
        await _settled(container);

        await container.read(authSessionProvider.notifier).logout();

        final logout = backend.requests.singleWhere(
          (r) => r.path == '/auth/logout',
        );
        expect(logout.data, {'refreshToken': 'refresh-1'});
        expect(container.read(authSessionProvider), isA<SignedOut>());
        expect(await store.read(), isNull);
      },
    );

    test(
      'logout still signs out locally when the server cannot be reached',
      () async {
        await store.save(
          const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
        );
        final flaky = FakeAdapter((options) {
          if (options.path == '/auth/logout') {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'down',
            );
          }
          return backend.adapter.fetch(options, null, null);
        });
        final container = _container(backend, store, adapter: flaky);
        await _settled(container);

        await container.read(authSessionProvider.notifier).logout();

        expect(container.read(authSessionProvider), isA<SignedOut>());
        expect(await store.read(), isNull);
      },
    );
  });
}

class _BrokenStore implements TokenStore {
  @override
  Future<TokenPair?> read() async => throw StateError('keystore unavailable');

  @override
  Future<void> save(TokenPair tokens) async {}

  @override
  Future<void> clear() async {}
}
