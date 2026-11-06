// #file notifications
import 'package:flutter/material.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

import '../l10n/l10n.dart';

/// The inbox. A tapped row opens the path `notificationOpenProvider` gives
/// (see `wiring.dart`).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notificationsTitle)),
      body: NotificationListView(
        labels: context.byLocale(
          const NotificationsLabels.ko(),
          const NotificationsLabels(),
        ),
      ),
    );
  }
}
