import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../social_support.dart';
import 'form_page.dart';

/// Account settings: deleting the account (the store rules ask for it inside
/// the app). The proof is the password, a mailed code or, for an account with
/// no address, a fresh sign-in with a linked provider; on success the device is
/// signed out. A store subscription outlives the account (the server cannot end
/// it), so the person is told to cancel it in the store first. An account with
/// Sign in with Apple first has Apple told to drop its access (App Review).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  var _revoked = false;
  var _revoking = false;
  String? _revokeError;

  Future<void> _revokeApple() async {
    final apple = ref.read(sampleAccountProvider).value?.appleToRevoke;
    if (apple == null) return;
    final client = ref.read(apiClientProvider);
    setState(() {
      _revoking = true;
      _revokeError = null;
    });
    try {
      await apple.revokeBeforeDelete(client);
      if (mounted) setState(() => _revoked = true);
    } on SocialCancelled {
      // Backed out: nothing is deleted and nothing is shown.
    } catch (_) {
      if (mounted) {
        setState(() => _revokeError = 'Apple could not be reached. Try again.');
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(iapStoreSubscriptionToCancelProvider);
    final needsAppleStep =
        !_revoked &&
        ref.watch(sampleAccountProvider).value?.appleToRevoke != null;
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
        if (needsAppleStep) ...[
          const Text(
            'This account signs in with Apple. Apple has to drop its access '
            'before the account can be deleted.',
          ),
          const SizedBox(height: SkeletonSpace.sm),
          FilledButton(
            key: const ValueKey('account.revokeApple'),
            onPressed: _revoking ? null : _revokeApple,
            child: const Text('Remove Apple access'),
          ),
          if (_revokeError != null) ...[
            const SizedBox(height: SkeletonSpace.sm),
            Text(
              _revokeError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ] else
          DeleteAccountForm(
            onDeleted: (_) => context.go('/login'),
            socialReauth: () => reauthWithLinkedProvider(ref),
          ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/settings'),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
