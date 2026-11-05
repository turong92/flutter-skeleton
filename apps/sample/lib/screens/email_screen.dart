import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../email_gate.dart';
import '../social_support.dart';
import 'form_page.dart';

/// Where an account without an address lands (see `email_gate.dart`). When the
/// server asks for the address right after sign-in the only ways out are
/// registering, discarding the account (for someone who already has another)
/// and signing out; when it asks only for changes the screen can be closed.
class EmailScreen extends ConsumerWidget {
  const EmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(emailGateProvider);
    return FormPage(
      title: 'Add your email',
      children: [
        Text(
          gate.blocking
              ? 'This service needs your email address before it goes on.'
              : 'Changes need your email address. Reading works without it.',
        ),
        const SizedBox(height: SkeletonSpace.md),
        EmailRegisterForm(
          socialReauth: () => reauthWithLinkedProvider(ref),
          onRegistered: () {
            ref.invalidate(accountMeProvider);
            ref.read(emailGateProvider.notifier).registered();
            context.go('/board');
          },
        ),
        const SizedBox(height: SkeletonSpace.lg),
        DiscardAccountButton(socialReauth: () => reauthWithLinkedProvider(ref)),
        const SizedBox(height: SkeletonSpace.sm),
        if (!gate.blocking) ...[
          OutlinedButton(
            onPressed: () {
              ref.read(emailGateProvider.notifier).later();
              context.go('/board');
            },
            child: const Text('Later'),
          ),
          const SizedBox(height: SkeletonSpace.sm),
        ],
        OutlinedButton(
          onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// A strip above a screen that leads to a write: shown only while the server
/// wants an address for changes and the account has none. The button opens
/// [EmailScreen] now, so nothing typed later is lost to a refused write.
class EmailWriteNotice extends ConsumerWidget {
  const EmailWriteNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(emailGateProvider);
    if (!gate.toWrite) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(SkeletonSpace.md),
      child: Row(
        children: [
          const Expanded(child: Text('Add your email to post or comment.')),
          const SizedBox(width: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => ref.read(emailGateProvider.notifier).require(),
            child: const Text('Add email'),
          ),
        ],
      ),
    );
  }
}
