import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'deletion_pending_gate.dart';
import 'email_gate.dart';
import 'login_id_gate.dart';
import 'nickname_gate.dart';
import 'screens/account_screen.dart';
import 'screens/board_screens.dart';
import 'screens/deletion_pending_screen.dart';
import 'screens/email_screen.dart';
import 'screens/forgot_login_id_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_id_screen.dart';
import 'screens/login_screen.dart';
import 'screens/magic_link_screen.dart';
import 'screens/nickname_screen.dart';
import 'screens/notifications_screens.dart';
import 'screens/reset_password_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/social_link_screen.dart';
import 'screens/store_screen.dart';
import 'screens/verify_screen.dart';

/// Open in every sign-in state: a reset link survives the splash, and the
/// code screen is not left when the code signs the user in. The screens
/// navigate themselves afterwards.
const publicPaths = {
  '/sign-up',
  '/verify',
  '/forgot-password',
  '/reset-password',
  '/forgot-login-id',
  // A mailed sign-in link: the token is exchanged for a session on arrival.
  '/magic-link',
  // The offer to cancel a deletion is shown to someone not signed in.
  '/deletion-pending',
};

/// `/splash` while the stored tokens are checked, `/login` when signed out,
/// the board tab when signed in. The auth package decides that; `legal` adds
/// `/consent` while a document waits for agreement.
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
  // A 403 ACCOUNT.LOGIN_ID_REQUIRED only marks "choose an ID first".
  ref
      .read(apiClientProvider)
      .dio
      .interceptors
      .add(
        LoginIdRequiredInterceptor(
          onRequired: ref.read(needsLoginIdProvider.notifier).require,
        ),
      );
  // A 403 ACCOUNT.EMAIL_REQUIRED only marks "add an address first".
  ref
      .read(apiClientProvider)
      .dio
      .interceptors
      .add(
        EmailRequiredInterceptor(
          onRequired: ref.read(emailGateProvider.notifier).require,
        ),
      );
  // Whatever ends the session (sign-out, expiry, deletion) also ends a pending
  // agreement, or the next person to sign in is sent to /consent first.
  ref.listen(authSessionProvider, (_, next) {
    if (next is SignedOut) ref.read(reconsentProvider.notifier).clear();
  });

  final deletionGate = deletionPendingRedirect(ref);
  final authGate = authRedirect(
    ref,
    publicPaths: publicPaths,
    signedInPath: '/board',
  );
  final loginIdGate = loginIdRedirect(ref);
  final emailGate = emailRedirect(ref);
  final nicknameGate = nicknameRedirect(ref);
  final consentGate = reconsentRedirect(ref, homePath: '/board');
  // The account gates, in the server's order (ID -> email -> consent): the
  // first one that is up decides, so a later gate does not pull the person off
  // the screen of an earlier one. The nickname is the app's own and comes last.
  // The email gate stops writes only on a server that asks at write time; it
  // is up then only after the person opened it (see `email_gate.dart`).
  FutureOr<String?> accountGates(BuildContext context, GoRouterState state) {
    if (ref.read(needsLoginIdProvider)) return loginIdGate(context, state);
    if (ref.read(emailGateProvider).open) return emailGate(context, state);
    if (ref.read(reconsentProvider).isNotEmpty) {
      return consentGate(context, state);
    }
    if (ref.read(needsNicknameProvider)) return nicknameGate(context, state);
    // Nothing is up: consentGate sends someone still on /consent back.
    return consentGate(context, state);
  }

  final router = GoRouter(
    initialLocation: '/board',
    // A link the app has no route for (a server link, an old push) lands on
    // the inbox. The sign-in and gate redirects still come first.
    onException: (context, state, router) => router.go('/notifications'),
    // The gates are for a signed-in account. They clear a moment after the
    // session ends; until then a signed-out router must not be sent to a gate
    // screen, or it bounces between that and /login for ever.
    redirect: (context, state) =>
        deletionGate(context, state) ??
        authGate(context, state) ??
        (ref.read(authSessionProvider) is SignedIn
            ? accountGates(context, state)
            : null),
    refreshListenable: Listenable.merge([
      authRefreshListenable(ref),
      deletionPendingRefreshListenable(ref),
      loginIdRefreshListenable(ref),
      emailRefreshListenable(ref),
      nicknameRefreshListenable(ref),
      reconsentRefreshListenable(ref),
    ]),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
        path: '/forgot-login-id',
        builder: (context, state) => const ForgotLoginIdScreen(),
      ),
      GoRoute(
        path: '/magic-link',
        builder: (context, state) =>
            MagicLinkScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/social',
        builder: (context, state) => const SocialLinkScreen(),
      ),
      GoRoute(
        path: '/nickname',
        builder: (context, state) => const NicknameScreen(),
      ),
      GoRoute(
        path: '/login-id',
        builder: (context, state) => const LoginIdScreen(),
      ),
      GoRoute(path: '/email', builder: (context, state) => const EmailScreen()),
      GoRoute(
        path: '/deletion-pending',
        builder: (context, state) => const DeletionPendingScreen(),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => ReconsentScreen(
            // The way out for someone who will not agree.
            onLeave: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
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
                        // The post comes with the tap; a pasted link opens the
                        // post itself.
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/store',
                builder: (context, state) => const StoreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        const NotificationSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
