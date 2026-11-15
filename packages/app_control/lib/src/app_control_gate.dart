import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_control_labels.dart';
import 'app_control_providers.dart';
import 'app_state.dart';

/// Put it above the app (`MaterialApp.builder: (context, child) =>
/// AppControlGate(child: child!)`). Maintenance shows a screen; a version below
/// the minimum shows a screen that cannot be closed with a button to the store;
/// one below the recommended version shows a notice above the app that can be
/// closed. The config is read at start and every time the app comes back to the
/// front; if it cannot be read the app is not held back.
class AppControlGate extends ConsumerStatefulWidget {
  const AppControlGate({
    required this.child,
    this.labels = const AppControlLabels(),
    super.key,
  });

  final Widget child;
  final AppControlLabels labels;

  @override
  ConsumerState<AppControlGate> createState() => _AppControlGateState();
}

class _AppControlGateState extends ConsumerState<AppControlGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appConfigProvider.notifier).refresh();
    }
  }

  Future<void> _openStore(String? storeUrl) async {
    if (storeUrl == null) return;
    await ref.read(storeLauncherProvider)(Uri.parse(storeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final state = ref.watch(appControlStateProvider);
    switch (state) {
      case AppMaintenance():
        final endsAt = state.endsAt;
        return _StatusScreen(
          icon: Icons.build_circle_outlined,
          title: labels.maintenanceTitle,
          body: state.message ?? labels.maintenanceBody,
          note: endsAt == null
              ? null
              : labels.maintenanceEnds.replaceFirst(
                  '{time}',
                  _timeText(context, endsAt),
                ),
        );
      case AppUpdateRequired():
        return _StatusScreen(
          icon: Icons.system_update,
          title: labels.updateRequiredTitle,
          body: labels.updateRequiredBody,
          action: state.storeUrl == null
              ? null
              : FilledButton(
                  onPressed: () => _openStore(state.storeUrl),
                  child: Text(labels.update),
                ),
        );
      case AppUpdateRecommended():
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels.updateRecommendedTitle,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(labels.updateRecommendedBody),
                          ],
                        ),
                      ),
                      if (state.storeUrl != null)
                        TextButton(
                          onPressed: () => _openStore(state.storeUrl),
                          child: Text(labels.update),
                        ),
                      TextButton(
                        onPressed: () => ref
                            .read(dismissedUpdateProvider.notifier)
                            .dismiss(state.recommendedVersion),
                        child: Text(labels.later),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The notice already took the top inset.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.child,
              ),
            ),
          ],
        );
      case AppOk():
        return widget.child;
    }
  }

  static String _timeText(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final l10n = MaterialLocalizations.of(context);
    return '${l10n.formatShortDate(local)} '
        '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    required this.icon,
    required this.title,
    required this.body,
    this.note,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    note!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 24), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
