import 'package:google_sign_in/google_sign_in.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

/// Google through `google_sign_in` 7: `initialize(serverClientId)` once, then
/// `authenticate()` for an ID token.
///
/// [serverClientId] is the **web** OAuth client id of the Google Cloud project
/// (the server's `auth-social-google` `client-id`). With it the ID token's
/// `aud` is that web client id on Android and iOS alike. [clientId] is the
/// iOS client id; leave it null when `GIDClientID` is in `Info.plist`.
///
/// No nonce goes to Google: `google_sign_in` 7 takes one only in `initialize`
/// (once per app run), so a fresh value per sign-in is not possible. The
/// server compares a nonce only when the token has one.
class GoogleSocialProvider implements SocialProvider {
  GoogleSocialProvider({required this.serverClientId, this.clientId});

  final String serverClientId;
  final String? clientId;

  // `GoogleSignIn.instance.initialize` must run exactly once per app run.
  Future<void>? _initialized;

  @override
  String get id => 'google';

  @override
  Future<SocialCredential> obtain(String nonce) async {
    await (_initialized ??= GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    ));
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no ID token');
    }
    return SocialCredential.idToken(idToken);
  }

  @override
  Future<void> signOut() async {
    if (_initialized == null) return;
    await _initialized;
    await GoogleSignIn.instance.signOut();
  }
}
