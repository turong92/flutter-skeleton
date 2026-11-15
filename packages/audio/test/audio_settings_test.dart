import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_audio/skeleton_audio.dart';
import 'package:skeleton_audio/testing.dart';

void main() {
  group('the saved settings', () {
    test('nothing saved gives the defaults: both on, full volume', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await loadSavedAudioSettings(
          const SharedPreferencesAudioSettingsStore(),
        ),
        const AudioSettings(),
      );
      expect(const AudioSettings().bgmEnabled, isTrue);
      expect(const AudioSettings().sfxVolume, 1.0);
    });

    test('SharedPreferences keeps all four values across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      const saved = AudioSettings(
        bgmEnabled: false,
        bgmVolume: 0.3,
        sfxEnabled: true,
        sfxVolume: 0.6,
      );
      await const SharedPreferencesAudioSettingsStore().save(saved);

      // a new store object = a new start of the app
      expect(
        await loadSavedAudioSettings(
          const SharedPreferencesAudioSettingsStore(),
        ),
        saved,
      );
    });

    test('a stored volume outside 0..1 is clamped', () async {
      SharedPreferences.setMockInitialValues({
        'skeleton_audio.bgm_volume': 7.0,
        'skeleton_audio.sfx_volume': -1.0,
      });
      final loaded = await loadSavedAudioSettings(
        const SharedPreferencesAudioSettingsStore(),
      );
      expect(loaded.bgmVolume, 1.0);
      expect(loaded.sfxVolume, 0.0);
    });
  });

  group('AudioSettingsController', () {
    test('starts from the saved settings', () {
      final container = ProviderContainer(
        overrides: [
          savedAudioSettingsProvider.overrideWithValue(
            const AudioSettings(sfxEnabled: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(audioSettingsProvider).sfxEnabled, isFalse);
    });

    test('each change is shown at once and written to the store', () async {
      final store = MemoryAudioSettingsStore();
      final container = ProviderContainer(
        overrides: [audioSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(audioSettingsProvider.notifier);

      await controller.setBgmEnabled(false);
      await controller.setBgmVolume(0.4);
      await controller.setSfxEnabled(false);
      await controller.setSfxVolume(0.2);

      const expected = AudioSettings(
        bgmEnabled: false,
        bgmVolume: 0.4,
        sfxEnabled: false,
        sfxVolume: 0.2,
      );
      expect(container.read(audioSettingsProvider), expected);
      expect(store.saved, expected);
    });

    test('a volume outside 0..1 is clamped', () async {
      final container = ProviderContainer(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(
            MemoryAudioSettingsStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(audioSettingsProvider.notifier);

      await controller.setBgmVolume(2);
      await controller.setSfxVolume(-0.5);

      expect(container.read(audioSettingsProvider).bgmVolume, 1.0);
      expect(container.read(audioSettingsProvider).sfxVolume, 0.0);
    });
  });
}
