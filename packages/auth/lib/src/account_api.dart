import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'models.dart';

/// The backend calls of the `account` module for sign-up, password reset and
/// self-service deletion. Stores nothing.
class AccountApi {
  AccountApi(this._client);

  final ApiClient _client;

  /// `POST /account/sign-up`: 202 (code mailed, also for a taken address) or
  /// 201 when verification is off.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    String? displayName,
    List<ConsentClaim> consents = const [],
  }) {
    return _client.value(
      '/account/sign-up',
      method: 'POST',
      json: {
        'email': email,
        'password': password,
        'displayName': ?displayName,
        if (consents.isNotEmpty)
          'consents': [for (final c in consents) c.toJson()],
      },
      skipAuth: true,
      decode: SignUpOutcome.fromJson,
    );
  }

  /// `POST /auth/verify-email`: the right code creates the account and signs
  /// in. `400 ACCOUNT.CODE_INVALID` (see [attemptsLeftOf]), `410
  /// ACCOUNT.CODE_EXPIRED`.
  Future<AuthResult> verifyEmail({
    required String signUpId,
    required String code,
    String? displayName,
  }) {
    return _client.value(
      '/auth/verify-email',
      method: 'POST',
      json: {'signUpId': signUpId, 'code': code, 'displayName': ?displayName},
      skipAuth: true,
      decode: AuthResult.fromJson,
    );
  }

  /// `POST /account/verification/resend`: always 202; silent inside the
  /// cooldown.
  Future<CodeIssued> resendVerification(String signUpId) {
    return _client.value(
      '/account/verification/resend',
      method: 'POST',
      json: {'signUpId': signUpId},
      skipAuth: true,
      decode: CodeIssued.fromJson,
    );
  }

  /// `POST /account/password/forgot`: always 202, whether or not the address
  /// has an account.
  Future<void> forgotPassword(String email) async {
    await _client.value(
      '/account/password/forgot',
      method: 'POST',
      json: {'email': email},
      skipAuth: true,
      decode: (_) => null,
    );
  }

  /// `POST /account/password/reset`: all sessions of the account end. The
  /// [token] comes from the mailed link; it is never logged.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _client.noContent(
      '/account/password/reset',
      method: 'POST',
      json: {'token': token, 'newPassword': newPassword},
      skipAuth: true,
    );
  }

  /// `GET /account/password/policy`.
  Future<PasswordPolicy> passwordPolicy() => _client.value(
    '/account/password/policy',
    skipAuth: true,
    decode: PasswordPolicy.fromJson,
  );

  /// `GET /account/me`, reduced to what picks the deletion proof.
  Future<AccountMe> me() =>
      _client.value('/account/me', decode: AccountMe.fromJson);

  /// `PATCH /account/me` with a nickname. `400` field error on `displayName`,
  /// `409 ACCOUNT.DISPLAY_NAME_TAKEN`; a refused change changes nothing.
  Future<AccountMe> updateDisplayName(String displayName) => _client.value(
    '/account/me',
    method: 'PATCH',
    json: {'displayName': displayName},
    decode: AccountMe.fromJson,
  );

  /// `POST /account/delete/confirmation` (202): mails a 6-digit code to an
  /// account that has an address and no password. Nothing is sent to an
  /// account without an address (it uses [deleteAccount]'s `socialReauth`).
  Future<CodeIssued> requestDeleteConfirmation() {
    return _client.value(
      '/account/delete/confirmation',
      method: 'POST',
      decode: CodeIssued.fromJson,
    );
  }

  /// `POST /account/delete` (202). Send the one proof that fits the account:
  /// [currentPassword], else the mailed [confirmationCode], else (no address)
  /// [socialReauth] (`{provider, idToken | accessToken | authorizationCode,
  /// nonce?, ...}` as the social package builds it; its tokens are never
  /// logged). The same [idempotencyKey] on a retry of the same submit; `409
  /// ACCOUNT.DELETION_BLOCKED` when another module blocks it.
  Future<DeletionScheduled> deleteAccount({
    String? currentPassword,
    String? confirmationCode,
    Map<String, Object?>? socialReauth,
    required String idempotencyKey,
  }) {
    return _client.value(
      '/account/delete',
      method: 'POST',
      json: {
        'currentPassword': ?currentPassword,
        'confirmationCode': ?confirmationCode,
        'socialReauth': ?socialReauth,
      },
      headers: {'Idempotency-Key': idempotencyKey},
      decode: DeletionScheduled.fromJson,
    );
  }
}
