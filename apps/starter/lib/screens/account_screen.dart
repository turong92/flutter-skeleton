import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'form_page.dart';

/// Account settings: deleting the account (the store rules ask for it inside
/// the app). The password is typed again; on success the device is signed out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Account settings',
      children: [
        Text('Delete account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SkeletonSpace.sm),
        DeleteAccountForm(onDeleted: (_) => context.go('/login')),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/me'),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
