import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_ads/testing.dart';

var _now = DateTime(2026, 1, 1, 12);

ProviderContainer containerWith(FakeAdsSdk sdk, {bool removed = false}) {
  _now = DateTime(2026, 1, 1, 12);
  final container = ProviderContainer(
    overrides: [
      adsSdkProvider.overrideWithValue(sdk),
      adsRemovedProvider.overrideWithValue(removed),
      adsClockProvider.overrideWithValue(() => _now),
      adsRetryDelayProvider.overrideWithValue(
        (_) => const Duration(milliseconds: 5),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  const unit = 'interstitial-unit';

  group('interstitial', () {
    test('nothing is loaded before the ads are ready', () async {
      final sdk = FakeAdsSdk(canRequest: false);
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider(unit), (_, _) {});
      final ads = container.read(interstitialAdProvider(unit));
      await settle();
      expect(sdk.calls.where((c) => c.startsWith('loadInterstitial')), isEmpty);
      expect(await ads.showIfAllowed(), isFalse);
      await settle();
      expect(sdk.calls.where((c) => c.startsWith('loadInterstitial')), isEmpty);
    });

    test('right after the start and for the minimum interval after a close it is held back', () async {
      final sdk = FakeAdsSdk();
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider(unit), (_, _) {});
      final ads = container.read(interstitialAdProvider(unit));
      await settle();
      expect(sdk.calls, contains('loadInterstitial'));

      expect(await ads.showIfAllowed(), isFalse, reason: 'just loaded');
      _now = _now.add(const Duration(seconds: 61));
      expect(await ads.showIfAllowed(), isTrue);
      expect(sdk.interstitialsShown, 1);

      await settle();
      _now = _now.add(const Duration(seconds: 30));
      expect(await ads.showIfAllowed(), isFalse, reason: 'closed 30s ago');
      _now = _now.add(const Duration(seconds: 31));
      expect(await ads.showIfAllowed(), isTrue);
      expect(sdk.interstitialsShown, 2);
    });

    test(
      'after a close, and after a failed show, the next one is loaded',
      () async {
        final sdk = FakeAdsSdk();
        final container = containerWith(sdk);
        container.listen(adsControllerProvider, (_, _) {});
        container.listen(interstitialAdProvider(unit), (_, _) {});
        final ads = container.read(interstitialAdProvider(unit));
        await settle();
        _now = _now.add(const Duration(minutes: 2));
        await ads.showIfAllowed();
        await settle();
        expect(sdk.calls.where((c) => c == 'loadInterstitial'), hasLength(2));

        sdk.interstitialShowFails = true;
        _now = _now.add(const Duration(minutes: 2));
        expect(await ads.showIfAllowed(), isFalse);
        await settle();
        expect(sdk.calls.where((c) => c == 'loadInterstitial'), hasLength(3));
      },
    );

    test('one clock for every unit: a second unit does not show right after the first', () async {
      final sdk = FakeAdsSdk();
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider('unit-a'), (_, _) {});
      container.listen(interstitialAdProvider('unit-b'), (_, _) {});
      final a = container.read(interstitialAdProvider('unit-a'));
      final b = container.read(interstitialAdProvider('unit-b'));
      await settle();

      _now = _now.add(const Duration(seconds: 61));
      expect(await a.showIfAllowed(), isTrue);
      expect(await b.showIfAllowed(), isFalse, reason: 'a closed just now');
      _now = _now.add(const Duration(seconds: 61));
      expect(await b.showIfAllowed(), isTrue);
    });

    test('a load that failed is tried again later', () async {
      final sdk = FakeAdsSdk(interstitialLoadFails: true);
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider(unit), (_, _) {});
      final ads = container.read(interstitialAdProvider(unit));
      await settle();
      sdk.interstitialLoadFails = false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      _now = _now.add(const Duration(minutes: 5));
      expect(await ads.showIfAllowed(), isTrue);
    });

    test('ads removed: none is loaded and none is shown', () async {
      final sdk = FakeAdsSdk();
      final container = containerWith(sdk, removed: true);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider(unit), (_, _) {});
      final ads = container.read(interstitialAdProvider(unit));
      await settle();
      _now = _now.add(const Duration(minutes: 5));

      expect(await ads.showIfAllowed(), isFalse);
      expect(sdk.calls.where((c) => c == 'loadInterstitial'), isEmpty);
    });

    test('a failed load shows nothing and does not wait', () async {
      final sdk = FakeAdsSdk(interstitialLoadFails: true);
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(interstitialAdProvider(unit), (_, _) {});
      final ads = container.read(interstitialAdProvider(unit));
      await settle();
      _now = _now.add(const Duration(minutes: 5));
      expect(await ads.showIfAllowed(), isFalse);
      expect(sdk.interstitialsShown, 0);
    });
  });

  group('rewarded', () {
    const key = (unitId: 'rewarded-unit', ssvUserId: 'acc_1');

    Future<ProviderContainer> started(FakeAdsSdk sdk) async {
      final container = containerWith(sdk);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(rewardedAdProvider(key), (_, _) {});
      await settle();
      return container;
    }

    test('ready only once an ad is loaded', () async {
      final sdk = FakeAdsSdk(canRequest: false);
      final container = await started(sdk);
      expect(
        container.read(rewardedAdProvider(key)),
        RewardedStatus.unavailable,
      );

      final ok = await started(FakeAdsSdk());
      expect(ok.read(rewardedAdProvider(key)), RewardedStatus.ready);
    });

    test('ads removed does not touch the rewarded ad', () async {
      final sdk = FakeAdsSdk();
      final container = containerWith(sdk, removed: true);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(rewardedAdProvider(key), (_, _) {});
      await settle();
      expect(container.read(rewardedAdProvider(key)), RewardedStatus.ready);
    });

    test('the reward comes only when the SDK reported one; closing early gives null', () async {
      final sdk = FakeAdsSdk(reward: const AdReward(type: 'coin', amount: 5));
      final container = await started(sdk);
      final reward = await container
          .read(rewardedAdProvider(key).notifier)
          .show();
      expect(reward?.amount, 5);
      expect(reward?.type, 'coin');
      await settle();
      expect(container.read(rewardedAdProvider(key)), RewardedStatus.ready);

      sdk.reward = null;
      expect(
        await container.read(rewardedAdProvider(key).notifier).show(),
        isNull,
      );
    });

    test('the account id goes to the SDK for the server-side check', () async {
      final sdk = FakeAdsSdk();
      await started(sdk);
      expect(sdk.lastSsvUserId, 'acc_1');
    });

    test(
      'a load that failed is tried again, and the button comes back',
      () async {
        final sdk = FakeAdsSdk(rewardedLoadFails: true);
        final container = await started(sdk);
        expect(
          container.read(rewardedAdProvider(key)),
          RewardedStatus.unavailable,
        );
        sdk.rewardedLoadFails = false;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(rewardedAdProvider(key)), RewardedStatus.ready);
      },
    );

    test('a failed load leaves it unavailable and show gives null', () async {
      final sdk = FakeAdsSdk(rewardedLoadFails: true);
      final container = await started(sdk);
      expect(
        container.read(rewardedAdProvider(key)),
        RewardedStatus.unavailable,
      );
      expect(
        await container.read(rewardedAdProvider(key).notifier).show(),
        isNull,
      );
    });
  });
}
