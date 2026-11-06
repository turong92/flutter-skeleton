import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import '../email_gate.dart';
import '../login_id_gate.dart';
import '../social_support.dart';
import 'form_page.dart';

/// Where an account without a login ID lands (see `login_id_gate.dart`). The
/// ID is chosen once; saving lets the person on (the next gate, if any, takes
/// over). Sign out is the way out: the server answers nothing else until an ID
/// is chosen.
class LoginIdScreen extends ConsumerWidget {
  const LoginIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void done() {
      ref.invalidate(accountMeProvider);
      ref.read(needsLoginIdProvider.notifier).done();
      context.go('/board');
    }

    return FormPage(
      title: context.l10n.chooseId,
      children: [
        LoginIdForm(
          labels: context.byLocale(
            const LoginIdLabels.ko(),
            const LoginIdLabels(),
          ),
          onSaved: (_) => done(),
          onAlreadySet: done,
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          child: Text(context.l10n.signOut),
        ),
        // Under the address rule the ID gate also has the way out (accounts.md).
        if (ref.watch(emailGateProvider.select((g) => g.blocking || g.toWrite)))
          DiscardAccountButton(
            socialReauth: () => reauthWithLinkedProvider(ref),
          ),
      ],
    );
  }
}
