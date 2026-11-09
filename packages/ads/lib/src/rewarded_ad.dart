import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_controller.dart';
import 'ads_retry.dart';
import 'ads_sdk.dart';

/// `loading` until an ad is loaded; `ready` when one waits (turn the "watch an
/// ad" button on only then: a rewarded ad must be a person's own choice);
/// `unavailable` when none came.
enum RewardedStatus { loading, ready, unavailable }

/// [ssvUserId] is the account id Google's server-side verification callback
/// carries as `user_id`; the app passes it when a server credits the reward.
typedef RewardedKey = ({String unitId, String? ssvUserId});

class RewardedAdController extends Notifier<RewardedStatus> {
  RewardedAdController(this.key);

  final RewardedKey key;
  LoadedRewarded? _ad;
  bool _loading = false;
  int _misses = 0;
  Timer? _retry;

  @override
  RewardedStatus build() {
    ref.onDispose(() {
      _retry?.cancel();
      _ad?.dispose();
      _ad = null;
    });
    final ads = ref.watch(adsControllerProvider);
    if (ads == AdsStatus.ready) {
      Future.microtask(_load);
      return RewardedStatus.loading;
    }
    return ads == AdsStatus.starting
        ? RewardedStatus.loading
        : RewardedStatus.unavailable;
  }

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    _retry?.cancel();
    _loading = true;
    LoadedRewarded? ad;
    try {
      ad = await ref
          .read(adsSdkProvider)
          .loadRewarded(key.unitId, ssvUserId: key.ssvUserId);
    } on Object {
      ad = null;
    }
    _loading = false;
    if (!ref.mounted) {
      ad?.dispose();
      return;
    }
    _ad = ad;
    if (ad == null) {
      state = RewardedStatus.unavailable;
      // no fill or no network: try again later, with growing waits, so the
      // button comes back by itself
      _retry = Timer(ref.read(adsRetryDelayProvider)(_misses++), _load);
      return;
    }
    _misses = 0;
    state = RewardedStatus.ready;
  }

  /// Shows the ad. The reward when the SDK said it was earned, else null
  /// (closed early, not ready, could not show). Then the next ad is loaded.
  ///
  /// A server must not be asked to credit from this value: anyone can call
  /// such an endpoint. Credit through Google's server-side verification.
  Future<AdReward?> show() async {
    final ad = _ad;
    if (ad == null || state != RewardedStatus.ready) return null;
    _ad = null;
    state = RewardedStatus.loading;
    AdReward? reward;
    try {
      reward = await ad.show();
    } on Object {
      reward = null;
    }
    ad.dispose();
    if (ref.mounted) await _load();
    return reward;
  }
}

final rewardedAdProvider = NotifierProvider.autoDispose
    .family<RewardedAdController, RewardedStatus, RewardedKey>(
      RewardedAdController.new,
    );
