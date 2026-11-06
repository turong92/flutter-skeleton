import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import '../nickname_gate.dart';
import 'form_page.dart';

/// Where an account without a nickname lands after sign-in (see
/// `nickname_gate.dart`). Saving lets the person on to the board.
class NicknameScreen extends ConsumerWidget {
  const NicknameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormPage(
      title: context.l10n.chooseNickname,
      children: [
        DisplayNameForm(
          labels: context.byLocale(
            const DisplayNameLabels.ko(),
            const DisplayNameLabels(),
          ),
          onSaved: (_) {
            ref.invalidate(accountMeProvider);
            ref.read(needsNicknameProvider.notifier).done();
            context.go('/board');
          },
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          child: Text(context.l10n.signOut),
        ),
      ],
    );
  }
}
