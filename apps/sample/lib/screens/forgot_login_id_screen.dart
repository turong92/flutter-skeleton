import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';

/// "Mail me my ID": reached from the sign-in screen on a server with login
/// IDs on. The answer is the same whether or not the address has an account.
class ForgotLoginIdScreen extends StatelessWidget {
  const ForgotLoginIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: context.l10n.forgotIdTitle,
      children: [
        ForgotLoginIdForm(
          labels: context.byLocale(
            const ForgotLoginIdLabels.ko(),
            const ForgotLoginIdLabels(),
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
