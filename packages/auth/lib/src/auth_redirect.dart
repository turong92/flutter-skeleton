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
String? authRedirectFor(
  AuthState state,
  String location, {
  String loginPath = '/login',
  String signedInPath = '/me',
  String splashPath = '/splash',
}) {
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
}) {
  return (context, routerState) => authRedirectFor(
    ref.read(authSessionProvider),
    routerState.matchedLocation,
    loginPath: loginPath,
    signedInPath: signedInPath,
    splashPath: splashPath,
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
