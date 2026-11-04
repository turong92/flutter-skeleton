@Tags(['backend'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

// Runs the auth client against a real kotlin-skeleton `apps/api` (login, me,
// refresh, logout). No device needed. Skipped unless the variables are set:
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend
//
// The starter has no seed account: start it with
// `skeleton.account.seed.accounts` (see packages/auth/README.md). The "already
// rotated" test needs `skeleton.auth-session.reuse-grace: 0s`: the starter's
// 60 s grace hands the same successor to a spent token instead of closing the
// session.
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];
final _email = _env['API_SEED_EMAIL'] ?? '';
final _password = _env['API_SEED_PASSWORD'] ?? '';

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL, API_SEED_EMAIL and API_SEED_PASSWORD to run against a backend'
      : null;

  ApiClient clientWith(TokenStore store, {void Function()? onSessionEnded}) =>
      createAuthClient(
        baseUrl: _baseUrl!,
        tokenStore: store,
        onSessionEnded: onSessionEnded ?? () {},
      );

  test('login, me, silent refresh, logout against the real backend', () async {
    final store = MemoryTokenStore();
    var ended = 0;
    final client = clientWith(store, onSessionEnded: () => ended++);
    final api = AuthApi(client);

    // login
    final login = await api.login(email: _email, password: _password);
    await store.save(login.tokens);
    expect(login.principal.email, _email);

    // me with the issued access token
    expect((await api.me()).accountId, login.principal.accountId);

    // an unusable access token is renewed silently and the call repeats
    await store.save(
      TokenPair(
        accessToken: 'not-a-valid-jwt',
        refreshToken: login.tokens.refreshToken,
      ),
    );
    expect((await api.me()).accountId, login.principal.accountId);
    final rotated = (await store.read())!;
    expect(rotated.refreshToken, isNot(login.tokens.refreshToken));
    expect(ended, 0);

    // logout kills the session: its refresh token cannot be used any more
    await api.logout(rotated.refreshToken);
    await store.clear();
    await expectLater(
      api.refresh(rotated.refreshToken),
      throwsA(
        isA<ApiRequestError>()
            .having((e) => e.status, 'status', 401)
            .having(
              (e) => e.code,
              'code',
              anyOf(
                ErrorCodes.authRefreshInvalid,
                ErrorCodes.authRefreshReused,
              ),
            ),
      ),
    );
  }, skip: skip);

  test('a refresh token that was already rotated ends the session', () async {
    final store = MemoryTokenStore();
    var ended = 0;
    final client = clientWith(store, onSessionEnded: () => ended++);
    final api = AuthApi(client);

    final login = await api.login(email: _email, password: _password);
    await api.refresh(
      login.tokens.refreshToken,
    ); // rotates; the first token is spent
    // the app still holds the spent refresh token and an unusable access token
    await store.save(
      TokenPair(
        accessToken: 'not-a-valid-jwt',
        refreshToken: login.tokens.refreshToken,
      ),
    );

    await expectLater(
      api.me(),
      throwsA(isA<ApiRequestError>().having((e) => e.status, 'status', 401)),
    );

    expect(await store.read(), isNull);
    expect(ended, 1);
  }, skip: skip);

  test('a wrong password is AUTH.INVALID_CREDENTIALS', () async {
    final api = AuthApi(clientWith(MemoryTokenStore()));

    await expectLater(
      api.login(email: _email, password: '$_password-wrong'),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          ErrorCodes.authInvalidCredentials,
        ),
      ),
    );
  }, skip: skip);
}
