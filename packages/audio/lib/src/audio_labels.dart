/// The texts of [AudioSettingsSection]. The package does not translate: the app
/// passes its own (defaults are English).
class AudioLabels {
  const AudioLabels({
    this.bgm = 'Background music',
    this.sfx = 'Sound effects',
  });

  /// Korean texts, in the polite 해요 style.
  const AudioLabels.ko() : this(bgm: '배경음', sfx: '효과음');

  final String bgm;
  final String sfx;
}
