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
    // #endif
    // #if storage
    // The picture slot exists only when the server has `storage` (`me` then
    // carries the `avatarKey` key). The upload is the app's part; `auth` does
    // not know `storage`.
    final me = ref.watch(accountMeProvider).value;
    // #endif
    return FormPage(
      title: 'Account settings',
      children: [
        // #if storage
        if (me != null && me.avatarEnabled) ...[
          ProfilePictureSection(
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
        Text('Delete account', style: Theme.of(context).textTheme.titleMedium),
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
