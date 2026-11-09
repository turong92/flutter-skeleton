import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_ads/skeleton_ads.dart';

void main() {
  const real = 'ca-app-pub-1111111111111111/2222222222';

  test(
    'outside a release build the test unit is used, whatever the app set',
    () {
      expect(
        AdUnitIds.banner(
          android: real,
          ios: real,
          release: false,
          platform: TargetPlatform.android,
        ),
        AdUnitIds.testBannerAndroid,
      );
      expect(
        AdUnitIds.banner(
          android: real,
          ios: real,
          release: false,
          platform: TargetPlatform.iOS,
        ),
        AdUnitIds.testBannerIos,
      );
    },
  );

  test(
    'a release build uses the real unit, and the test unit when it is empty',
    () {
      expect(
        AdUnitIds.banner(
          android: real,
          release: true,
          platform: TargetPlatform.android,
        ),
        real,
      );
      expect(
        AdUnitIds.banner(release: true, platform: TargetPlatform.iOS),
        AdUnitIds.testBannerIos,
      );
    },
  );
}
