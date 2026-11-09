import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_ads_sdk.dart';

/// What the person earned from a rewarded ad (the unit's reward in the AdMob
/// console).
class AdReward {
  const AdReward({required this.type, required this.amount});

  final String type;
  final num amount;
}

/// An interstitial that is loaded and waiting.
abstract class LoadedInterstitial {
  /// Shows it; completes when it is closed. False when it could not be shown.
  Future<bool> show();

  void dispose();
}

/// A rewarded ad that is loaded and waiting.
abstract class LoadedRewarded {
  /// Shows it; completes when it is closed. The reward is there only when the
  /// SDK said it was earned (watched to the end); closing early gives null.
  Future<AdReward?> show();

  void dispose();
}

/// What the package needs from the ads SDK. Platform-view ads do not run in
/// `flutter test`, so widget tests swap this for `FakeAdsSdk`
/// (`package:skeleton_ads/testing.dart`).
abstract class AdsSdk {
  /// Asks for the consent state again. Throws when it cannot.
  Future<void> requestConsentUpdate();

  /// Shows the consent form when the person has to answer one.
  Future<void> showConsentFormIfRequired();

  /// Whether the consent kept by the SDK allows ad requests.
  Future<bool> canRequestAds();

  /// Whether the app must offer a way to change the consent.
  Future<bool> privacyOptionsRequired();

  Future<void> showPrivacyOptionsForm();

  /// Starts the ads SDK. Called once, and only when [canRequestAds] is true.
  Future<void> initialize();

  /// Loads one interstitial; null when none came.
  Future<LoadedInterstitial?> loadInterstitial(String unitId);

  /// Loads one rewarded ad; null when none came. With [ssvUserId] (and
  /// [ssvCustomData]) the ad carries them to Google's server-side
  /// verification callback, which is how a server may be asked to credit.
  Future<LoadedRewarded?> loadRewarded(
    String unitId, {
    String? ssvUserId,
    String? ssvCustomData,
  });

  /// One banner for [unitId], sized to the width of [context].
  Widget banner(BuildContext context, String unitId);
}

final adsSdkProvider = Provider<AdsSdk>((ref) => GoogleAdsSdk());
