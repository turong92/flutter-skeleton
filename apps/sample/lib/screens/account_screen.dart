import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
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
/// Sign in with Apple has Apple told to drop its access (App Review) right
/// before the delete call, after the proof (a revoke earlier would let the
/// proof's own Apple sheet link the app again).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  /// The revoke code the proof's own Apple sheet gave (Apple-only accounts),
  /// so the revoke needs no second sheet.
  String? _appleCode;

  Future<Map<String, Object?>?> _reauth() {
    _appleCode = null;
    return reauthWithLinkedProvider(
      ref,
      onAppleRevokeCode: (code) => _appleCode = code,
    );
  }

  /// Right before `POST /account/delete`: Apple drops its access (App Review).
  /// Cancel = false (nothing is deleted); Apple off for the project = nothing
  /// to revoke; any other failure stops the delete and the form stays.
  Future<bool> _revokeApple() async {
    final account = await ref.read(sampleAccountProvider.future);
    final apple = account.appleToRevoke;
    if (apple == null) return true;
    final client = ref.read(apiClientProvider);
    final code = _appleCode;
    _appleCode = null;
    try {
      if (code != null) {
        await apple.revokeWithCode(client, code);
      } else {
        await apple.revokeBeforeDelete(client);
      }
      return true;
    } on SocialCancelled {
      return false;
    } catch (e) {
      if (e is ApiRequestError && e.code == 'AUTH_SOCIAL.PROVIDER_NOT_FOUND') {
        return true;
      }
      throw const DeleteAccountHookFailed(
        'Apple could not be reached. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(iapStoreSubscriptionToCancelProvider);
    final account = ref.watch(sampleAccountProvider);
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
        // The form waits for /account/me: not knowing whether Apple is linked
        // must not open a way to delete without the revoke.
        account.when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            message: 'Could not load your account.',
            onRetry: () => ref.invalidate(sampleAccountProvider),
          ),
          data: (_) => DeleteAccountForm(
            onDeleted: (_) => context.go('/login'),
            socialReauth: _reauth,
            beforeDelete: _revokeApple,
          ),
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
