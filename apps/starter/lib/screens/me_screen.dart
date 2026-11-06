import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if notifications
import 'package:skeleton_notifications/skeleton_notifications.dart';
// #endif
// #if push
import 'package:skeleton_push/skeleton_push.dart';
// #endif
import 'package:skeleton_ui/skeleton_ui.dart';

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
        title: const Text('My account'),
        actions: [
          IconButton.outlined(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: me.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load your account.',
          onRetry: () => ref.invalidate(_meProvider),
        ),
        data: (principal) => ListView(
          padding: const EdgeInsets.all(SkeletonSpace.md),
          children: [
            OutlinedButton(
              onPressed: () => context.go('/account'),
              child: const Text('Account settings'),
            ),
            // #if push
            const PushPrompt(),
            OutlinedButton(
              onPressed: () => context.push('/settings/notifications'),
              child: const Text('Notification settings'),
            ),
            // #endif
            // #if notifications
            OutlinedButton.icon(
              onPressed: () => context.push('/notifications'),
              icon: const UnreadBadge(
                child: Icon(Icons.notifications_outlined),
              ),
              label: const Text('Notifications'),
            ),
            // #endif
            // #if iap
            OutlinedButton(
              onPressed: () => context.push('/store'),
              child: const Text('Store'),
            ),
            // #endif
            // #if board
            OutlinedButton(
              onPressed: () => context.push('/board'),
              child: const Text('Board'),
            ),
            // #endif
            ListTile(
              title: Text(principal.email ?? principal.accountId),
              subtitle: Text('Roles: ${principal.roles.join(', ')}'),
            ),
          ],
        ),
      ),
    );
  }
}
