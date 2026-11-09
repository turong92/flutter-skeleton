import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_i18n/skeleton_i18n.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';

/// Who is signed in, the way to the notification settings, social sign-in
/// links, the account page (deletion) and sign-out. Sign-out is the only path
/// that runs the sign-out hooks, so this device's push registration is removed
/// first.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final fallback = session is SignedIn
        ? (session.principal.email ?? session.principal.accountId)
        : '';
    // name#tag when the server gave a tag; the address until /account/me is in.
    final who = ref.watch(accountMeProvider).value?.displayLabel ?? fallback;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
        actions: [LanguageMenu(tooltip: context.l10n.language)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SkeletonSpace.md),
        children: [
          ListTile(title: Text(who), subtitle: Text(context.l10n.signedIn)),
          const Divider(),
          OutlinedButton(
            onPressed: () => context.go('/settings/notifications'),
            child: Text(context.l10n.notificationSettingsTitle),
          ),
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => context.go('/social'),
            child: Text(context.l10n.socialSignIn),
          ),
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => context.go('/account'),
            child: Text(context.l10n.accountSettings),
          ),
          // Draws nothing where Google's consent policy asks for no entry.
          AdsPrivacyOptionsButton(
            labels: context.byLocale(const AdsLabels.ko(), const AdsLabels()),
          ),
          const SizedBox(height: SkeletonSpace.sm),
          FilledButton(
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
            child: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
  }
}
