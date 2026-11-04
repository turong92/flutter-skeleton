import 'package:flutter/material.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';
import 'package:skeleton_push/advertising.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

/// The inbox tab. A tapped row opens `notificationOpenProvider`'s path.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const NotificationListView(),
    );
  }
}

/// `/settings/notifications`: push of this device and per type, then consent
/// to promotional push.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        padding: const EdgeInsets.all(SkeletonSpace.md),
        children: const [
          PushSettingsView(),
          Divider(),
          AdvertisingSettingsView(),
        ],
      ),
    );
  }
}
