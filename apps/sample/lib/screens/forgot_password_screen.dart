import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'form_page.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Forgot password',
      children: [
        const ForgotPasswordForm(),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
