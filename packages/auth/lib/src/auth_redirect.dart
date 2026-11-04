import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_session.dart';
import 'models.dart';

/// Where [state] sends a user who asks for [location]; null = stay.
///
/// - checking: the splash route
/// - signed out: the login route
/// - signed in: off the login and splash routes, to [signedInPath]
///
/// [publicPaths] (sign-up, verify, forgot and reset password) stay open in
/// every state, so a reset link survives the splash and a signed-out user can
/// reach the account pages.
String? authRedirectFor(
  AuthState state,
  String location, {
  String loginPath = '/login',
  String signedInPath = '/me',
  String splashPath = '/splash',
  Set<String> publicPaths = const {},
}) {
  if (publicPaths.contains(location)) return null;
  switch (state) {
    case AuthChecking():
      return location == splashPath ? null : splashPath;
    case SignedOut():
      return location == loginPath ? null : loginPath;
    case SignedIn():
      return location == loginPath || location == splashPath
          ? signedInPath
          : null;
  }
}

/// `GoRouter(redirect: authRedirect(ref), refreshListenable: authRefreshListenable(ref))`
GoRouterRedirect authRedirect(
  Ref ref, {
  String loginPath = '/login',
  String signedInPath = '/me',
  String splashPath = '/splash',
  Set<String> publicPaths = const {},
}) {
  return (context, routerState) => authRedirectFor(
    ref.read(authSessionProvider),
    routerState.matchedLocation,
    loginPath: loginPath,
    signedInPath: signedInPath,
    splashPath: splashPath,
    publicPaths: publicPaths,
  );
}

/// Makes the router re-run its redirect whenever the auth state changes.
Listenable authRefreshListenable(Ref ref) {
  final notifier = _AuthChanged();
  ref.listen(authSessionProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _AuthChanged extends ChangeNotifier {
  void changed() => notifyListeners();
}
