import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'form_page.dart';

/// The pending sign-up, read from the attempt store: it is still there after
/// the OS killed the app. No (or an expired) attempt sends the user back.
final _attemptProvider = FutureProvider.autoDispose<SignUpAttempt?>(
  (ref) => restoreSignUpAttempt(ref.watch(signUpAttemptStoreProvider)),
);

/// The code screen. A right code signs in; the sign-up pages are public paths,
/// so the screen moves on by itself.
class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_attemptProvider)
        .when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (_, _) => const Scaffold(body: LoadingView()),
          data: (attempt) {
            if (attempt == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/sign-up');
              });
              return const Scaffold(body: LoadingView());
            }
            return FormPage(
              title: 'Check your email',
              children: [
                VerifyCodeForm(
                  attempt: attempt,
                  onVerified: () => context.go('/board'),
                  onExpired: () => context.go('/sign-up'),
                ),
              ],
            );
          },
        );
  }
}
