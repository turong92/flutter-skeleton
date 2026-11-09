import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_ads/testing.dart';

ProviderContainer containerWith(FakeAdsSdk sdk) {
  final container = ProviderContainer(
    overrides: [adsSdkProvider.overrideWithValue(sdk)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<AdsStatus> started(ProviderContainer container) async {
  container.listen(adsControllerProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container.read(adsControllerProvider);
}

void main() {
  test('consent update, then the form, then one initialize', () async {
    final sdk = FakeAdsSdk();
    final container = containerWith(sdk);
    expect(await started(container), AdsStatus.ready);
    expect(sdk.calls, [
      'requestConsentUpdate',
      'showConsentFormIfRequired',
      'canRequestAds',
      'initialize',
    ]);
  });

  test(
    'no consent: the SDK is not initialized and the banner is empty',
    () async {
      final sdk = FakeAdsSdk(canRequest: false);
      final container = containerWith(sdk);
      expect(await started(container), AdsStatus.unavailable);
      expect(sdk.calls, isNot(contains('initialize')));
    },
  );

  test(
    'a failed consent update still reads the consent kept from before',
    () async {
      final sdk = FakeAdsSdk(updateFails: true);
      final container = containerWith(sdk);
      expect(await started(container), AdsStatus.ready);
      expect(sdk.calls, contains('canRequestAds'));
      expect(sdk.calls, contains('initialize'));

      final refused = FakeAdsSdk(updateFails: true, canRequest: false);
      expect(await started(containerWith(refused)), AdsStatus.unavailable);
    },
  );

  test('an SDK that fails to start leaves the ads unavailable', () async {
    final sdk = FakeAdsSdk(initializeFails: true);
    expect(await started(containerWith(sdk)), AdsStatus.unavailable);
  });

  testWidgets('the banner draws only when the ads are ready', (tester) async {
    Future<void> pump(FakeAdsSdk sdk) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [adsSdkProvider.overrideWithValue(sdk)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(adsControllerProvider);
                return const AdBanner(unitId: 'unit');
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pump(FakeAdsSdk());
    expect(find.byKey(FakeAdsSdk.bannerKey), findsOneWidget);

    await pump(FakeAdsSdk(canRequest: false));
    expect(find.byKey(FakeAdsSdk.bannerKey), findsNothing);
  });

  testWidgets('the privacy button shows only when the form is required', (
    tester,
  ) async {
    Future<FakeAdsSdk> pump({required bool required}) async {
      final sdk = FakeAdsSdk(privacyRequired: required);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [adsSdkProvider.overrideWithValue(sdk)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(adsControllerProvider);
                return const AdsPrivacyOptionsButton();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      return sdk;
    }

    var sdk = await pump(required: false);
    expect(find.byType(OutlinedButton), findsNothing);

    sdk = await pump(required: true);
    expect(find.text('Ad privacy settings'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(sdk.calls, contains('showPrivacyOptionsForm'));
  });
}
