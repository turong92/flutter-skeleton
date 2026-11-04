import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'form_page.dart';

/// Account settings: deleting the account (the store rules ask for it inside
/// the app). The password is typed again; on success the device is signed out.
/// A store subscription outlives the account (the server cannot end it), so
/// the person is told to cancel it in the store first.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(iapStoreSubscriptionToCancelProvider);
    final notice = store.when(
      loading: () => null,
      // Not knowing is not "none": the person is asked to check.
      error: (_, _) =>
          'We could not check your store subscription. If you have one, '
          'cancel it in the App Store or Google Play before deleting.',
      data: (provider) => switch (provider) {
        'appstore' =>
          'Your subscription is billed by the App Store and keeps running '
              'after the account is deleted. Cancel it in the App Store first.',
        'googleplay' =>
          'Your subscription is billed by Google Play and keeps running '
              'after the account is deleted. Cancel it in Google Play first.',
        _ => null,
      },
    );
    return FormPage(
      title: 'Account settings',
      children: [
        Text('Delete account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SkeletonSpace.sm),
        if (notice != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SkeletonSpace.md),
              child: Text(notice),
            ),
          ),
          const SizedBox(height: SkeletonSpace.sm),
        ],
        DeleteAccountForm(onDeleted: (_) => context.go('/login')),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/settings'),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
