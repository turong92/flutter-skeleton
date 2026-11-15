import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The boundary over the sound player, so tests run without a platform. The
/// files are Flutter assets, named as in `pubspec.yaml` without the `assets/`
/// folder `audioplayers` adds (`audio/theme.mp3` = `assets/audio/theme.mp3`).
abstract class AudioEngine {
  /// Play [asset] on a loop at [volume], replacing the music that plays.
  Future<void> startBgm(String asset, double volume);
  Future<void> setBgmVolume(double volume);
  Future<void> pauseBgm();
  Future<void> resumeBgm();
  Future<void> stopBgm();

  /// Play a short sound once; calls overlap.
  Future<void> playSfx(String asset, double volume);

  Future<void> dispose();
}

final audioEngineProvider = Provider<AudioEngine>(
  (ref) => AudioplayersEngine(),
);

/// The session of a game's music (see README): iOS `ambient` (follows the
/// silent switch, mixes with other apps' music), Android game usage that does
/// not take the audio focus from other apps.
final ambientAudioContext = AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.game,
    contentType: AndroidContentType.music,
    audioFocus: AndroidAudioFocus.none,
  ),
);

/// [AudioEngine] over `audioplayers`: one looping player for the music, and
/// up to four players per effect file, used in turn.
class AudioplayersEngine implements AudioEngine {
  AudioplayersEngine({AudioContext? context})
    : _context = context ?? ambientAudioContext;

  final AudioContext _context;
  final _bgm = AudioPlayer();
  final _sfx = <String, List<AudioPlayer>>{};
  static const _maxSfxAtOnce = 4;
  Future<void>? _ready;

  /// The session is set on the music player itself: a player copies the
  /// default context when it is made, so the global one comes too late for it.
  /// A failed setup is tried again by the next call.
  Future<void> _ensureReady() => _ready ??= _setUp().onError((e, s) {
    _ready = null;
    Error.throwWithStackTrace(e!, s);
  });

  Future<void> _setUp() async {
    await AudioPlayer.global.setAudioContext(_context);
    await _bgm.setAudioContext(_context);
    await _bgm.setReleaseMode(ReleaseMode.loop);
  }

  @override
  Future<void> startBgm(String asset, double volume) async {
    await _ensureReady();
    await _bgm.play(AssetSource(asset), volume: volume);
  }

  @override
  Future<void> setBgmVolume(double volume) => _bgm.setVolume(volume);

  @override
  Future<void> pauseBgm() => _bgm.pause();

  @override
  Future<void> resumeBgm() => _bgm.resume();

  @override
  Future<void> stopBgm() => _bgm.stop();

  @override
  Future<void> playSfx(String asset, double volume) async {
    await _ensureReady();
    final players = _sfx.putIfAbsent(asset, () => []);
    var player = players
        .where((p) => p.state != PlayerState.playing)
        .firstOrNull;
    if (player == null) {
      // A fifth sound of one file at once is dropped: the players are made
      // once, so nothing grows with the number of calls.
      if (players.length >= _maxSfxAtOnce) return;
      player = AudioPlayer();
      players.add(player);
      await player.setAudioContext(_context);
    }
    await player.play(AssetSource(asset), volume: volume);
  }

  @override
  Future<void> dispose() async {
    final all = [_bgm, for (final players in _sfx.values) ...players];
    _sfx.clear();
    for (final player in all) {
      try {
        await player.dispose();
      } on Object {
        // go on with the others
      }
    }
  }
}
