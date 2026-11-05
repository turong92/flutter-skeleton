import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_api.dart';
import 'account_models.dart';
import 'auth_api.dart';
import 'auth_client.dart';
import 'models.dart';
import 'sign_out_hooks.dart';
import 'sign_up_attempt_store.dart';
import 'token_store.dart';

/// What the app gives the auth package. The providers below throw until the
/// app overrides them in its `ProviderScope`.
class AuthConfig {
  const AuthConfig({required this.apiBaseUrl});

  /// Backend API root including `/api/v1`, e.g. `https://api.example.com/api/v1`.
  final String apiBaseUrl;
}

final authConfigProvider = Provider<AuthConfig>(
  (ref) => throw UnimplementedError(
    'Override authConfigProvider in the ProviderScope',
  ),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError(
    'Override tokenStoreProvider in the ProviderScope',
  ),
);

/// The HTTP adapter under the client. Null is Dio's default; tests put a fake
/// here.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// The client for the whole app: Bearer header, silent refresh on 401.
final apiClientProvider = Provider<ApiClient>((ref) {
  return createAuthClient(
    baseUrl: ref.watch(authConfigProvider).apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
    adapter: ref.watch(httpAdapterProvider),
    onSessionEnded: () => ref.read(authSessionProvider.notifier).sessionEnded(),
  );
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final accountApiProvider = Provider<AccountApi>(
  (ref) => AccountApi(ref.watch(apiClientProvider)),
);

/// Where a pending sign-up is kept. The app overrides it (for example with
/// `SecureSignUpAttemptStore()`); only the sign-up screens read it.
final signUpAttemptStoreProvider = Provider<SignUpAttemptStore>(
  (ref) => throw UnimplementedError(
    'Override signUpAttemptStoreProvider in the ProviderScope',
  ),
);

/// Things to do just before a sign-out; other packages call `add` on it.
final signOutHooksProvider = Provider<SignOutHooks>((ref) => SignOutHooks());

/// `GET /account/password/policy`, read once for the hints.
final passwordPolicyProvider = FutureProvider<PasswordPolicy>(
  (ref) => ref.watch(accountApiProvider).passwordPolicy(),
);

/// `GET /account/me` for the signed-in account (nickname, tag). Invalidate it
/// after a change.
final accountMeProvider = FutureProvider.autoDispose<AccountMe>(
  (ref) => ref.watch(accountApiProvider).me(),
);

final authSessionProvider = NotifierProvider<AuthSession, AuthState>(
  AuthSession.new,
);

class AuthSession extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthChecking();
  }

  /// App start: stored tokens are checked with `GET /auth/me` (which renews an
  /// expired access token on the way). Never leaves the app on the splash: when
  /// the check fails the user lands on the login screen. A failure that is not
  /// the server ending the session (offline) keeps the stored tokens for the
  /// next start. Errors other than API/network ones are also reported.
  Future<void> _restore() async {
    try {
      final tokens = await ref.read(tokenStoreProvider).read();
      if (tokens == null) return _set(const SignedOut());
      final principal = await ref.read(authApiProvider).me();
      _set(SignedIn(principal));
    } catch (e, stackTrace) {
      // Whatever went wrong, never stay on the splash.
      if (ref.mounted && state is AuthChecking) state = const SignedOut();
      if (e is! ApiRequestError) {
        // An API or network failure is expected; anything else is a bug or a
        // broken keystore and must be seen.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stackTrace,
            library: 'skeleton_auth',
            context: ErrorDescription('while restoring the session'),
          ),
        );
      }
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await ref
        .read(authApiProvider)
        .login(email: email, password: password);
    await signInWith(result);
  }

  /// Takes a sign-in the app already has (the code check of a sign-up is a
  /// login): stores the tokens and signs in.
  Future<void> signInWith(AuthResult result) async {
    await ref.read(tokenStoreProvider).save(result.tokens);
    _set(SignedIn(result.principal));
  }

  /// Ends the server session when it can, and always signs out locally. The
  /// sign-out hooks run first, while the tokens still work.
  Future<void> logout() async {
    await ref.read(signOutHooksProvider).run();
    final store = ref.read(tokenStoreProvider);
    final tokens = await store.read();
    if (tokens != null) {
      try {
        await ref.read(authApiProvider).logout(tokens.refreshToken);
      } on ApiRequestError {
        // Offline or a server error: the local sign-out must not depend on it.
      }
    }
    await store.clear();
    _set(const SignedOut());
  }

  /// Signs out on this device only, with no server call and no hooks: for when
  /// the server already ended every session (password reset, account
  /// deletion).
  Future<void> signOutLocally() async {
    await ref.read(tokenStoreProvider).clear();
    _set(const SignedOut());
  }

  /// The refresh failed for good (the interceptor already cleared the store).
  void sessionEnded() => _set(const SignedOut());

  void _set(AuthState next) {
    if (ref.mounted) state = next;
  }
}
