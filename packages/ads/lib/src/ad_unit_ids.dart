import 'package:flutter/foundation.dart';

/// Which ad unit to ask for. A real unit is used only in a release build:
/// seeing and tapping your own real ads while developing is the classic reason
/// an AdMob account is suspended. To see real ads in a debug build, register
/// the device as a test device in the AdMob console.
abstract final class AdUnitIds {
  /// Google's published test banner units.
  static const testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const testBannerIos = 'ca-app-pub-3940256099942544/2435281174';

  /// [android] / [ios] are the app's real units (empty = none). [release] and
  /// [platform] are for tests.
  static String banner({
    String android = '',
    String ios = '',
    bool release = kReleaseMode,
    TargetPlatform? platform,
  }) {
    final isIos = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    final real = isIos ? ios : android;
    if (release && real.isNotEmpty) return real;
    return isIos ? testBannerIos : testBannerAndroid;
  }
}
