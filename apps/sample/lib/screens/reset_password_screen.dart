import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

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
        title: 'Reset password',
        children: [
          const Text('This link is incomplete. Ask for a new one.'),
          const SizedBox(height: SkeletonSpace.md),
          FilledButton(
            onPressed: () => context.go('/forgot-password'),
            child: const Text('Send a new link'),
          ),
        ],
      );
    }
    return FormPage(
      title: 'Reset password',
      children: [
        ResetPasswordForm(token: token, onReset: () => context.go('/login')),
      ],
    );
  }
}
