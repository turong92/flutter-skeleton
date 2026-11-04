import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
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
