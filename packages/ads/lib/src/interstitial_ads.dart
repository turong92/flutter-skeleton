import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_controller.dart';
import 'ads_retry.dart';
import 'ads_sdk.dart';

/// The clock of the interstitial interval; tests override it.
final adsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The least time between two interstitials, and between the start of the ads
/// and the first one. Google's policy keeps an interstitial from cutting into
/// content or opening the app, so this one rule holds both back. An app
/// overrides it with its own value.
final interstitialMinIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);

/// When the last interstitial of the whole app closed (or, before any, when
/// the first one loaded). One clock for every unit: a second unit does not
/// get to show right after the first. Not auto-disposed.
class InterstitialClock extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  DateTime? get last => state;

  void startIfUnset(DateTime now) => state ??= now;

  void set(DateTime now) => state = now;
}

final interstitialClockProvider =
    NotifierProvider<InterstitialClock, DateTime?>(InterstitialClock.new);

/// One interstitial kept loaded for [unitId].
class InterstitialAds {
  InterstitialAds(Ref ref, this.unitId)
    : _sdk = ref.read(adsSdkProvider),
      _now = ref.read(adsClockProvider),
      _minInterval = ref.read(interstitialMinIntervalProvider),
      _retryDelay = ref.read(adsRetryDelayProvider),
      _clock = ref.read(interstitialClockProvider.notifier);

  final String unitId;
  // Taken once: nothing reads a Ref after the provider is gone.
  final AdsSdk _sdk;
  final DateTime Function() _now;
  final Duration _minInterval;
  final Duration Function(int) _retryDelay;
  final InterstitialClock _clock;

  LoadedInterstitial? _ad;
  bool _loading = false;
  bool _showing = false;
  bool _disposed = false;
  // set by the provider from adsControllerProvider: no request before consent
  bool _ready = false;
  int _misses = 0;
  Timer? _retry;

  Future<void> _load() async {
    if (!_ready || _loading || _ad != null || _disposed) return;
    _retry?.cancel();
    _loading = true;
    LoadedInterstitial? ad;
    try {
      ad = await _sdk.loadInterstitial(unitId);
    } on Object {
      ad = null;
    }
    _loading = false;
    if (_disposed) {
      ad?.dispose();
      return;
    }
    _ad = ad;
    if (ad == null) {
      // no fill or no network: try again later, with growing waits
      _retry = Timer(_retryDelay(_misses++), _load);
      return;
    }
    _misses = 0;
    // the first ad starts the clock: not one right after the start
    _clock.startIfUnset(_now());
  }

  /// Shows the loaded interstitial when the interval has passed. True when it
  /// was shown. Never waits: with nothing loaded it only asks for one for
  /// next time.
  Future<bool> showIfAllowed() async {
    final ad = _ad;
    final since = _clock.last;
    if (_showing || ad == null || since == null) {
      unawaited(_load());
      return false;
    }
    if (_now().difference(since) < _minInterval) return false;
    _showing = true;
    _ad = null;
    var shown = false;
    try {
      shown = await ad.show();
    } on Object {
      shown = false;
    } finally {
      ad.dispose();
      _showing = false;
      _clock.set(_now());
    }
    await _load();
    return shown;
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _ad?.dispose();
    _ad = null;
  }
}

/// Keeps one interstitial loaded once the ads are ready.
final interstitialAdProvider = Provider.autoDispose
    .family<InterstitialAds, String>((ref, unitId) {
      final ads = InterstitialAds(ref, unitId);
      ref.listen(adsControllerProvider, (_, status) {
        ads._ready = status == AdsStatus.ready;
        if (ads._ready) ads._load();
      }, fireImmediately: true);
      ref.onDispose(ads.dispose);
      return ads;
    });
