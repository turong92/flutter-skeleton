import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: context.l10n.forgotPasswordTitle,
      children: [
        ForgotPasswordForm(
          labels: context.byLocale(
            const ForgotPasswordLabels.ko(),
            const ForgotPasswordLabels(),
          ),
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: Text(context.l10n.backToSignIn),
        ),
      ],
    );
  }
}
