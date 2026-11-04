import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

/// Naver's app SDK as a [SocialProvider] (server provider id `naver`).
///
/// `logIn()` then `getCurrentAccessToken()`; the access token goes to the
/// server as is, which checks it with Naver's profile API. The Naver SDK takes
/// no nonce. The SDK is configured by the platform files (client id, secret
/// and app name), not in Dart.
class NaverSocialProvider implements SocialProvider {
  @override
  String get id => 'naver';

  @override
  Future<SocialCredential> obtain(String nonce) async {
    final result = await FlutterNaverLogin.logIn();
    switch (result.status) {
      case NaverLoginStatus.loggedIn:
        break;
      case NaverLoginStatus.loggedOut:
        // Android answers a back-out with loggedOut.
        throw const SocialCancelled();
      case NaverLoginStatus.error:
        final message = result.errorMessage ?? '';
        // iOS answers a back-out with an error saying "cancelled".
        if (message.toLowerCase().contains('cancel')) {
          throw const SocialCancelled();
        }
        throw Exception('Naver sign-in failed: $message');
    }
    // Not printed anywhere: NaverToken.toString includes the tokens.
    final token = await FlutterNaverLogin.getCurrentAccessToken();
    if (token.accessToken.isEmpty) {
      throw Exception('Naver sign-in gave no access token');
    }
    return SocialCredential.accessToken(token.accessToken);
  }

  /// Ends the Naver session and deletes the SDK's stored tokens. Does nothing
  /// (and does not throw) when there was no session: the plugin answers a
  /// status, never an error.
  @override
  Future<void> signOut() async {
    await FlutterNaverLogin.logOutAndDeleteToken();
  }
}
