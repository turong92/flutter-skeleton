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
    this.interstitialLoadFails = false,
    this.interstitialShowFails = false,
    this.rewardedLoadFails = false,
    this.reward = const AdReward(type: 'coin', amount: 1),
  });

  bool canRequest;
  bool updateFails;
  bool initializeFails;
  bool privacyRequired;
  bool interstitialLoadFails;
  bool interstitialShowFails;
  bool rewardedLoadFails;

  /// What a rewarded ad hands over when shown; null = closed early.
  AdReward? reward;

  /// How many interstitials were shown.
  int interstitialsShown = 0;

  /// The account id the last rewarded ad was loaded with.
  String? lastSsvUserId;

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
  Future<LoadedInterstitial?> loadInterstitial(String unitId) async {
    calls.add('loadInterstitial');
    return interstitialLoadFails ? null : _FakeInterstitial(this);
  }

  @override
  Future<LoadedRewarded?> loadRewarded(
    String unitId, {
    String? ssvUserId,
    String? ssvCustomData,
  }) async {
    calls.add('loadRewarded');
    lastSsvUserId = ssvUserId;
    return rewardedLoadFails ? null : _FakeRewarded(this);
  }

  @override
  Widget banner(BuildContext context, String unitId) =>
      const SizedBox(key: bannerKey, height: 50);
}

class _FakeInterstitial implements LoadedInterstitial {
  _FakeInterstitial(this._sdk);

  final FakeAdsSdk _sdk;

  @override
  Future<bool> show() async {
    if (_sdk.interstitialShowFails) return false;
    _sdk.interstitialsShown++;
    return true;
  }

  @override
  void dispose() {}
}

class _FakeRewarded implements LoadedRewarded {
  _FakeRewarded(this._sdk);

  final FakeAdsSdk _sdk;

  @override
  Future<AdReward?> show() async => _sdk.reward;

  @override
  void dispose() {}
}
