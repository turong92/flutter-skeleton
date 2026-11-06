import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if i18n
import 'package:skeleton_i18n/skeleton_i18n.dart';
// #endif
// #if notifications
import 'package:skeleton_notifications/skeleton_notifications.dart';
// #endif
// #if push
import 'package:skeleton_push/skeleton_push.dart';
// #endif
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';

/// `GET /auth/me`, read when the screen opens.
final _meProvider = FutureProvider.autoDispose<Principal>(
  (ref) => ref.watch(authApiProvider).me(),
);

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(_meProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myAccount),
        actions: [
          // #if i18n
          LanguageMenu(tooltip: context.l10n.language),
          // #endif
          IconButton.outlined(
            icon: const Icon(Icons.logout),
            tooltip: context.l10n.signOut,
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: me.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: context.l10n.accountLoadFailed,
          onRetry: () => ref.invalidate(_meProvider),
        ),
        data: (principal) => ListView(
          padding: const EdgeInsets.all(SkeletonSpace.md),
          children: [
            OutlinedButton(
              onPressed: () => context.go('/account'),
              child: Text(context.l10n.accountSettings),
            ),
            // #if push
            PushPrompt(
              labels: context.byLocale(
                const PushLabels.ko(),
                const PushLabels(),
              ),
            ),
            OutlinedButton(
              onPressed: () => context.push('/settings/notifications'),
              child: Text(context.l10n.notificationSettingsTitle),
            ),
            // #endif
            // #if notifications
            OutlinedButton.icon(
              onPressed: () => context.push('/notifications'),
              icon: const UnreadBadge(
                child: Icon(Icons.notifications_outlined),
              ),
              label: Text(context.l10n.notificationsTitle),
            ),
            // #endif
            // #if iap
            OutlinedButton(
              onPressed: () => context.push('/store'),
              child: Text(context.l10n.storeTitle),
            ),
            // #endif
            // #if board
            OutlinedButton(
              onPressed: () => context.push('/board'),
              child: Text(context.l10n.boardTitle),
            ),
            // #endif
            ListTile(
              title: Text(principal.email ?? principal.accountId),
              subtitle: Text(
                context.l10n.rolesLabel(principal.roles.join(', ')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
