import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if board
import 'package:skeleton_board/skeleton_board.dart';
// #endif
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'screens/account_screen.dart';
// #if board
import 'screens/board_screens.dart';
// #endif
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/me_screen.dart';
// #if iap
import 'screens/store_screen.dart';
// #endif
// #if push
import 'screens/notification_settings_screen.dart';
// #endif
// #if notifications
import 'screens/notifications_screen.dart';
// #endif
import 'screens/reset_password_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/verify_screen.dart';

/// Open in every sign-in state: a reset link survives the splash, and the
/// code screen is not left when the code signs the user in. The screens
/// navigate themselves afterwards.
const publicPaths = {
  '/sign-up',
  '/verify',
  '/forgot-password',
  '/reset-password',
};

/// `/splash` while the stored tokens are checked, `/login` when signed out,
/// `/me` when signed in. The auth package decides that; `legal` adds `/consent`
/// while a document waits for agreement.
final routerProvider = Provider<GoRouter>((ref) {
  // A 403 LEGAL.RECONSENT_REQUIRED only marks "agree first"; the session lives.
  ref
      .read(apiClientProvider)
      .dio
      .interceptors
      .add(
        ReconsentInterceptor(
          onRequired: ref.read(reconsentProvider.notifier).require,
        ),
      );
  // Whatever ends the session (sign-out, expiry, deletion) also ends a pending
  // agreement, or the next person to sign in is sent to /consent first.
  ref.listen(authSessionProvider, (_, next) {
    if (next is SignedOut) ref.read(reconsentProvider.notifier).clear();
  });

  final authGate = authRedirect(ref, publicPaths: publicPaths);
  final consentGate = reconsentRedirect(ref, homePath: '/me');
  final router = GoRouter(
    initialLocation: '/me',
    redirect: (context, state) =>
        authGate(context, state) ?? consentGate(context, state),
    refreshListenable: Listenable.merge([
      authRefreshListenable(ref),
      reconsentRefreshListenable(ref),
    ]),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerifyScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      // #if iap
      GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
      // #endif
      // #if push
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      // #endif
      // #if notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // #endif
      // #if board
      GoRoute(
        path: '/board',
        builder: (context, state) => const BoardListScreen(),
        routes: [
          // `new` before `:id`, or "new" would be read as a post id.
          GoRoute(
            path: 'new',
            builder: (context, state) => const PostEditorScreen(),
          ),
          GoRoute(
            path: ':id',
            redirect: (context, state) =>
                int.tryParse(state.pathParameters['id']!) == null
                ? '/board'
                : null,
            builder: (context, state) => PostDetailScreen(
              postId: int.parse(state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                // The post comes with the tap; a pasted link opens the post itself.
                redirect: (context, state) => state.extra is PostDetail
                    ? null
                    : '/board/${state.pathParameters['id']}',
                builder: (context, state) =>
                    PostEditorScreen(post: state.extra! as PostDetail),
              ),
            ],
          ),
        ],
      ),
      // #endif
      GoRoute(
        path: '/consent',
        builder: (context, state) => ReconsentScreen(
          onLeave: ref.read(authSessionProvider.notifier).logout,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
