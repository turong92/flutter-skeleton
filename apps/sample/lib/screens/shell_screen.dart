import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

import '../config.dart';
import '../l10n/l10n.dart';

/// The four tabs. Each keeps its own place when another tab is open.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Empty until the ads are ready (consent, then the SDK).
          AdBanner(
            unitId: AdUnitIds.banner(
              android: AppConfig.adsBannerAndroid,
              ios: AppConfig.adsBannerIos,
            ),
          ),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            // Tapping the open tab goes back to its first screen.
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              // The labels come from the chosen language.
              NavigationDestination(
                icon: const Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: context.l10n.tabBoard,
              ),
              NavigationDestination(
                icon: UnreadBadge(child: Icon(Icons.notifications_outlined)),
                selectedIcon: UnreadBadge(child: Icon(Icons.notifications)),
                label: context.l10n.tabNotifications,
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: context.l10n.tabStore,
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: context.l10n.tabSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
