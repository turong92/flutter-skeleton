import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import 'form_page.dart';
import 'social_buttons.dart';

/// The auth package's form in a page. Pass `LoginLabels` here to translate it.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The ID link shows only on a server with login IDs on; an unread or
    // failed `/auth/methods` reads as off, like in the forms.
    final hasLoginId = ref.watch(authMethodsProvider).value?.loginId != null;
    return FormPage(
      title: context.l10n.appName,
      children: [
        LoginForm(
          labels: context.byLocale(const LoginLabels.ko(), const LoginLabels()),
        ),
        const SocialButtons(),
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
        if (hasLoginId) ...[
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => context.go('/forgot-login-id'),
            child: Text(context.l10n.forgotIdLink),
          ),
        ],
      ],
    );
  }
}
