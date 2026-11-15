import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_settings.dart';
import 'audio_settings_store.dart';

final audioSettingsStoreProvider = Provider<AudioSettingsStore>(
  (ref) => const SharedPreferencesAudioSettingsStore(),
);

/// The settings read from the store before the first frame:
/// `ProviderScope(overrides: [savedAudioSettingsProvider.overrideWithValue(await loadSavedAudioSettings(store))])`.
final savedAudioSettingsProvider = Provider<AudioSettings>(
  (ref) => const AudioSettings(),
);

/// The settings now. A change is shown at once and written to the store.
final audioSettingsProvider =
    NotifierProvider<AudioSettingsController, AudioSettings>(
      AudioSettingsController.new,
    );

class AudioSettingsController extends Notifier<AudioSettings> {
  @override
  AudioSettings build() => ref.read(savedAudioSettingsProvider);

  Future<void> setBgmEnabled(bool value) =>
      _set(state.copyWith(bgmEnabled: value));

  /// [save] false while a slider is dragged: the volume is heard at once and
  /// written once, when the finger leaves (call again with the default).
  Future<void> setBgmVolume(double value, {bool save = true}) =>
      _set(state.copyWith(bgmVolume: value.clamp(0.0, 1.0)), save: save);

  Future<void> setSfxEnabled(bool value) =>
      _set(state.copyWith(sfxEnabled: value));

  Future<void> setSfxVolume(double value, {bool save = true}) =>
      _set(state.copyWith(sfxVolume: value.clamp(0.0, 1.0)), save: save);

  Future<void> _set(AudioSettings next, {bool save = true}) async {
    state = next;
    if (save) await ref.read(audioSettingsStoreProvider).save(next);
  }
}
