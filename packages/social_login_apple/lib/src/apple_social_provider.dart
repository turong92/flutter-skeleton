import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

bool _runsOnIOS() => !kIsWeb && Platform.isIOS;

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
    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialCancelled();
      }
      rethrow;
    }
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
    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(scopes: const []);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialCancelled();
      }
      rethrow;
    }
    await client.noContent(
      '/auth/social/apple/revoke',
      method: 'POST',
      json: {'authorizationCode': apple.authorizationCode},
    );
  }

  /// Apple keeps no SDK session to end.
  @override
  Future<void> signOut() async {}
}
