import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';
import 'package:skeleton_storage/skeleton_storage.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
import '../config.dart';
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
    final unreachable = context.l10n.appleUnreachable;
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
      throw DeleteAccountHookFailed(unreachable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(iapStoreSubscriptionToCancelProvider);
    final account = ref.watch(sampleAccountProvider);
    final notice = store.when(
      loading: () => null,
      // Not knowing is not "none": the person is asked to check.
      error: (_, _) => context.l10n.storeCheckFailed,
      data: (provider) => switch (provider) {
        'appstore' => context.l10n.storeAppStoreBilled,
        'googleplay' => context.l10n.storeGooglePlayBilled,
        _ => null,
      },
    );
    // The contact-email section exists only when the server has the feature
    // on: `me` then carries the `contactEmail` key (null = none yet).
    final me = ref.watch(accountMeProvider).value;
    return FormPage(
      title: context.l10n.accountSettings,
      children: [
        // The picture slot exists only when the server has `storage`: `me`
        // then carries the `avatarKey` key. The upload is the app's part
        // (`ImageUploadField`, one photo); `auth` does not know `storage`.
        if (me != null && me.avatarEnabled) ...[
          ProfilePictureSection(
            labels: context.byLocale(
              const ProfilePictureLabels.ko(),
              const ProfilePictureLabels(),
            ),
            key: ValueKey(me.avatarKey),
            me: me,
            resolveUrl: (url) => resolveStoredUrl(url, AppConfig.apiBaseUrl),
            onSaved: (_) => ref.invalidate(accountMeProvider),
            picker: (context, value, onChanged, onBusy) => ImageUploadField(
              uploader: ref.watch(uploaderProvider),
              value: value == null ? const [] : [value],
              max: 1,
              // one photo: the last finished upload is the picture
              onChanged: (keys) => onChanged(keys.isEmpty ? null : keys.last),
              onBusyChanged: onBusy,
              // the picture already saved: its small copy, else an icon
              keyPreview: (context, key) {
                final thumb = me.avatar?.thumbUrl;
                return thumb == null
                    ? const Icon(Icons.image_outlined)
                    : StoredImage(
                        url: resolveStoredUrl(thumb, AppConfig.apiBaseUrl),
                      );
              },
            ),
          ),
          const SizedBox(height: SkeletonSpace.lg),
        ],
        if (me != null && me.contactEmailEnabled) ...[
          ContactEmailSection(
            labels: context.byLocale(
              const ContactEmailLabels.ko(),
              const ContactEmailLabels(),
            ),
            contactEmail: me.contactEmail,
            socialReauth: _reauth,
            onChanged: () => ref.invalidate(accountMeProvider),
          ),
          const SizedBox(height: SkeletonSpace.lg),
        ],
        Text(
          context.l10n.deleteAccount,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
            message: context.l10n.accountLoadFailed,
            onRetry: () => ref.invalidate(sampleAccountProvider),
          ),
          data: (_) => DeleteAccountForm(
            labels: context.byLocale(
              const DeleteAccountLabels.ko(),
              const DeleteAccountLabels(),
            ),
            onDeleted: (_) => context.go('/login'),
            socialReauth: _reauth,
            beforeDelete: _revokeApple,
          ),
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/settings'),
          child: Text(context.l10n.back),
        ),
      ],
    );
  }
}
