import 'package:flutter/foundation.dart';

/// What the person chose for sound: each of the background music and the sound
/// effects is on or off and has a volume from 0 to 1. Neutral defaults: both on
/// at full volume (the app's own sound levels are in its files).
@immutable
class AudioSettings {
  const AudioSettings({
    this.bgmEnabled = true,
    this.bgmVolume = 1.0,
    this.sfxEnabled = true,
    this.sfxVolume = 1.0,
  });

  final bool bgmEnabled;
  final double bgmVolume;
  final bool sfxEnabled;
  final double sfxVolume;

  /// Music that should reach the player: on and not turned down to nothing.
  bool get bgmAudible => bgmEnabled && bgmVolume > 0;

  /// Effects that should reach the player.
  bool get sfxAudible => sfxEnabled && sfxVolume > 0;

  AudioSettings copyWith({
    bool? bgmEnabled,
    double? bgmVolume,
    bool? sfxEnabled,
    double? sfxVolume,
  }) => AudioSettings(
    bgmEnabled: bgmEnabled ?? this.bgmEnabled,
    bgmVolume: bgmVolume ?? this.bgmVolume,
    sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    sfxVolume: sfxVolume ?? this.sfxVolume,
  );

  @override
  bool operator ==(Object other) =>
      other is AudioSettings &&
      other.bgmEnabled == bgmEnabled &&
      other.bgmVolume == bgmVolume &&
      other.sfxEnabled == sfxEnabled &&
      other.sfxVolume == sfxVolume;

  @override
  int get hashCode => Object.hash(bgmEnabled, bgmVolume, sfxEnabled, sfxVolume);

  @override
  String toString() =>
      'AudioSettings(bgm: $bgmEnabled $bgmVolume, sfx: $sfxEnabled $sfxVolume)';
}
