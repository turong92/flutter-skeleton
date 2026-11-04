import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

/// The four tabs. Each keeps its own place when another tab is open.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the open tab goes back to its first screen.
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Board',
          ),
          NavigationDestination(
            icon: UnreadBadge(child: Icon(Icons.notifications_outlined)),
            selectedIcon: UnreadBadge(child: Icon(Icons.notifications)),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
