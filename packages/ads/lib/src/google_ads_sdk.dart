import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_sdk.dart';

/// The real SDK. Not covered by `flutter test` (platform views and channels);
/// check it on a device.
class GoogleAdsSdk implements AdsSdk {
  @override
  Future<void> requestConsentUpdate() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      done.complete,
      (error) => done.completeError(StateError(error.message)),
    );
    return done.future;
  }

  @override
  Future<void> showConsentFormIfRequired() {
    final done = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(StateError(error.message));
      }
    });
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptionsForm() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(StateError(error.message));
      }
    });
    return done.future;
  }

  @override
  Future<void> initialize() => MobileAds.instance.initialize();

  @override
  Future<LoadedInterstitial?> loadInterstitial(String unitId) {
    final done = Completer<LoadedInterstitial?>();
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => done.complete(_GoogleInterstitial(ad)),
        onAdFailedToLoad: (_) => done.complete(null),
      ),
    );
    return done.future;
  }

  @override
  Future<LoadedRewarded?> loadRewarded(
    String unitId, {
    String? ssvUserId,
    String? ssvCustomData,
  }) {
    final done = Completer<LoadedRewarded?>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          try {
            if (ssvUserId != null || ssvCustomData != null) {
              await ad.setServerSideOptions(
                ServerSideVerificationOptions(
                  userId: ssvUserId,
                  customData: ssvCustomData,
                ),
              );
            }
            done.complete(_GoogleRewarded(ad));
          } on Object {
            // without its verification options the reward could not be
            // credited: drop the ad
            await ad.dispose();
            done.complete(null);
          }
        },
        onAdFailedToLoad: (_) => done.complete(null),
      ),
    );
    return done.future;
  }

  @override
  Widget banner(BuildContext context, String unitId) =>
      _AnchoredBanner(unitId: unitId);
}

/// An anchored adaptive banner. Empty until it has loaded, and empty for good
/// when the load fails.
class _AnchoredBanner extends StatefulWidget {
  const _AnchoredBanner({required this.unitId});

  final String unitId;

  @override
  State<_AnchoredBanner> createState() => _AnchoredBannerState();
}

class _AnchoredBannerState extends State<_AnchoredBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The adaptive size depends on the width: a turn of the screen asks for a
    // new banner (Google's advice) instead of leaving a cut-off one.
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width == _width) return;
    _width = width;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _load(width);
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    // Gone, or the width changed again while the size was asked for.
    if (size == null || !mounted || width != _width) return;
    final ad = BannerAd(
      adUnitId: widget.unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (mounted && identical(loaded, _ad)) {
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (failed, _) {
          failed.dispose();
          if (identical(failed, _ad)) _ad = null;
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

class _GoogleInterstitial implements LoadedInterstitial {
  _GoogleInterstitial(this._ad);

  final InterstitialAd _ad;

  @override
  Future<bool> show() {
    final done = Completer<bool>();
    _ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (_) => done.complete(true),
      onAdFailedToShowFullScreenContent: (_, _) => done.complete(false),
    );
    _ad.show();
    return done.future;
  }

  @override
  void dispose() => _ad.dispose();
}

class _GoogleRewarded implements LoadedRewarded {
  _GoogleRewarded(this._ad);

  final RewardedAd _ad;

  @override
  Future<AdReward?> show() {
    final done = Completer<AdReward?>();
    AdReward? earned;
    _ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) => done.complete(earned),
      onAdFailedToShowFullScreenContent: (_, _) => done.complete(null),
    );
    _ad.show(
      onUserEarnedReward: (_, reward) =>
          earned = AdReward(type: reward.type, amount: reward.amount),
    );
    return done.future;
  }

  @override
  void dispose() => _ad.dispose();
}
