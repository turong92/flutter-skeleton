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
/// one [AudioPool] per effect file.
class AudioplayersEngine implements AudioEngine {
  AudioplayersEngine({AudioContext? context})
    : _context = context ?? ambientAudioContext;

  final AudioContext _context;
  final _bgm = AudioPlayer();
  final _pools = <String, Future<AudioPool>>{};
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    _ready = true;
    await AudioPlayer.global.setAudioContext(_context);
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
    final pool = await _pools.putIfAbsent(
      asset,
      () => AudioPool.createFromAsset(path: asset, maxPlayers: 4),
    );
    await pool.start(volume: volume);
  }

  @override
  Future<void> dispose() async {
    await _bgm.dispose();
    for (final pool in _pools.values) {
      await (await pool).dispose();
    }
  }
}
