/// `ApiError.code` values the backend (kotlin-skeleton) really emits and this
/// skeleton branches on. Add one only together with the Kotlin enum entry it
/// mirrors; do not invent codes.
abstract final class ErrorCodes {
  // modules/platform common/ErrorCode.kt
  static const commonValidationFailed = 'COMMON.VALIDATION_FAILED';
  static const commonUnauthorized = 'COMMON.UNAUTHORIZED';

  // modules/auth AuthErrorCode, modules/auth-session AuthSessionErrorCode
  static const authInvalidCredentials = 'AUTH.INVALID_CREDENTIALS';
  static const authRefreshInvalid = 'AUTH.REFRESH_INVALID';
  static const authRefreshReused = 'AUTH.REFRESH_REUSED';
  static const authAccountSuspended = 'AUTH.ACCOUNT_SUSPENDED';

  /// 429 on refresh: the session is fine, wait (`Retry-After`).
  static const authTooManyRefreshes = 'AUTH.TOO_MANY_REFRESHES';
}

/// Codes made by this client, not by the backend. The status is 0 for a
/// failure without a response.
abstract final class ClientErrorCodes {
  /// A response that is not the `ApiError` contract (a proxy page, a missing
  /// envelope key).
  static const httpError = 'CLIENT.HTTP_ERROR';

  /// No response at all: network, timeout, cancel. Status 0.
  static const networkError = 'CLIENT.NETWORK_ERROR';
}
