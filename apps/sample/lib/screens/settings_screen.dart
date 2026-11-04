import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

/// Who is signed in, the push settings of this device, social sign-in links,
/// the account page (deletion) and sign-out. Sign-out is the only path that runs the
/// sign-out hooks, so this device's push registration is removed first.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final who = session is SignedIn
        ? (session.principal.email ?? session.principal.accountId)
        : '';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(SkeletonSpace.md),
        children: [
          ListTile(title: Text(who), subtitle: const Text('Signed in')),
          const Divider(),
          const PushSettingsView(),
          const Divider(),
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => context.go('/social'),
            child: const Text('Social sign-in'),
          ),
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: () => context.go('/account'),
            child: const Text('Account settings'),
          ),
          const SizedBox(height: SkeletonSpace.sm),
          FilledButton(
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
