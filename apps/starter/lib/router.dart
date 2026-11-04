import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'screens/login_screen.dart';
import 'screens/me_screen.dart';

/// `/splash` while the stored tokens are checked, `/login` when signed out,
/// `/me` when signed in. The redirect is the auth package's.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/me',
    redirect: authRedirect(ref),
    refreshListenable: authRefreshListenable(ref),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
