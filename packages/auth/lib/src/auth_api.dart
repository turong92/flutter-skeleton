import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend calls of the `auth` and `auth-session` modules. Stores nothing.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// `POST /auth/login`. A wrong password is `AUTH.INVALID_CREDENTIALS`.
  Future<AuthResult> login({required String email, required String password}) {
    return _client.value(
      '/auth/login',
      method: 'POST',
      json: {'email': email, 'password': password},
      skipAuth: true,
      decode: AuthResult.fromJson,
    );
  }

  /// `POST /auth/refresh`: the refresh token is rotated, the old one is dead.
  Future<AuthResult> refresh(String refreshToken) {
    return _client.value(
      '/auth/refresh',
      method: 'POST',
      json: {'refreshToken': refreshToken},
      skipAuth: true,
      decode: AuthResult.fromJson,
    );
  }

  /// `POST /auth/logout`: always 204, also for an unknown token.
  Future<void> logout(String refreshToken) {
    return _client.noContent(
      '/auth/logout',
      method: 'POST',
      json: {'refreshToken': refreshToken},
      skipAuth: true,
    );
  }

  /// `GET /auth/me`.
  Future<Principal> me() =>
      _client.value('/auth/me', decode: Principal.fromJson);
}
