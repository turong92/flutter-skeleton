import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_sdk.dart';

/// `starting` until the consent flow is over; `ready` when the SDK runs and
/// ads may be asked for; `unavailable` when consent was refused or the SDK
/// would not start.
enum AdsStatus { starting, ready, unavailable }

/// Watch it once at the app root. Each app start: consent update, the consent
/// form if one is due, and only when the kept consent allows ad requests, one
/// SDK initialize.
class AdsController extends Notifier<AdsStatus> {
  @override
  AdsStatus build() {
    unawaited(Future.microtask(_start));
    return AdsStatus.starting;
  }

  Future<void> _start() async {
    final sdk = ref.read(adsSdkProvider);
    // A failed update or form is not the end: the SDK keeps the answer from
    // before, and canRequestAds reads that (Google's own advice).
    try {
      await sdk.requestConsentUpdate();
    } on Object {
      // fall through to the consent kept from before
    }
    try {
      await sdk.showConsentFormIfRequired();
    } on Object {
      // same
    }
    var status = AdsStatus.unavailable;
    try {
      if (await sdk.canRequestAds()) {
        await sdk.initialize();
        status = AdsStatus.ready;
      }
    } on Object {
      status = AdsStatus.unavailable;
    }
    if (ref.mounted) state = status;
  }
}

final adsControllerProvider = NotifierProvider<AdsController, AdsStatus>(
  AdsController.new,
);

/// True when the person has paid to remove ads: the banner is not drawn and no
/// interstitial is loaded or shown. Rewarded ads (a person's own choice), the
/// consent flow and the privacy button are not affected. The app overrides it
/// with what its server said; `skeleton_ads` does not know how it was bought.
final adsRemovedProvider = Provider<bool>((ref) => false);
