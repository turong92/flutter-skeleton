import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'models.dart';

/// The backend calls of the `auth` and `auth-session` modules. Stores nothing.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// `POST /auth/login`. A wrong password is `AUTH.INVALID_CREDENTIALS`. Give
  /// an [email], or a [username] without `@` (a login ID, when the server has
  /// them on).
  Future<AuthResult> login({
    String? email,
    String? username,
    required String password,
  }) {
    assert(
      (email == null) != (username == null),
      'Give either an email or a username',
    );
    return _client.value(
      '/auth/login',
      method: 'POST',
      json: {'email': ?email, 'username': ?username, 'password': password},
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

  /// `GET /auth/methods` (public).
  Future<AuthMethods> methods() => _client.value(
    '/auth/methods',
    skipAuth: true,
    decode: AuthMethods.fromJson,
  );

  /// `GET /auth/me`.
  Future<Principal> me() =>
      _client.value('/auth/me', decode: Principal.fromJson);
}
