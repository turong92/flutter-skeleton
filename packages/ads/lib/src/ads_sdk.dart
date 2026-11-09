import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_ads_sdk.dart';

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

  /// One banner for [unitId], sized to the width of [context].
  Widget banner(BuildContext context, String unitId);
}

final adsSdkProvider = Provider<AdsSdk>((ref) => GoogleAdsSdk());
