/// Test double for apps that test against `ads`: import it from tests only
/// (`package:skeleton_ads/testing.dart`).
library;

import 'package:flutter/widgets.dart';
import 'package:skeleton_ads/skeleton_ads.dart';

class FakeAdsSdk implements AdsSdk {
  FakeAdsSdk({
    this.canRequest = true,
    this.updateFails = false,
    this.initializeFails = false,
    this.privacyRequired = false,
  });

  bool canRequest;
  bool updateFails;
  bool initializeFails;
  bool privacyRequired;

  /// The calls made, in order.
  final calls = <String>[];

  /// The key of the banner this fake draws.
  static const bannerKey = ValueKey('fake-ad-banner');

  @override
  Future<void> requestConsentUpdate() async {
    calls.add('requestConsentUpdate');
    if (updateFails) throw StateError('consent update failed');
  }

  @override
  Future<void> showConsentFormIfRequired() async {
    calls.add('showConsentFormIfRequired');
  }

  @override
  Future<bool> canRequestAds() async {
    calls.add('canRequestAds');
    return canRequest;
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptionsForm() async {
    calls.add('showPrivacyOptionsForm');
  }

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    if (initializeFails) throw StateError('initialize failed');
  }

  @override
  Widget banner(BuildContext context, String unitId) =>
      const SizedBox(key: bannerKey, height: 50);
}
