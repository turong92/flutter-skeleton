import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

ApiClient _client(
  FakeAuthBackend backend,
  TokenStore store, {
  void Function()? onSessionEnded,
}) => createAuthClient(
  baseUrl: 'http://localhost:8080/api/v1',
  tokenStore: store,
  onSessionEnded: onSessionEnded ?? () {},
  adapter: backend.adapter,
);

Future<Object?> _me(ApiClient client) =>
    client.value('/auth/me', decode: (j) => j['accountId']);

void main() {
  late FakeAuthBackend backend;
  late MemoryTokenStore store;

  setUp(() async {
    backend = FakeAuthBackend();
    store = MemoryTokenStore();
    await store.save(
      const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
  });

  test('sends the stored access token as a Bearer header', () async {
    await _me(_client(backend, store));

    expect(backend.requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('a 401 refreshes once, retries with the new token and saves the rotated pair', () async {
    backend.accessToken =
        'server-rotated-out'; // the stored access token is stale

    final id = await _me(_client(backend, store));

    expect(id, 'acc_user');
    expect(backend.refreshCalls, 1);
    final saved = await store.read();
    expect(saved!.accessToken, backend.accessToken);
    expect(saved.refreshToken, backend.refreshToken);
    expect(
      backend.requests.last.headers['Authorization'],
      'Bearer ${backend.accessToken}',
    );
  });

  test('401s that arrive together share one refresh', () async {
    backend.accessToken = 'server-rotated-out';
    backend.refreshDelay = const Duration(milliseconds: 50);
    final client = _client(backend, store);

    final ids = await Future.wait([_me(client), _me(client), _me(client)]);

    expect(ids, ['acc_user', 'acc_user', 'acc_user']);
    expect(backend.refreshCalls, 1);
  });

  for (final code in ['AUTH.REFRESH_INVALID', 'AUTH.REFRESH_REUSED']) {
    test(
      '$code clears the store, ends the session once and surfaces the 401',
      () async {
        backend.accessToken = 'server-rotated-out';
        backend.refreshOverride = () => apiError(401, code);
        var ended = 0;
        final client = _client(backend, store, onSessionEnded: () => ended++);

        await expectLater(
          Future.wait([_me(client), _me(client)]),
          throwsA(
            isA<ApiRequestError>().having((e) => e.status, 'status', 401),
          ),
        );

        expect(await store.read(), isNull);
        expect(ended, 1);
        expect(backend.refreshCalls, 1);
      },
    );
  }

  test('a refresh that fails on the network keeps the session and surfaces that error', () async {
    backend.accessToken = 'server-rotated-out';
    final offline = FakeAdapter((options) {
      if (options.path == '/auth/refresh') {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        );
      }
      return backend.adapter.fetch(options, null, null);
    });
    var ended = 0;
    final client = createAuthClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStore: store,
      onSessionEnded: () => ended++,
      adapter: offline,
    );

    await expectLater(
      _me(client),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          ClientErrorCodes.networkError,
        ),
      ),
    );

    expect(await store.read(), isNotNull);
    expect(ended, 0);
  });

  test(
    'a request that is still 401 after the retry gives up (no refresh loop)',
    () async {
      backend.accessToken = 'never-matches';
      backend.refreshOverride = () =>
          FakeAdapter.json(200, tokenResponse('also-wrong', 'refresh-2'));

      await expectLater(
        _me(_client(backend, store)),
        throwsA(isA<ApiRequestError>().having((e) => e.status, 'status', 401)),
      );

      expect(backend.refreshCalls, 1);
    },
  );

  test('a login (skipAuth) with the wrong password is not "recovered" by a refresh', () async {
    final api = AuthApi(_client(backend, store));

    await expectLater(
      api.login(email: 'user@example.com', password: 'nope'),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          ErrorCodes.authInvalidCredentials,
        ),
      ),
    );

    expect(backend.refreshCalls, 0);
  });

  test(
    'token values never show up in toString of the pair or the stores',
    () async {
      const pair = TokenPair(
        accessToken: 'secret-access',
        refreshToken: 'secret-refresh',
      );
      final memory = MemoryTokenStore();
      await memory.save(pair);

      for (final text in [
        pair.toString(),
        memory.toString(),
        SecureTokenStore().toString(),
      ]) {
        expect(text, isNot(contains('secret')));
      }
    },
  );
}
