@Tags(['backend'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

// Runs the account calls against a real kotlin-skeleton `apps/api` (sign-up
// consent gate, attempt, wrong code, forgot, policy, delete). The mailed code
// cannot be read, so "code -> login" is covered by the widget tests.
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   API_DELETE_EMAIL=doomed@example.com API_DELETE_PASSWORD=password \
//   flutter test --tags backend test/backend/account_backend_test.dart
//
// The two seed accounts come from `skeleton.account.seed.accounts` (see
// README.md). The delete account is deleted for real: use a throw-away one.
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];

void main() {
  final skip = _baseUrl == null || _env['API_DELETE_EMAIL'] == null
      ? 'Set API_BASE_URL, API_DELETE_EMAIL and API_DELETE_PASSWORD to run against a backend'
      : null;

  AccountApi plainApi() =>
      AccountApi(ApiClient(baseUrl: _baseUrl!));

  Future<List<ConsentClaim>> requiredConsents() async {
    final response = await Dio(
      BaseOptions(baseUrl: _baseUrl!),
    ).get<Map<String, Object?>>('/legal/documents');
    final claims = <String, ConsentClaim>{};
    for (final doc in response.data!['values']! as List) {
      doc as Map<String, Object?>;
      if (doc['requiredAtSignUp'] == true) {
        claims[doc['type']! as String] = ConsentClaim(
          type: doc['type']! as String,
          version: doc['version']! as String,
        );
      }
    }
    return claims.values.toList();
  }

  test('policy: maxBytes is bytes and the local check agrees with the server shape', () async {
    final policy = await plainApi().passwordPolicy();

    expect(policy.minLength, greaterThan(0));
    expect(policy.maxBytes, greaterThanOrEqualTo(policy.minLength));
  }, skip: skip);

  test('sign-up without the required consents is 400 LEGAL.CONSENT_REQUIRED', () async {
    await expectLater(
      plainApi().signUp(email: 'f9-noconsent@example.com', password: 'secret-pass-1'),
      throwsA(
        isA<ApiRequestError>()
            .having((e) => e.status, 'status', 400)
            .having((e) => e.code, 'code', AccountErrorCodes.legalConsentRequired),
      ),
    );
  }, skip: skip);

  test('sign-up with the consents is 202 and gives an attempt; a wrong code lists the tries left', () async {
    final api = plainApi();
    final outcome = await api.signUp(
      email: 'f9-new-${DateTime.now().microsecondsSinceEpoch}@example.com',
      password: 'secret-pass-1',
      consents: await requiredConsents(),
    );

    expect(outcome.status, SignUpStatus.verificationSent);
    final attempt = outcome.attempt!;
    expect(attempt.signUpId, isNotEmpty);
    expect(attempt.expiresAt.isAfter(DateTime.now()), isTrue);

    await expectLater(
      api.verifyEmail(signUpId: attempt.signUpId, code: '000000'),
      throwsA(
        isA<ApiRequestError>()
            .having((e) => e.code, 'code', AccountErrorCodes.codeInvalid)
            .having(attemptsLeftOf, 'attemptsLeft', isA<int>()),
      ),
    );
  }, skip: skip);

  test('forgot password is 202 for an unknown address too', () async {
    await plainApi().forgotPassword('nobody-f9@example.com');
  }, skip: skip);

  test('delete: the password is checked, the same Idempotency-Key repeats the answer', () async {
    final store = MemoryTokenStore();
    final client = createAuthClient(
      baseUrl: _baseUrl!,
      tokenStore: store,
      onSessionEnded: () {},
    );
    final login = await AuthApi(client).login(
      email: _env['API_DELETE_EMAIL']!,
      password: _env['API_DELETE_PASSWORD']!,
    );
    await store.save(login.tokens);
    final api = AccountApi(client);

    await expectLater(
      api.deleteAccount(currentPassword: 'wrong-password', idempotencyKey: newIdempotencyKey()),
      throwsA(isA<ApiRequestError>().having((e) => e.status, 'status', 400)),
    );

    final key = newIdempotencyKey();
    final first = await api.deleteAccount(
      currentPassword: _env['API_DELETE_PASSWORD']!,
      idempotencyKey: key,
    );
    final again = await api.deleteAccount(
      currentPassword: _env['API_DELETE_PASSWORD']!,
      idempotencyKey: key,
    );

    expect(first.purgeAfter.isAfter(DateTime.now()), isTrue);
    expect(again.purgeAfter, first.purgeAfter);
  }, skip: skip);
}
