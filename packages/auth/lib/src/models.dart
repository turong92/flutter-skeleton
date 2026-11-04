import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'token_store.dart';

/// `CurrentPrincipal` of the backend `auth` module (`/auth/me`, and inside the
/// login and refresh responses).
class Principal {
  const Principal({
    required this.accountId,
    this.username,
    this.email,
    this.roles = const [],
    this.permissions = const [],
    this.sessionId,
  });

  factory Principal.fromJson(Map<String, Object?> json) => Principal(
    accountId: json['accountId']! as String,
    username: json['username'] as String?,
    email: json['email'] as String?,
    roles: [...?(json['roles'] as List?)?.cast<String>()],
    permissions: [...?(json['permissions'] as List?)?.cast<String>()],
    sessionId: json['sessionId'] as String?,
  );

  final String accountId;
  final String? username;
  final String? email;
  final List<String> roles;

  /// Operator permission keys. Only for hiding menus; the server decides.
  final List<String> permissions;
  final String? sessionId;
}

/// The login / refresh response (`AuthTokenResponse`) in body-delivery mode.
class AuthResult {
  const AuthResult({required this.tokens, required this.principal});

  factory AuthResult.fromJson(Map<String, Object?> json) {
    final refresh = json['refreshToken'];
    if (refresh is! String) {
      // auth-session missing, or cookie delivery: this skeleton needs the body.
      throw ApiRequestError.http(
        200,
        detail: 'No refreshToken in the response (auth-session with delivery=body is required)',
      );
    }
    return AuthResult(
      tokens: TokenPair(
        accessToken: json['accessToken']! as String,
        refreshToken: refresh,
      ),
      principal: Principal.fromJson(json['principal']! as Map<String, Object?>),
    );
  }

  final TokenPair tokens;
  final Principal principal;
}

/// What the app knows about the login.
sealed class AuthState {
  const AuthState();
}

/// Stored tokens are being checked (the splash).
class AuthChecking extends AuthState {
  const AuthChecking();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.principal);

  final Principal principal;
}
