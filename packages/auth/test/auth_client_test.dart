import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';
import 'support/test_client.dart';

ApiClient _client(
  FakeAuthBackend backend,
  TokenStore store, {
  void Function()? onSessionEnded,
}) => testAuthClient(
  store: store,
  adapter: backend.adapter,
  onSessionEnded: onSessionEnded,
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

  for (final (status, code) in [
    (401, 'AUTH.REFRESH_INVALID'),
    (401, 'AUTH.REFRESH_REUSED'),
    (403, 'AUTH.ACCOUNT_SUSPENDED'),
  ]) {
    test(
      '$code clears the store, ends the session once and surfaces the 401',
      () async {
        backend.accessToken = 'server-rotated-out';
        backend.refreshOverride = () => apiError(status, code);
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

  test('a refresh whose response is lost is sent again with the SAME refresh token', () async {
    backend.accessToken = 'server-rotated-out';
    var lost = 0;
    final flaky = FakeAdapter((options) {
      if (options.path == '/auth/refresh' && lost++ == 0) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        );
      }
      return backend.adapter.fetch(options, null, null);
    });
    var ended = 0;
    final client = testAuthClient(
      store: store,
      adapter: flaky,
      onSessionEnded: () => ended++,
    );

    expect(await _me(client), 'acc_user');

    final sent = backend.requests
        .where((r) => r.path == '/auth/refresh')
        .toList();
    expect(sent, hasLength(1)); // the first never reached the backend
    expect(
      flaky.requests.where((r) => r.path == '/auth/refresh'),
      hasLength(2),
    );
    expect(
      flaky.requests
          .where((r) => r.path == '/auth/refresh')
          .map((r) => (r.data as Map)['refreshToken'])
          .toSet(),
      {'refresh-1'},
    );
    expect(ended, 0);
  });

  test(
    'a logout while a refresh is in flight is not undone by the refresh result',
    () async {
      backend.accessToken = 'server-rotated-out';
      backend.refreshDelay = const Duration(milliseconds: 50);
      final client = _client(backend, store);

      final call = _me(client);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.clear(); // the user signs out while the refresh runs

      await expectLater(
        call,
        throwsA(isA<ApiRequestError>().having((e) => e.status, 'status', 401)),
      );
      expect(await store.read(), isNull);
    },
  );

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
    'a REUSED answer for an old token does not sign out a newer sign-in',
    () async {
      backend.accessToken = 'server-rotated-out';
      backend.refreshDelay = const Duration(milliseconds: 50);
      backend.refreshOverride = () => apiError(401, 'AUTH.REFRESH_REUSED');
      var ended = 0;
      final client = _client(backend, store, onSessionEnded: () => ended++);

      final call = _me(client);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // the user signs in again while the old refresh is out
      await store.save(
        const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh'),
      );

      await expectLater(
        call,
        throwsA(isA<ApiRequestError>().having((e) => e.status, 'status', 401)),
      );
      expect((await store.read())!.refreshToken, 'new-refresh');
      expect(ended, 0);
    },
  );

  test(
    'token values never show up in toString of the pair or the memory store',
    () async {
      const pair = TokenPair(
        accessToken: 'secret-access',
        refreshToken: 'secret-refresh',
      );
      final memory = MemoryTokenStore();
      await memory.save(pair);

      for (final text in [pair.toString(), memory.toString()]) {
        expect(text, isNot(contains('secret')));
      }
    },
  );
}
