// #file notifications
import 'package:flutter/material.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

/// The inbox. A tapped row opens the path `notificationOpenProvider` gives
/// (see `wiring.dart`).
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
