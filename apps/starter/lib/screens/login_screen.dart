import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';

/// The auth package's form in a page. Pass `LoginLabels` here to translate it.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Starter',
      children: [
        LoginForm(
          labels: context.byLocale(const LoginLabels.ko(), const LoginLabels()),
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/sign-up'),
          child: Text(context.l10n.createAccount),
        ),
        const SizedBox(height: SkeletonSpace.sm),
        OutlinedButton(
          onPressed: () => context.go('/forgot-password'),
          child: Text(context.l10n.forgotPasswordLink),
        ),
      ],
    );
  }
}
