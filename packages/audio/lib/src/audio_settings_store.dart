import 'package:shared_preferences/shared_preferences.dart';

import 'audio_settings.dart';

/// Where the sound settings are kept (on this device only).
abstract class AudioSettingsStore {
  /// The saved settings; a value never saved is the default.
  Future<AudioSettings> load();
  Future<void> save(AudioSettings settings);
}

double _unit(double v) => v.clamp(0.0, 1.0);

/// [SharedPreferences], keys under [prefix]. A storage that fails does not
/// stop the app: the settings then last until it closes.
class SharedPreferencesAudioSettingsStore implements AudioSettingsStore {
  const SharedPreferencesAudioSettingsStore({this.prefix = 'skeleton_audio.'});

  final String prefix;

  @override
  Future<AudioSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaults = AudioSettings();
      return AudioSettings(
        bgmEnabled:
            prefs.getBool('${prefix}bgm_enabled') ?? defaults.bgmEnabled,
        bgmVolume: _unit(
          prefs.getDouble('${prefix}bgm_volume') ?? defaults.bgmVolume,
        ),
        sfxEnabled:
            prefs.getBool('${prefix}sfx_enabled') ?? defaults.sfxEnabled,
        sfxVolume: _unit(
          prefs.getDouble('${prefix}sfx_volume') ?? defaults.sfxVolume,
        ),
      );
    } on Object {
      return const AudioSettings();
    }
  }

  @override
  Future<void> save(AudioSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${prefix}bgm_enabled', settings.bgmEnabled);
      await prefs.setDouble('${prefix}bgm_volume', settings.bgmVolume);
      await prefs.setBool('${prefix}sfx_enabled', settings.sfxEnabled);
      await prefs.setDouble('${prefix}sfx_volume', settings.sfxVolume);
    } on Object {
      // kept in memory by the controller
    }
  }
}

/// The saved settings, read before the first frame.
Future<AudioSettings> loadSavedAudioSettings(AudioSettingsStore store) =>
    store.load();
