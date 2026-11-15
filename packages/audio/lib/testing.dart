/// Test doubles for apps that test against `audio`: import from tests only
/// (`package:skeleton_audio/testing.dart`).
library;

import 'src/audio_engine.dart';
import 'src/audio_settings.dart';
import 'src/audio_settings_store.dart';

/// A store that keeps the settings in memory; [saved] is the last one written.
class MemoryAudioSettingsStore implements AudioSettingsStore {
  MemoryAudioSettingsStore([this.saved]);

  AudioSettings? saved;

  @override
  Future<AudioSettings> load() async => saved ?? const AudioSettings();

  @override
  Future<void> save(AudioSettings settings) async => saved = settings;
}

/// An engine that plays nothing and writes down what it was asked, one line
/// each: `startBgm <asset> <volume>`, `setBgmVolume <v>`, `pauseBgm`,
/// `resumeBgm`, `stopBgm`, `sfx <asset> <volume>`.
class FakeAudioEngine implements AudioEngine {
  final calls = <String>[];

  @override
  Future<void> startBgm(String asset, double volume) async =>
      calls.add('startBgm $asset $volume');

  @override
  Future<void> setBgmVolume(double volume) async =>
      calls.add('setBgmVolume $volume');

  @override
  Future<void> pauseBgm() async => calls.add('pauseBgm');

  @override
  Future<void> resumeBgm() async => calls.add('resumeBgm');

  @override
  Future<void> stopBgm() async => calls.add('stopBgm');

  @override
  Future<void> playSfx(String asset, double volume) async =>
      calls.add('sfx $asset $volume');

  @override
  Future<void> dispose() async {}
}
