import 'dart:convert';
import 'dart:math';

/// What a provider's app SDK returned: exactly one token, plus the raw nonce
/// the server must compare when the provider takes one.
///
/// [idToken] is for providers whose `nativeToken` is `id_token` (Google,
/// Apple), [accessToken] for `access_token` (Kakao, Naver).
///
/// [toString] never prints a value: a credential that lands in a log line, an
/// exception message or a debugger watch must not leak.
class SocialCredential {
  const SocialCredential.idToken(
    String this.idToken, {
    this.nonce,
    this.displayName,
  }) : accessToken = null;

  const SocialCredential.accessToken(String this.accessToken, {this.nonce})
    : idToken = null,
      displayName = null;

  final String? idToken;
  final String? accessToken;

  /// The raw nonce (not its hash) that was given to [SocialProvider.obtain].
  final String? nonce;

  /// A name the SDK gave that the token leaves out (Apple, first sign-in
  /// only). The server uses it only as the nickname of a new account.
  final String? displayName;

  /// The request fields the server reads (`POST /auth/social/{p}/token`, and
  /// the same keys in a link call or a `socialReauth` object).
  Map<String, Object?> toJson() => {
    'idToken': ?idToken,
    'accessToken': ?accessToken,
    'nonce': ?nonce,
    'displayName': ?displayName,
  };

  @override
  String toString() => 'SocialCredential(<redacted>)';
}

/// The person closed the provider's sign-in screen. Not an error: nothing is
/// shown and nothing is sent.
class SocialCancelled implements Exception {
  const SocialCancelled();

  @override
  String toString() => 'SocialCancelled()';
}

/// One provider's app SDK. A provider package implements it.
abstract interface class SocialProvider {
  /// The server's provider id (`google`, `apple`, `kakao`, `naver`): the
  /// `{provider}` of the paths and the `provider` of `GET /auth/methods`.
  String get id;

  /// Opens the SDK's sign-in and returns its token. [nonce] is a fresh raw
  /// value; a provider that binds a nonce into its token hands the SDK what it
  /// needs and returns the raw value in the credential. Throws
  /// [SocialCancelled] when the person backs out.
  Future<SocialCredential> obtain(String nonce);

  /// Ends the SDK's own session (called on sign-out). Must not throw for a
  /// provider that has no session.
  Future<void> signOut();
}

/// 32 random bytes as unpadded base64url (43 characters, inside the server's
/// 8-256 printable ASCII rule). [random] is for tests; the default is
/// [Random.secure].
String generateSocialNonce([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
