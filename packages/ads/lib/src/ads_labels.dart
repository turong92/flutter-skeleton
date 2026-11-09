/// The text of [AdsPrivacyOptionsButton]. The package does not translate: the
/// app passes its own (defaults are English).
class AdsLabels {
  const AdsLabels({this.privacyOptions = 'Ad privacy settings'});

  /// Korean texts, in the polite 해요 style.
  const AdsLabels.ko() : this(privacyOptions: '광고 개인정보 설정');

  final String privacyOptions;
}
