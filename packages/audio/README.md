# skeleton_audio

Background music and sound effects for an app that picks `--packages audio` (a game, a serial): each is on or off with a volume from 0 to 1, kept on the device; the music loops and changes track with a short fade, pauses while the app is in the background; effects overlap. No backend, no web twin. The sound files are the app's.

| Piece | What it is |
|---|---|
| `AudioSettings` | `bgmEnabled`, `bgmVolume`, `sfxEnabled`, `sfxVolume`. Default: both on, full volume |
| `audioSettingsProvider` · `AudioSettingsController` | The settings now. `setBgmEnabled` · `setBgmVolume` · `setSfxEnabled` · `setSfxVolume` show the change at once and write it to the store (a volume is clamped to 0..1) |
| `AudioSettingsStore` · `SharedPreferencesAudioSettingsStore` | Where it is kept. `loadSavedAudioSettings(store)` reads it; `savedAudioSettingsProvider` hands it to the app before the first frame |
| `AudioSettingsSection(labels:)` | A switch and a slider for the music and for the effects. A slider is disabled while its sound is off. `AudioLabels` / `AudioLabels.ko()` are its two texts |
| `audioProvider` → `Audio` | `playBgm(asset)`, `stopBgm()`, `playSfx(asset)`. Read it once at the start so the app lifecycle is followed |
| `audioFadeProvider` | The fade between tracks (default 400 ms; `Duration.zero` = none) |
| `AudioEngine` (`audioEngineProvider`) | The boundary over the player. `AudioplayersEngine` is the real one; `FakeAudioEngine` and `MemoryAudioSettingsStore` are in `package:skeleton_audio/testing.dart` |

## What `Audio` does

- Music asked for while it is switched off or at volume 0 **never reaches the player**; it starts when the person switches it on. The same goes for effects (they are simply not played).
- `playBgm` of the track that is playing does nothing; another track fades the old one out, starts the new one at 0 and fades it in. `stopBgm` fades out.
- The app going to the background (`paused` / `hidden`) pauses the music and coming back resumes it. A short `inactive` (a call banner, the control center) does not.
- A volume change reaches the track that plays at once.

## Wiring

```dart
// main(): the settings before the first frame
final saved = await loadSavedAudioSettings(const SharedPreferencesAudioSettingsStore());
runApp(ProviderScope(overrides: [savedAudioSettingsProvider.overrideWithValue(saved)], child: const App()));

// pubspec.yaml: your files (the path audioplayers reads is assets/ + the name)
//   flutter: { assets: [assets/audio/] }
final audio = ref.read(audioProvider);
audio.playBgm('audio/theme.mp3');      // assets/audio/theme.mp3
audio.playSfx('audio/tap.wav');

// a settings screen
AudioSettingsSection(labels: context.byLocale(const AudioLabels.ko(), const AudioLabels()))
```

The starter (`--packages audio`) has only the settings section in the account screen and the saved settings; it has no sound files and plays nothing.

## The audio session, and why

Choice: **iOS `ambient`, Android game usage without taking the audio focus** (`ambientAudioContext`).

- iOS `ambient` follows the **silent switch** (a person who muted the phone expects a game to be quiet) and **mixes with other apps' music** (a game does not cut the podcast the person is hearing). It is the category Apple documents for "sound that is not the main purpose of the app" and what games use for their music.
- Android has no silent switch; `AndroidAudioFocus.none` with `game` usage makes the music mix with other apps as on iOS. The in-app switch is the person's control.
- Not chosen: stopping our music when another app plays. It needs the iOS secondary-audio hint, which `audioplayers` does not give, and mixing is the safer default.
- For an app whose sound is the point (a music or audio player), pass your own context: `AudioplayersEngine(context: AudioContext(...))` through `audioEngineProvider`. An `ambient` session cannot play while the phone is locked, and this package pauses on the background anyway.

## Player choice

`audioplayers` ^6 (pub.dev: 150/160 points, about 1.7 M downloads a month, updated this year). It has what is needed in one package: a looping player, `AudioPool` for overlapping short sounds and the audio session setting (`AudioContext`). `just_audio` + `audio_session` was the other candidate; it is as maintained, but has no sound pool for effects.

## Not here

The sound files; ducking for another app; playing while the app is in the background; streaming a URL; playing a sample when a slider is moved.

## Tests

```bash
cd packages/audio && flutter test
```
