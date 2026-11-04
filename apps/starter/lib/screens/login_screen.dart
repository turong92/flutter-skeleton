import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'form_page.dart';

/// The auth package's form in a page. Pass `LoginLabels` here to translate it.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Starter',
      children: [
        const LoginForm(),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/sign-up'),
          child: const Text('Create account'),
        ),
        const SizedBox(height: SkeletonSpace.sm),
        OutlinedButton(
          onPressed: () => context.go('/forgot-password'),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}
