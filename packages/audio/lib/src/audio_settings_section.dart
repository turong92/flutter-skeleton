import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'audio_labels.dart';
import 'audio_settings_providers.dart';

/// A switch and a volume slider for the background music and for the sound
/// effects, to put in a settings screen. The slider of a sound that is switched
/// off is disabled.
class AudioSettingsSection extends ConsumerWidget {
  const AudioSettingsSection({super.key, this.labels = const AudioLabels()});

  final AudioLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(audioSettingsProvider);
    final controller = ref.read(audioSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          label: labels.bgm,
          enabled: settings.bgmEnabled,
          volume: settings.bgmVolume,
          onEnabled: controller.setBgmEnabled,
          onVolume: controller.setBgmVolume,
        ),
        const SizedBox(height: SkeletonSpace.sm),
        _Row(
          label: labels.sfx,
          enabled: settings.sfxEnabled,
          volume: settings.sfxVolume,
          onEnabled: controller.setSfxEnabled,
          onVolume: controller.setSfxVolume,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.enabled,
    required this.volume,
    required this.onEnabled,
    required this.onVolume,
  });

  final String label;
  final bool enabled;
  final double volume;
  final ValueChanged<bool> onEnabled;
  final Future<void> Function(double value, {bool save}) onVolume;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: enabled,
          onChanged: onEnabled,
        ),
        Semantics(
          label: label,
          child: Slider(
            value: volume,
            semanticFormatterCallback: (v) => '${(v * 100).round()}%',
            onChanged: enabled ? (v) => onVolume(v, save: false) : null,
            onChangeEnd: enabled ? (v) => onVolume(v) : null,
          ),
        ),
      ],
    );
  }
}
