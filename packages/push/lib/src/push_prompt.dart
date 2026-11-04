import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_controller.dart';
import 'push_labels.dart';

/// The in-app band that comes before the system dialog: it explains, and only
/// the tap on its button asks for permission. After a refusal it only points
/// to the device settings (the system will not ask again). Hidden when push
/// cannot work, is on, or is switched off. [open] lets the app choose the
/// moment (for example after the first post).
class PushPrompt extends ConsumerWidget {
  const PushPrompt({
    super.key,
    this.open = true,
    this.labels = const PushLabels(),
  });

  final bool open;
  final PushLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushControllerProvider).status;
    if (!open) return const SizedBox.shrink();
    return switch (status) {
      PushStatus.notAsked => _Band(
        icon: Icons.notifications_outlined,
        text: labels.promptTitle,
        action: FilledButton(
          onPressed: () =>
              ref.read(pushControllerProvider.notifier).requestPermission(),
          child: Text(labels.promptEnable),
        ),
      ),
      PushStatus.denied => _Band(
        icon: Icons.notifications_off_outlined,
        text: labels.deniedHelp,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
      ),
    );
  }
}
