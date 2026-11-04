import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'social_credential.dart';

/// The backend calls of the app-token sign-in (kotlin `auth-social`) and the
/// token forms of social linking (`account`). Stores nothing.
class SocialAuthApi {
  SocialAuthApi(this._client);

  final ApiClient _client;

  /// `POST /auth/social/{provider}/token`: the same answer as a password
  /// login. Nothing is stored here; the caller hands the result to
  /// `AuthSession.signInWith` once it holds a server-checked answer.
  Future<AuthResult> login(String provider, SocialCredential credential) {
    return _client.value(
      '/auth/social/$provider/token',
      method: 'POST',
      json: credential.toJson(),
      skipAuth: true,
      decode: AuthResult.fromJson,
    );
  }

  /// `POST /account/identities/social/{provider}`: links the signed-in
  /// account to a provider account. The server needs a proof that the person
  /// is there: [proof] holds its fields (`currentPassword`,
  /// `confirmationCode` or `socialReauth`). Returns the new identity.
  Future<Map<String, Object?>> link(
    String provider,
    SocialCredential credential, {
    Map<String, Object?> proof = const {},
  }) {
    return _client.value(
      '/account/identities/social/$provider',
      method: 'POST',
      json: {...credential.toJson(), ...proof},
      decode: (json) => json,
    );
  }

  /// The `socialReauth` object of the account calls (delete, unlink, email
  /// change, ...): a fresh token of a provider already linked to this account.
  static Map<String, Object?> socialReauth(
    String provider,
    SocialCredential credential,
  ) => {'provider': provider, ...credential.toJson()};

  /// `GET /auth/methods`: the ids of the providers that take an app token
  /// (`nativeToken` is not null). A provider the server turned off is not in
  /// the list, so its button is never shown just to end in a 404.
  Future<Set<String>> nativeTokenProviders() {
    return _client.value(
      '/auth/methods',
      skipAuth: true,
      decode: (json) => {
        for (final item in [...?(json['social'] as List?)])
          if (item is Map<String, Object?> && item['nativeToken'] != null)
            item['provider']! as String,
      },
    );
  }
}
