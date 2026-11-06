// #file push
import 'package:flutter/material.dart';
import 'package:skeleton_push/advertising.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';

/// `/settings/notifications`: push of this device and per type, then consent
/// to promotional push.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notificationSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SkeletonSpace.md),
        children: [
          PushSettingsView(
            labels: context.byLocale(const PushLabels.ko(), const PushLabels()),
          ),
          const Divider(),
          const AdvertisingSettingsView(),
        ],
      ),
    );
  }
}
