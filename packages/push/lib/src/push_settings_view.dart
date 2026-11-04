import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';
import 'push_api.dart';
import 'push_controller.dart';
import 'push_labels.dart';

final _preferencesProvider = FutureProvider.autoDispose<List<PushPreference>>(
  (ref) => ref.watch(pushApiProvider).preferences(),
  retry: (_, _) => null,
);

/// Settings for push: this device's switch, one switch per notification kind
/// and a test notification. Place it in the app's settings screen.
class PushSettingsView extends ConsumerStatefulWidget {
  const PushSettingsView({super.key, this.labels = const PushLabels()});

  final PushLabels labels;

  @override
  ConsumerState<PushSettingsView> createState() => _PushSettingsViewState();
}

class _PushSettingsViewState extends ConsumerState<PushSettingsView> {
  String? _testResult;
  bool _testing = false;

  PushLabels get labels => widget.labels;

  Future<void> _sendTest() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String result;
    try {
      await ref.read(pushControllerProvider.notifier).sendTest();
      result = labels.testSent;
    } on ApiRequestError catch (e) {
      result = e.code == PushErrorCodes.testTooSoon
          ? labels.testTooSoon
          : labels.testFailed;
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result;
    });
  }

  Future<void> _setKind(PushPreference pref, bool enabled) async {
    try {
      await ref.read(pushApiProvider).setPreference(pref.type, enabled: enabled);
    } on ApiRequestError {
      // the list is read again below and shows what the server still has
    }
    ref.invalidate(_preferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pushControllerProvider).status;
    if (status == PushStatus.unavailable) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(labels.unavailable),
      );
    }
    final denied = status == PushStatus.denied;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(labels.deviceSwitch),
          subtitle: denied ? Text(labels.deniedHelp) : null,
          value: status == PushStatus.enabled,
          onChanged: denied
              ? null
              : (on) => ref
                    .read(pushControllerProvider.notifier)
                    .setDeviceEnabled(on),
        ),
        ..._kinds(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: status == PushStatus.enabled && !_testing
                    ? _sendTest
                    : null,
                child: Text(labels.testSend),
              ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_testResult!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _kinds() {
    final prefs = ref.watch(_preferencesProvider);
    return prefs.when(
      loading: () => const [],
      error: (_, _) => [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(labels.loadFailed),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(_preferencesProvider),
                child: Text(labels.retry),
              ),
            ],
          ),
        ),
      ],
      data: (items) => [
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              labels.kindsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        for (final pref in items)
          SwitchListTile(
            title: Text(labels.typeName(pref.type)),
            subtitle: pref.allChannelsMuted ? Text(labels.allChannelsMuted) : null,
            value: pref.push && !pref.allChannelsMuted,
            onChanged: pref.allChannelsMuted
                ? null
                : (on) => _setKind(pref, on),
          ),
      ],
    );
  }
}
