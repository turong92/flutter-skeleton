import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_audio/skeleton_audio.dart';
import 'package:skeleton_audio/testing.dart';

class _Rig {
  _Rig({
    AudioSettings settings = const AudioSettings(),
    Duration fade = Duration.zero,
  }) : engine = FakeAudioEngine() {
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        audioSettingsStoreProvider.overrideWithValue(
          MemoryAudioSettingsStore(),
        ),
        savedAudioSettingsProvider.overrideWithValue(settings),
        audioFadeProvider.overrideWithValue(fade),
      ],
    );
    addTearDown(container.dispose);
    audio = container.read(audioProvider);
  }

  final FakeAudioEngine engine;
  late final ProviderContainer container;
  late final Audio audio;

  AudioSettingsController get settings =>
      container.read(audioSettingsProvider.notifier);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> state(AppLifecycleState s) async {
    binding.handleAppLifecycleStateChanged(s);
    await pumpEventQueue();
  }

  group('background music', () {
    test('plays the file on a loop at the saved volume', () async {
      final rig = _Rig(settings: const AudioSettings(bgmVolume: 0.5));

      await rig.audio.playBgm('audio/a.mp3');

      expect(rig.engine.calls, ['startBgm audio/a.mp3 0.5']);
    });

    test('asking for the track that is playing does not restart it', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');
      await rig.audio.playBgm('audio/a.mp3');

      expect(rig.engine.calls, ['startBgm audio/a.mp3 1.0']);
    });

    test('switched off: nothing reaches the player, and it starts when switched on', () async {
      final rig = _Rig(settings: const AudioSettings(bgmEnabled: false));

      await rig.audio.playBgm('audio/a.mp3');
      expect(rig.engine.calls, isEmpty);

      await rig.settings.setBgmEnabled(true);
      await pumpEventQueue();
      expect(rig.engine.calls, ['startBgm audio/a.mp3 1.0']);
    });

    test('volume 0: nothing reaches the player', () async {
      final rig = _Rig(settings: const AudioSettings(bgmVolume: 0));

      await rig.audio.playBgm('audio/a.mp3');

      expect(rig.engine.calls, isEmpty);
    });

    test('switching it off while it plays stops it', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');

      await rig.settings.setBgmEnabled(false);
      await pumpEventQueue();

      expect(rig.engine.calls.last, 'stopBgm');
    });

    test('a volume change reaches the track that plays', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');

      await rig.settings.setBgmVolume(0.25);
      await pumpEventQueue();

      expect(rig.engine.calls.last, 'setBgmVolume 0.25');
    });

    test('another track replaces it; stopBgm ends it and a later enable stays silent', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');
      await rig.audio.playBgm('audio/b.mp3');
      expect(rig.engine.calls.last, 'startBgm audio/b.mp3 1.0');

      await rig.audio.stopBgm();
      expect(rig.engine.calls.last, 'stopBgm');

      final before = rig.engine.calls.length;
      await rig.settings.setBgmEnabled(false);
      await rig.settings.setBgmEnabled(true);
      await pumpEventQueue();
      expect(rig.engine.calls.length, before);
    });

    test(
      'the switch fades out, then in, and ends at the saved volume',
      () async {
        final rig = _Rig(
          settings: const AudioSettings(bgmVolume: 0.8),
          fade: const Duration(milliseconds: 40),
        );
        await rig.audio.playBgm('audio/a.mp3');
        rig.engine.calls.clear();

        await rig.audio.playBgm('audio/b.mp3');

        final calls = rig.engine.calls;
        final start = calls.indexOf('startBgm audio/b.mp3 0.0');
        expect(start, greaterThan(0), reason: '$calls');
        expect(calls.sublist(0, start).last, 'setBgmVolume 0.0');
        expect(calls.last, 'setBgmVolume 0.8');
      },
    );
  });

  group('the app in the background', () {
    test('pauses the music and resumes it when the app comes back', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');
      rig.engine.calls.clear();

      await state(AppLifecycleState.paused);
      expect(rig.engine.calls, ['pauseBgm']);

      await state(AppLifecycleState.resumed);
      expect(rig.engine.calls, ['pauseBgm', 'resumeBgm']);
    });

    test('a short interruption (inactive) does not stop it', () async {
      final rig = _Rig();
      await rig.audio.playBgm('audio/a.mp3');
      rig.engine.calls.clear();

      await state(AppLifecycleState.inactive);
      await state(AppLifecycleState.resumed);

      expect(rig.engine.calls, isEmpty);
    });

    test(
      'music asked for in the background starts when the app returns',
      () async {
        final rig = _Rig();
        await state(AppLifecycleState.paused);

        await rig.audio.playBgm('audio/a.mp3');
        expect(rig.engine.calls, isEmpty);

        await state(AppLifecycleState.resumed);
        expect(rig.engine.calls, ['startBgm audio/a.mp3 1.0']);
      },
    );
  });

  group('sound effects', () {
    test('several play at once, each at the saved volume', () async {
      final rig = _Rig(settings: const AudioSettings(sfxVolume: 0.5));

      await rig.audio.playSfx('audio/tap.wav');
      await rig.audio.playSfx('audio/tap.wav');
      await rig.audio.playSfx('audio/win.wav');

      expect(rig.engine.calls, [
        'sfx audio/tap.wav 0.5',
        'sfx audio/tap.wav 0.5',
        'sfx audio/win.wav 0.5',
      ]);
    });

    test('switched off or volume 0: nothing reaches the player', () async {
      final off = _Rig(settings: const AudioSettings(sfxEnabled: false));
      await off.audio.playSfx('audio/tap.wav');
      final silent = _Rig(settings: const AudioSettings(sfxVolume: 0));
      await silent.audio.playSfx('audio/tap.wav');

      expect(off.engine.calls, isEmpty);
      expect(silent.engine.calls, isEmpty);
    });

    test(
      'the two switches are separate: music off, effects still play',
      () async {
        final rig = _Rig(settings: const AudioSettings(bgmEnabled: false));

        await rig.audio.playSfx('audio/tap.wav');

        expect(rig.engine.calls, ['sfx audio/tap.wav 1.0']);
      },
    );
  });
}
