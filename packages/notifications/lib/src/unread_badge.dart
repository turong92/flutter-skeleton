import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_providers.dart';

/// [child] (a tab or app bar icon) with the unread count on it: nothing at 0,
/// `99+` above 99. The count is the server's (`unreadCountProvider`); while it
/// loads or failed, no badge.
class UnreadBadge extends ConsumerWidget {
  const UnreadBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}
