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
    String? loginId,
    List<ConsentClaim> consents = const [],
  }) {
    return _client.value(
      '/account/sign-up',
      method: 'POST',
      json: {
        'email': email,
        'password': password,
        'displayName': ?displayName,
        'loginId': ?loginId,
        if (consents.isNotEmpty)
          'consents': [for (final c in consents) c.toJson()],
      },
      skipAuth: true,
      decode: SignUpOutcome.fromJson,
    );
  }

  /// `POST /auth/verify-email`: the right code creates the account and signs
  /// in. `400 ACCOUNT.CODE_INVALID` (see [attemptsLeftOf]), `410
  /// ACCOUNT.CODE_EXPIRED`. A `409` on the nickname or the login ID does not
  /// use the attempt up: repeat with the same [signUpId] and [code] and a new
  /// [displayName] / [loginId].
  Future<AuthResult> verifyEmail({
    required String signUpId,
    required String code,
    String? displayName,
    String? loginId,
  }) {
    return _client.value(
      '/auth/verify-email',
      method: 'POST',
      json: {
        'signUpId': signUpId,
        'code': code,
        'displayName': ?displayName,
        'loginId': ?loginId,
      },
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

  /// `POST /account/login-id/forgot` (public): always 202, whether or not the
  /// address has an account. `429` only for the client IP.
  Future<void> forgotLoginId(String email) async {
    await _client.value(
      '/account/login-id/forgot',
      method: 'POST',
      json: {'email': email},
      skipAuth: true,
      decode: (_) => null,
    );
  }

  /// `POST /account/contact-email` (202): mails a 6-digit code to [email].
  /// Calling again is the resend. 404 when the server has the feature off
  /// (`me.contactEmail` is absent then). An account without an address
  /// must send [socialReauth] (`403 ACCOUNT.REAUTH_REQUIRED` otherwise).
  Future<CodeIssued> requestContactEmail(
    String email, {
    Map<String, Object?>? socialReauth,
  }) {
    return _client.value(
      '/account/contact-email',
      method: 'POST',
      json: {'email': email, 'socialReauth': ?socialReauth},
      decode: CodeIssued.fromJson,
    );
  }

  /// `POST /account/contact-email/confirm` (204): sets (or changes) the
  /// contact address. `400 ACCOUNT.CODE_INVALID`, `410 ACCOUNT.CODE_EXPIRED`.
  Future<void> confirmContactEmail(String code) => _client.noContent(
    '/account/contact-email/confirm',
    method: 'POST',
    json: {'code': code},
  );

  /// `DELETE /account/contact-email` (204, also when there was none).
  Future<void> removeContactEmail() =>
      _client.noContent('/account/contact-email', method: 'DELETE');

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

  /// `PATCH /account/me { avatarKey }`: a key sets the profile picture, null
  /// clears it. Only on a server with `storage`; elsewhere `400`. A `400`
  /// without field errors means the key is not usable (not this account's
  /// upload, not an image, or a file another place already uses).
  Future<AccountMe> updateAvatar(String? key) => _client.value(
    '/account/me',
    method: 'PATCH',
    json: {'avatarKey': key},
    decode: AccountMe.fromJson,
  );

  /// `GET /account/me/avatar`: a short-lived signed address of the picture.
  /// `404` without a picture, while it converts, or with signed reads off.
  Future<AvatarAddress> avatarAddress() =>
      _client.value('/account/me/avatar', decode: AvatarAddress.fromJson);

  /// `PATCH /account/me` with a nickname. `400` field error on `displayName`,
  /// `409 ACCOUNT.DISPLAY_NAME_TAKEN`; a refused change changes nothing.
  Future<AccountMe> updateDisplayName(String displayName) => _client.value(
    '/account/me',
    method: 'PATCH',
    json: {'displayName': displayName},
    decode: AccountMe.fromJson,
  );

  /// `POST /account/login-id/availability` (public, always 200; 429 when asked
  /// too often). Sends the candidate, so never log it.
  Future<LoginIdAvailability> checkLoginId(String loginId) => _client.value(
    '/account/login-id/availability',
    method: 'POST',
    json: {'loginId': loginId},
    decode: LoginIdAvailability.fromJson,
  );

  /// `POST /account/login-id`: chooses the login ID, once (there is no
  /// change). Works without an email address. `400` field error on `loginId`,
  /// `409 ACCOUNT.LOGIN_ID_TAKEN`, `409 ACCOUNT.LOGIN_ID_ALREADY_SET`.
  Future<AccountMe> setLoginId(String loginId) => _client.value(
    '/account/login-id',
    method: 'POST',
    json: {'loginId': loginId},
    decode: AccountMe.fromJson,
  );

  /// `POST /account/delete/cancel` (public): the account of a sign-in that
  /// answered `403 AUTH.ACCOUNT_DELETION_PENDING` is active again and the
  /// answer is a login. `410 ACCOUNT.TOKEN_INVALID` (used, expired, the grace
  /// ended, suspended meanwhile): sign in again. The [restoreToken] is never
  /// logged.
  Future<AuthResult> cancelDeletion(String restoreToken) {
    return _client.value(
      '/account/delete/cancel',
      method: 'POST',
      json: {'restoreToken': restoreToken},
      skipAuth: true,
      decode: AuthResult.fromJson,
    );
  }

  /// `POST /account/email/change` (202): mails a 6-digit code to [newEmail]
  /// (the same answer for an address another account owns: the code never
  /// comes). Calling again is the resend. A session older than an hour gets
  /// `403 ACCOUNT.REAUTH_REQUIRED` for the first address: send [socialReauth]
  /// (a fresh provider token, as the social package builds it). The call is
  /// `@IdempotentOperation` on the server: one press uses one
  /// [idempotencyKey] (also for the reauth retry), a resend a new one.
  Future<CodeIssued> requestEmailChange(
    String newEmail, {
    required String idempotencyKey,
    Map<String, Object?>? socialReauth,
  }) {
    return _client.value(
      '/account/email/change',
      method: 'POST',
      json: {'newEmail': newEmail, 'socialReauth': ?socialReauth},
      headers: {'Idempotency-Key': idempotencyKey},
      decode: CodeIssued.fromJson,
    );
  }

  /// `POST /account/email/change/confirm` (204): the address is registered
  /// and `me` stops asking for one. `400 ACCOUNT.CODE_INVALID` (see
  /// [attemptsLeftOf]), `410 ACCOUNT.CODE_EXPIRED`.
  Future<void> confirmEmailChange(String code) => _client.noContent(
    '/account/email/change/confirm',
    method: 'POST',
    json: {'code': code},
  );

  /// `POST /account/discard` (204): drops an account that has no address and
  /// has written nothing, at once and for good (the social login is free
  /// again; a login ID it chose can never be taken again). All sessions end:
  /// sign out locally. `409 ACCOUNT.DISCARD_NOT_ALLOWED`; an old session gets
  /// `403 ACCOUNT.REAUTH_REQUIRED` (send [socialReauth]); `503
  /// ACCOUNT.ERASURE_RETRY`: repeat the call with the same [idempotencyKey].
  Future<void> discard({
    Map<String, Object?>? socialReauth,
    required String idempotencyKey,
  }) {
    return _client.noContent(
      '/account/discard',
      method: 'POST',
      json: {'socialReauth': ?socialReauth},
      headers: {'Idempotency-Key': idempotencyKey},
    );
  }

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
