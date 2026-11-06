import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import '../email_gate.dart';
import '../social_support.dart';
import 'form_page.dart';

/// Where an account without an address lands (see `email_gate.dart`). When the
/// server asks for the address right after sign-in the only ways out are
/// registering, discarding the account (for someone who already has another)
/// and signing out; when it asks only for changes the screen can be closed.
class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  late final EmailGateNotifier _gate;

  @override
  void initState() {
    super.initState();
    _gate = ref.read(emailGateProvider.notifier);
  }

  @override
  void dispose() {
    // Opened for a write, the screen lies over the one the person was on, and
    // it can go away by a pop (button, swipe) or by a `go()` / redirect that
    // replaces the stack (a push tap, a link): either way it is "later" unless
    // the address was registered. Not inside dispose itself: providers cannot
    // change while the tree is being torn down.
    final gate = _gate;
    scheduleMicrotask(gate.screenGone);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(emailGateProvider);
    return FormPage(
      title: context.l10n.addYourEmail,
      children: [
        Text(
          gate.blocking
              ? context.l10n.emailNeededToGoOn
              : context.l10n.emailNeededForChanges,
        ),
        const SizedBox(height: SkeletonSpace.md),
        EmailRegisterForm(
          labels: context.byLocale(
            const EmailRegisterLabels.ko(),
            const EmailRegisterLabels(),
          ),
          socialReauth: () => reauthWithLinkedProvider(ref),
          onRegistered: () {
            ref.invalidate(accountMeProvider);
            ref.read(emailGateProvider.notifier).registered();
            _leave(context);
          },
        ),
        const SizedBox(height: SkeletonSpace.lg),
        DiscardAccountButton(
          labels: context.byLocale(
            const EmailRegisterLabels.ko(),
            const EmailRegisterLabels(),
          ),
          socialReauth: () => reauthWithLinkedProvider(ref),
        ),
        const SizedBox(height: SkeletonSpace.sm),
        if (!gate.blocking) ...[
          OutlinedButton(
            onPressed: () {
              ref.read(emailGateProvider.notifier).later();
              _leave(context);
            },
            child: Text(context.l10n.later),
          ),
          const SizedBox(height: SkeletonSpace.sm),
        ],
        OutlinedButton(
          onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          child: Text(context.l10n.signOut),
        ),
      ],
    );
  }

  /// Back to the screen under this one, or the board when there is none.
  void _leave(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/board');
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
          Expanded(child: Text(context.l10n.addEmailToPost)),
          const SizedBox(width: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => ref.read(emailGateProvider.notifier).require(),
            child: Text(context.l10n.addEmail),
          ),
        ],
      ),
    );
  }
}
