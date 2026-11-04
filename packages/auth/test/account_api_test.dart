import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

AccountApi _api(FakeAdapter adapter) => AccountApi(
  ApiClient(baseUrl: 'http://localhost:8080/api/v1', adapter: adapter),
);

ResponseBody _accepted(Object? value) =>
    FakeAdapter.json(202, {
      'value': value,
      'meta': {'timestamp': '2026-01-01T00:00:00Z'},
    });

void main() {
  test('signUp sends the consents with the version it was given and reads the attempt', () async {
    final adapter = FakeAdapter(
      (_) => _accepted({
        'status': 'VERIFICATION_SENT',
        'signUpId': 'su_1',
        'expiresAt': '2026-01-01T00:10:00Z',
        'resendAvailableAt': '2026-01-01T00:01:00Z',
      }),
    );

    final outcome = await _api(adapter).signUp(
      email: 'new@example.com',
      password: 'Secret-123',
      consents: const [ConsentClaim(type: 'terms', version: '2026-01')],
    );

    final request = adapter.requests.single;
    expect(request.path, '/account/sign-up');
    expect(request.data, {
      'email': 'new@example.com',
      'password': 'Secret-123',
      'consents': [
        {'type': 'terms', 'version': '2026-01'},
      ],
    });
    expect(outcome.status, SignUpStatus.verificationSent);
    expect(outcome.attempt!.signUpId, 'su_1');
    expect(outcome.attempt!.expiresAt, DateTime.utc(2026, 1, 1, 0, 10));
    expect(outcome.attempt!.resendAvailableAt, DateTime.utc(2026, 1, 1, 0, 1));
  });

  test('signUp with verification switched off: CREATED and no attempt', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(201, {
        'value': {'status': 'CREATED'},
        'meta': {'timestamp': '2026-01-01T00:00:00Z'},
      }),
    );

    final outcome = await _api(adapter).signUp(
      email: 'new@example.com',
      password: 'Secret-123',
    );

    expect(outcome.status, SignUpStatus.created);
    expect(outcome.attempt, isNull);
  });

  test('verifyEmail returns the sign-in result', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(200, tokenResponse('access-9', 'refresh-9')),
    );

    final result = await _api(adapter).verifyEmail(signUpId: 'su_1', code: '123456');

    expect(adapter.requests.single.data, {'signUpId': 'su_1', 'code': '123456'});
    expect(result.tokens.accessToken, 'access-9');
    expect(result.principal.accountId, 'acc_user');
  });

  test('a wrong code carries attemptsLeft', () async {
    final adapter = FakeAdapter(
      (_) => FakeAdapter.json(400, {
        'code': 'ACCOUNT.CODE_INVALID',
        'title': 'The code is wrong',
        'status': 400,
        'data': {'attemptsLeft': 2},
      }),
    );

    try {
      await _api(adapter).verifyEmail(signUpId: 'su_1', code: '000000');
      fail('should throw');
    } on ApiRequestError catch (e) {
      expect(e.code, AccountErrorCodes.codeInvalid);
      expect(attemptsLeftOf(e), 2);
    }
  });

  test('resend returns the new window, resendAvailableAt may be null', () async {
    final adapter = FakeAdapter(
      (_) => _accepted({
        'status': 'ACCEPTED',
        'expiresAt': '2026-01-01T00:20:00Z',
        'resendAvailableAt': null,
      }),
    );

    final issued = await _api(adapter).resendVerification('su_1');

    expect(adapter.requests.single.path, '/account/verification/resend');
    expect(adapter.requests.single.data, {'signUpId': 'su_1'});
    expect(issued.expiresAt, DateTime.utc(2026, 1, 1, 0, 20));
    expect(issued.resendAvailableAt, isNull);
  });

  test('forgot and reset post what the contract wants', () async {
    final adapter = FakeAdapter((options) {
      if (options.path == '/account/password/forgot') {
        return _accepted({'status': 'ACCEPTED'});
      }
      return FakeAdapter.empty(204);
    });
    final api = _api(adapter);

    await api.forgotPassword('a@example.com');
    await api.resetPassword(token: 'tok', newPassword: 'New-secret-1');

    expect(adapter.requests[0].data, {'email': 'a@example.com'});
    expect(adapter.requests[1].path, '/account/password/reset');
    expect(adapter.requests[1].data, {'token': 'tok', 'newPassword': 'New-secret-1'});
  });

  test('policy is read as the server gives it', () async {
    final adapter = FakeAdapter(
      (_) => ok({
        'minLength': 10,
        'maxBytes': 72,
        'requireLetter': true,
        'requireDigit': false,
        'requireSymbol': false,
        'forbidEmailLocalPart': true,
      }),
    );

    final policy = await _api(adapter).passwordPolicy();

    expect(policy.minLength, 10);
    expect(policy.maxBytes, 72);
    expect(policy.requireLetter, isTrue);
    expect(policy.requireDigit, isFalse);
  });

  test('delete sends the password and the Idempotency-Key it was given', () async {
    final adapter = FakeAdapter(
      (_) => _accepted({
        'status': 'DELETION_SCHEDULED',
        'purgeAfter': '2026-02-01T00:00:00Z',
      }),
    );

    final scheduled = await _api(adapter).deleteAccount(
      currentPassword: 'pw',
      idempotencyKey: 'key-1',
    );

    final request = adapter.requests.single;
    expect(request.path, '/account/delete');
    expect(request.headers['Idempotency-Key'], 'key-1');
    expect(request.data, {'currentPassword': 'pw'});
    expect(scheduled.purgeAfter, DateTime.utc(2026, 2, 1));
  });
}
