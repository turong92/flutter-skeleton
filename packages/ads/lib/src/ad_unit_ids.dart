import 'package:flutter/foundation.dart';

/// Which ad unit to ask for. A real unit is used only in a release build:
/// seeing and tapping your own real ads while developing is the classic reason
/// an AdMob account is suspended. To see real ads in a debug build, register
/// the device as a test device in the AdMob console.
abstract final class AdUnitIds {
  /// Google's published test units.
  static const testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const testBannerIos = 'ca-app-pub-3940256099942544/2435281174';
  static const testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  /// [android] / [ios] are the app's real units (empty = none). [release] and
  /// [platform] are for tests.
  static String banner({
    String android = '',
    String ios = '',
    bool release = kReleaseMode,
    TargetPlatform? platform,
  }) =>
      _pick(android, ios, release, platform, testBannerAndroid, testBannerIos);

  static String interstitial({
    String android = '',
    String ios = '',
    bool release = kReleaseMode,
    TargetPlatform? platform,
  }) => _pick(
    android,
    ios,
    release,
    platform,
    testInterstitialAndroid,
    testInterstitialIos,
  );

  static String rewarded({
    String android = '',
    String ios = '',
    bool release = kReleaseMode,
    TargetPlatform? platform,
  }) => _pick(
    android,
    ios,
    release,
    platform,
    testRewardedAndroid,
    testRewardedIos,
  );

  static String _pick(
    String android,
    String ios,
    bool release,
    TargetPlatform? platform,
    String testAndroid,
    String testIos,
  ) {
    final isIos = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    final real = isIos ? ios : android;
    if (release && real.isNotEmpty) return real;
    return isIos ? testIos : testAndroid;
  }
}
