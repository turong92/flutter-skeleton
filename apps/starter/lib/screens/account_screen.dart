import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if iap
import 'package:skeleton_iap/skeleton_iap.dart';
// #endif
// #if storage
import 'package:skeleton_storage/skeleton_storage.dart';
// #endif
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';
// #if storage
import '../config.dart';
// #endif
import 'form_page.dart';

/// Account settings: deleting the account (the store rules ask for it inside
/// the app). The password is typed again; on success the device is signed out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #if iap
    // A store subscription outlives the account (the server cannot end it),
    // so the person is told to cancel it in the store first.
    final notice = ref
        .watch(iapStoreSubscriptionToCancelProvider)
        .when(
          loading: () => null,
          // Not knowing is not "none": the person is asked to check.
          error: (_, _) => context.l10n.storeCheckFailed,
          data: (provider) => switch (provider) {
            'appstore' => context.l10n.storeAppStoreBilled,
            'googleplay' => context.l10n.storeGooglePlayBilled,
            _ => null,
          },
        );
    // #endif
    // #if storage
    // The picture slot exists only when the server has `storage` (`me` then
    // carries the `avatarKey` key). The upload is the app's part; `auth` does
    // not know `storage`.
    final me = ref.watch(accountMeProvider).value;
    // #endif
    return FormPage(
      title: context.l10n.accountSettings,
      children: [
        // #if storage
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
        // #endif
        Text(
          context.l10n.deleteAccount,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SkeletonSpace.sm),
        // #if iap
        if (notice != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SkeletonSpace.md),
              child: Text(notice),
            ),
          ),
          const SizedBox(height: SkeletonSpace.sm),
        ],
        // #endif
        DeleteAccountForm(
          labels: context.byLocale(
            const DeleteAccountLabels.ko(),
            const DeleteAccountLabels(),
          ),
          onDeleted: (_) => context.go('/login'),
        ),
        const SizedBox(height: SkeletonSpace.md),
        OutlinedButton(
          onPressed: () => context.go('/me'),
          child: Text(context.l10n.back),
        ),
      ],
    );
  }
}
