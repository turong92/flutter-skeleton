import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';

/// The page a mailed link opens: `/reset-password?token=...`. The token is
/// only handed to the form, never shown.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final token = this.token;
    if (token == null || token.isEmpty) {
      return FormPage(
        title: context.l10n.resetPasswordTitle,
        children: [
          Text(context.l10n.resetLinkIncomplete),
          const SizedBox(height: SkeletonSpace.md),
          FilledButton(
            onPressed: () => context.go('/forgot-password'),
            child: Text(context.l10n.sendNewLink),
          ),
        ],
      );
    }
    return FormPage(
      title: context.l10n.resetPasswordTitle,
      children: [
        ResetPasswordForm(
          token: token,
          labels: context.byLocale(
            const ResetPasswordLabels.ko(),
            const ResetPasswordLabels(),
          ),
          onReset: () => context.go('/login'),
        ),
      ],
    );
  }
}
