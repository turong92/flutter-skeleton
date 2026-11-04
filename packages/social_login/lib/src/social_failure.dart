import 'package:skeleton_api_client/skeleton_api_client.dart';

/// `ApiError.code` of the app-token sign-in that this package branches on
/// (kotlin `auth-social`, `account`).
abstract final class SocialErrorCodes {
  /// 409: the provider's email belongs to an existing account. Never merged:
  /// sign in with that account and link the provider in settings.
  static const emailConflict = 'ACCOUNT.SOCIAL_EMAIL_CONFLICT';

  /// 409: no account is linked to this provider account and sign-up is off.
  static const accountLinkNotFound = 'AUTH_SOCIAL.ACCOUNT_LINK_NOT_FOUND';

  /// 401: the ID token failed (signature, issuer, audience, expiry, nonce).
  static const idTokenInvalid = 'AUTH.SOCIAL_ID_TOKEN_INVALID';

  /// 401: the provider refused the access token, or it was issued to another
  /// app.
  static const accessTokenInvalid = 'AUTH.SOCIAL_ACCESS_TOKEN_INVALID';

  /// 404: the provider is off on the server, or has no app-token entrance.
  static const providerNotFound = 'AUTH_SOCIAL.PROVIDER_NOT_FOUND';

  /// 502: the provider or its key set is down.
  static const providerGatewayError = 'AUTH_SOCIAL.PROVIDER_GATEWAY_ERROR';

  /// 403: the account is in its deletion grace.
  static const accountDeletionPending = 'AUTH.ACCOUNT_DELETION_PENDING';

  /// 403: the provider account is on the re-registration block list.
  static const registrationBlocked = 'ACCOUNT.REGISTRATION_BLOCKED';

  /// 403: a second step is needed before tokens are given.
  static const mfaRequired = 'AUTH.MFA_REQUIRED';
}

/// Why a social sign-in did not happen, in the groups an app writes different
/// text for. Cancelling is not one of them.
enum SocialFailure {
  /// "An account with that email exists. Sign in with it, then link this
  /// provider in settings."
  emailConflict,

  /// "No account with this provider yet" (sign-up is closed on the server).
  notLinked,

  /// The server refused the token (expired, wrong app). Try again.
  tokenRejected,

  /// The provider is off on the server. Hide its button.
  providerNotAvailable,

  /// The provider or the server's check of it is down. Try later.
  providerDown,

  /// Suspended, or on the re-registration block list.
  blocked,

  /// The account is in its deletion grace.
  deletionPending,

  /// A second step is required.
  mfaRequired,

  /// No answer from the server.
  network,

  /// The provider's SDK failed (not a cancel).
  sdk,

  /// Anything else; read [SocialLoginFailed.error].
  other,
}

/// Sorts a failed server call into a [SocialFailure].
SocialFailure socialFailureOf(ApiRequestError error) {
  return switch (error.code) {
    SocialErrorCodes.emailConflict => SocialFailure.emailConflict,
    SocialErrorCodes.accountLinkNotFound => SocialFailure.notLinked,
    SocialErrorCodes.idTokenInvalid ||
    SocialErrorCodes.accessTokenInvalid => SocialFailure.tokenRejected,
    SocialErrorCodes.providerNotFound => SocialFailure.providerNotAvailable,
    SocialErrorCodes.providerGatewayError => SocialFailure.providerDown,
    ErrorCodes.authAccountSuspended ||
    SocialErrorCodes.registrationBlocked => SocialFailure.blocked,
    SocialErrorCodes.accountDeletionPending => SocialFailure.deletionPending,
    SocialErrorCodes.mfaRequired => SocialFailure.mfaRequired,
    ClientErrorCodes.networkError => SocialFailure.network,
    _ => SocialFailure.other,
  };
}
