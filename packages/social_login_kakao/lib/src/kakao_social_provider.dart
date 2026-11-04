import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

/// Kakao's app SDK as a [SocialProvider] (server provider id `kakao`).
///
/// With the KakaoTalk app installed the person signs in through it; without it
/// (or when KakaoTalk fails for a reason other than the person backing out)
/// through the Kakao account page. Backing out of either is [SocialCancelled]:
/// a cancelled KakaoTalk login does not open the account page.
///
/// The app calls `KakaoSdk.init(nativeAppKey: ...)` itself before the first
/// sign-in, the way it initializes Firebase for push; this class does not.
/// The Kakao SDK takes no nonce, so the credential carries none.
class KakaoSocialProvider implements SocialProvider {
  KakaoSocialProvider()
    : _talkInstalled = isKakaoTalkInstalled,
      _talkLogin = _talk,
      _accountLogin = _account;

  /// For tests: the three SDK calls, each answering the access token.
  @visibleForTesting
  KakaoSocialProvider.withSdk({
    required Future<bool> Function() isTalkInstalled,
    required Future<String> Function() loginWithTalk,
    required Future<String> Function() loginWithAccount,
  }) : _talkInstalled = isTalkInstalled,
       _talkLogin = loginWithTalk,
       _accountLogin = loginWithAccount;

  final Future<bool> Function() _talkInstalled;
  final Future<String> Function() _talkLogin;
  final Future<String> Function() _accountLogin;

  static Future<String> _talk() async =>
      (await UserApi.instance.loginWithKakaoTalk()).accessToken;

  static Future<String> _account() async =>
      (await UserApi.instance.loginWithKakaoAccount()).accessToken;

  @override
  String get id => 'kakao';

  @override
  Future<SocialCredential> obtain(String nonce) async {
    try {
      if (await _talkInstalled()) {
        try {
          return SocialCredential.accessToken(await _talkLogin());
        } catch (e) {
          if (_isCancel(e)) throw const SocialCancelled();
          // Any other KakaoTalk failure: the account page still works.
        }
      }
      return SocialCredential.accessToken(await _accountLogin());
    } catch (e) {
      if (_isCancel(e)) throw const SocialCancelled();
      rethrow;
    }
  }

  /// Ends the Kakao session (`/v1/user/logout`) and clears the SDK's stored
  /// token. Nothing to do, and no error, when there was no session.
  @override
  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } on KakaoException {
      // No token or the token was already dead; the SDK cleared its store.
    }
  }

  // The native flow reports a back-out as PlatformException(code: CANCELED);
  // the web-style path as KakaoClientException(cancelled).
  static bool _isCancel(Object e) =>
      (e is PlatformException && e.code == 'CANCELED') ||
      (e is KakaoClientException && e.reason == ClientErrorCause.cancelled);
}
