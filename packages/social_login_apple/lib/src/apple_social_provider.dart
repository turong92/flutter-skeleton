import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

bool _runsOnIOS() => !kIsWeb && Platform.isIOS;

/// What one Apple sheet gave for a delete: see
/// [AppleSocialProvider.obtainForDelete]. Prints nothing secret.
class AppleDeleteProof {
  const AppleDeleteProof(this.credential, this.authorizationCode);

  final SocialCredential credential;

  /// For [AppleSocialProvider.revokeWithCode]. Never log it.
  final String authorizationCode;

  @override
  String toString() => 'AppleDeleteProof(<redacted>)';
}

/// Sign in with Apple (`sign_in_with_apple` 8) for the iOS app.
///
/// The first version offers Apple on iOS only (the kotlin `auth-social-apple`
/// module takes the app's identityToken; Android and web Apple need a Services
/// ID and a callback and are a later step). Show the button only when
/// [isVisible] is true.
class AppleSocialProvider implements SocialProvider {
  /// [isIOS] decides [isVisible]; tests pass their own.
  AppleSocialProvider({bool Function()? isIOS}) : _isIOS = isIOS ?? _runsOnIOS;

  final bool Function() _isIOS;

  /// True on iOS. The sample shows its Sign in with Apple button only then.
  bool get isVisible => _isIOS();

  @override
  String get id => 'apple';

  /// The SDK gets `sha256(nonce)` (hex) and puts it in the identityToken's
  /// `nonce` claim; the server gets the raw [nonce] and hashes it to compare.
  @override
  Future<SocialCredential> obtain(String nonce) async {
    final apple = await _sheet([
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ], _hashed(nonce));
    final identityToken = apple.identityToken;
    if (identityToken == null) {
      throw StateError('Apple returned no identity token');
    }
    // Apple gives the name on the first authorization of this app only.
    final name = [
      apple.givenName,
      apple.familyName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return SocialCredential.idToken(
      identityToken,
      nonce: nonce,
      displayName: name.isEmpty ? null : name,
    );
  }

  /// Revokes the person's Apple tokens (App Review: an app with Sign in with
  /// Apple must do this when the account is deleted). Run it before
  /// `POST /account/delete`.
  ///
  /// Opens the Apple sheet once more for a fresh `authorizationCode`, then
  /// `POST /auth/social/apple/revoke {authorizationCode}` (signed in, `204`).
  /// Throws [SocialCancelled] when the person backs out: do not delete then.
  /// A revoke without a delete does no harm (the next Apple sign-in asks for
  /// consent again and arrives as the same `sub`). Server failures are
  /// [ApiRequestError]s (`401 AUTH_SOCIAL.INVALID_AUTHORIZATION_CODE`, `404`
  /// Apple is off for this project, `502` Apple failed).
  Future<void> revokeBeforeDelete(ApiClient client) async {
    final apple = await _sheet(const [], null);
    await revokeWithCode(client, apple.authorizationCode);
  }

  /// One Apple sheet that serves both halves of a delete: the
  /// [AppleDeleteProof.credential] (`identityToken` + raw [nonce]) goes in the
  /// delete call's `socialReauth`, the [AppleDeleteProof.authorizationCode]
  /// goes to [revokeWithCode]. Use it when the account is proven by its Apple
  /// sign-in, so the person sees one sheet, not two (a second sheet right
  /// after a revoke would link the app again). Throws [SocialCancelled] when
  /// the person backs out.
  Future<AppleDeleteProof> obtainForDelete(String nonce) async {
    final apple = await _sheet(const [], _hashed(nonce));
    final identityToken = apple.identityToken;
    if (identityToken == null) {
      throw StateError('Apple returned no identity token');
    }
    return AppleDeleteProof(
      SocialCredential.idToken(identityToken, nonce: nonce),
      apple.authorizationCode,
    );
  }

  /// `POST /auth/social/apple/revoke {authorizationCode}` with a code from
  /// [obtainForDelete] (signed in, `204`). Errors as in [revokeBeforeDelete].
  Future<void> revokeWithCode(ApiClient client, String authorizationCode) {
    return client.noContent(
      '/auth/social/apple/revoke',
      method: 'POST',
      json: {'authorizationCode': authorizationCode},
    );
  }

  static String _hashed(String nonce) =>
      sha256.convert(utf8.encode(nonce)).toString();

  Future<AuthorizationCredentialAppleID> _sheet(
    List<AppleIDAuthorizationScopes> scopes,
    String? hashedNonce,
  ) async {
    try {
      return await SignInWithApple.getAppleIDCredential(
        scopes: scopes,
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialCancelled();
      }
      rethrow;
    }
  }

  /// Apple keeps no SDK session to end.
  @override
  Future<void> signOut() async {}
}
