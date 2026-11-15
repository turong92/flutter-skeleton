import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_engine.dart';
import 'audio_settings.dart';
import 'audio_settings_providers.dart';

/// How long the music takes to fade out and in when the track changes.
final audioFadeProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// What the app calls to make sound. Read it once where the app starts, so the
/// app lifecycle is followed from the first frame.
final audioProvider = Provider<Audio>((ref) {
  final audio = Audio._(
    ref.watch(audioEngineProvider),
    ref.watch(audioFadeProvider),
    ref.read(audioSettingsProvider),
  );
  ref.listen(audioSettingsProvider, (_, next) => audio._settingsChanged(next));
  ref.onDispose(audio._dispose);
  return audio;
});

/// Music and effects, held to the person's [AudioSettings] and to the app's
/// state: music asked for while it is switched off, turned down to 0 or the app
/// is in the background does not reach the player, and plays when it may.
class Audio with WidgetsBindingObserver {
  Audio._(this._engine, this._fade, this._settings) {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioEngine _engine;
  final Duration _fade;
  AudioSettings _settings;

  String? _wanted; // what the app asked for
  String? _loaded; // what the player holds
  bool _paused = false; // the player holds it paused
  double _volume = 0; // the volume the player is at
  bool _background = false;
  Future<void> _tail = Future.value();

  /// Play [asset] as the background music, on a loop; the track that plays now
  /// fades out first. The same track again does nothing.
  Future<void> playBgm(String asset) {
    _wanted = asset;
    return _reconcile();
  }

  /// End the music (it fades out).
  Future<void> stopBgm() {
    _wanted = null;
    return _reconcile();
  }

  /// Play a short sound; calls overlap. Nothing when effects are off or at 0.
  Future<void> playSfx(String asset) async {
    if (!_settings.sfxAudible) return;
    await _engine.playSfx(asset, _settings.sfxVolume);
  }

  void _settingsChanged(AudioSettings next) {
    _settings = next;
    _reconcile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is a call, the control center, a dialog: the music goes on.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _background = true;
    } else if (state == AppLifecycleState.resumed) {
      _background = false;
    } else {
      return;
    }
    _reconcile();
  }

  Future<void> _dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _tail;
    await _engine.dispose();
  }

  // One change at a time, each looking at what is wanted when its turn comes.
  Future<void> _reconcile() {
    final run = _tail.then((_) => _apply());
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<void> _apply() async {
    final want = _wanted;
    final settings = _settings;
    if (want == null || !settings.bgmAudible) {
      if (_loaded == null) return;
      if (want == null && settings.bgmAudible && !_paused && !_background) {
        await _ramp(0);
      }
      _loaded = null;
      _paused = false;
      await _engine.stopBgm();
      return;
    }
    if (_background) {
      if (_loaded != null && !_paused) {
        _paused = true;
        await _engine.pauseBgm();
      }
      return;
    }
    if (_loaded == want) {
      if (_paused) {
        _paused = false;
        await _engine.resumeBgm();
      }
      if (_volume != settings.bgmVolume) await _setVolume(settings.bgmVolume);
      return;
    }
    if (_loaded != null && !_paused) await _ramp(0);
    _loaded = want;
    _paused = false;
    if (_fade == Duration.zero) {
      _volume = settings.bgmVolume;
      await _engine.startBgm(want, _volume);
    } else {
      _volume = 0;
      await _engine.startBgm(want, 0);
      await _ramp(settings.bgmVolume);
    }
  }

  Future<void> _setVolume(double volume) async {
    _volume = volume;
    await _engine.setBgmVolume(volume);
  }

  /// A short straight ramp of the music volume to [to].
  Future<void> _ramp(double to) async {
    if (_fade == Duration.zero) return;
    const steps = 8;
    final from = _volume;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_fade ~/ steps);
      await _setVolume(i == steps ? to : from + (to - from) * i / steps);
    }
  }
}
