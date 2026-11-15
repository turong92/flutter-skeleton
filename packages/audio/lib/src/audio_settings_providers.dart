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

  Future<void> setBgmVolume(double value) =>
      _set(state.copyWith(bgmVolume: value.clamp(0.0, 1.0)));

  Future<void> setSfxEnabled(bool value) =>
      _set(state.copyWith(sfxEnabled: value));

  Future<void> setSfxVolume(double value) =>
      _set(state.copyWith(sfxVolume: value.clamp(0.0, 1.0)));

  Future<void> _set(AudioSettings next) async {
    state = next;
    await ref.read(audioSettingsStoreProvider).save(next);
  }
}
