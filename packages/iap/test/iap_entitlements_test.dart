import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owned = {'itemType': 'ads-removal', 'itemRef': 'remove'};

  final signedFlag = NotifierProvider<_Flag, bool>(_Flag.new);

  ProviderContainer containerOn(Harness h, {bool signedIn = true}) {
    final container = ProviderContainer(
      overrides: [
        iapApiProvider.overrideWithValue(
          IapApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: h.adapter)),
        ),
        iapStoreProvider.overrideWithValue(InAppPurchase.instance),
        iapPlatformProvider.overrideWithValue('android'),
        signedFlag.overrideWith(() => _Flag(signedIn)),
        iapSignedInProvider.overrideWith((ref) => ref.watch(signedFlag)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('owns() says yes only for a listed item', () async {
    final h = Harness()..entitlements = [owned];
    addTearDown(h.dispose);
    final container = containerOn(h);
    container.listen(iapEntitlementsProvider, (_, _) {});

    final value = await container.read(iapEntitlementsProvider.future);

    expect(value.owns('ads-removal', 'remove'), isTrue);
    expect(value.owns('ads-removal', 'other'), isFalse);
    expect(value.owns('cheer', 'remove'), isFalse);
  });

  test('signed out: nothing is asked and nothing is owned', () async {
    final h = Harness()..entitlements = [owned];
    addTearDown(h.dispose);
    final container = containerOn(h, signedIn: false);
    container.listen(iapEntitlementsProvider, (_, _) {});

    final value = await container.read(iapEntitlementsProvider.future);

    expect(value.owns('ads-removal', 'remove'), isFalse);
    expect(h.entitlementReads, 0);
  });

  test(
    'after a grant (a purchase or a restore) the entitlements are read again',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final container = containerOn(h);
      container.listen(iapEntitlementsProvider, (_, _) {});
      container.listen(iapServiceProvider, (_, _) {});
      container.listen(iapOutcomesProvider, (_, _) {});
      final before = await container.read(iapEntitlementsProvider.future);
      expect(before.owns('ads-removal', 'remove'), isFalse);
      expect(h.entitlementReads, 1);

      // the person restores: the store hands the old purchase over again, the
      // server confirms it, and now the item is theirs
      h.entitlements = [owned];
      await container.read(iapServiceProvider)!.loadCatalog();
      final restored = googlePurchase(product: 'ads_removal', token: 'ads-3')
        ..status = PurchaseStatus.restored;
      h.store.deliver(restored);
      await pumpEventQueue();
      final after = await container.read(iapEntitlementsProvider.future);

      expect(h.entitlementReads, 2);
      expect(after.owns('ads-removal', 'remove'), isTrue);
    },
  );

  test(
    'a failed read is tried again when the app comes back to the front',
    () async {
      final h = Harness()..entitlementsFail = true;
      addTearDown(h.dispose);
      final container = containerOn(h);
      container.listen(iapEntitlementsProvider, (_, _) {}, onError: (_, _) {});
      await pumpEventQueue();
      expect(container.read(iapEntitlementsProvider).hasError, isTrue);
      expect(h.entitlementReads, 1);

      h.entitlementsFail = false;
      h.entitlements = [owned];
      final binding = WidgetsBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      final value = container.read(iapEntitlementsProvider).requireValue;

      expect(h.entitlementReads, 2);
      expect(value.owns('ads-removal', 'remove'), isTrue);
    },
  );

  test('another account signing in reads the entitlements again', () async {
    final h = Harness()..entitlements = [owned];
    addTearDown(h.dispose);
    final container = containerOn(h);
    container.listen(iapEntitlementsProvider, (_, _) {});
    expect(
      (await container.read(iapEntitlementsProvider.future))
          .owns('ads-removal', 'remove'),
      isTrue,
    );

    // sign out: nothing owned, nothing asked
    container.read(signedFlag.notifier).set(false);
    expect(
      (await container.read(iapEntitlementsProvider.future))
          .owns('ads-removal', 'remove'),
      isFalse,
    );
    expect(h.entitlementReads, 1);

    // the next account owns nothing
    h.entitlements = [];
    container.read(signedFlag.notifier).set(true);
    final next = await container.read(iapEntitlementsProvider.future);
    expect(h.entitlementReads, 2);
    expect(next.owns('ads-removal', 'remove'), isFalse);
  });
  test('another account after a logout does not inherit the last account value', () async {
    final h = Harness()..entitlements = [owned];
    addTearDown(h.dispose);
    final container = containerOn(h);
    container
        .listen(iapEntitlementsProvider, (_, _) {}, onError: (_, _) {})
        .close();
    // the app root watches the signed-in flag (through the iap service)
    container.listen(iapServiceProvider, (_, _) {});
    final a = await container.read(iapEntitlementsProvider.future);
    expect(a.owns('ads-removal', 'remove'), isTrue);

    // A signs out and nobody reads the provider; B signs in and the read fails
    container.read(signedFlag.notifier).set(false);
    await pumpEventQueue();
    container.read(signedFlag.notifier).set(true);
    await pumpEventQueue();
    h.entitlementsFail = true;
    container.listen(iapEntitlementsProvider, (_, _) {}, onError: (_, _) {});
    final reading = container.read(iapEntitlementsProvider);
    expect(reading.forThisAccount, isNull, reason: 'a reload keeps nothing');
    expect(reading.isReadingForThisAccount, isTrue);

    await pumpEventQueue();
    final failed = container.read(iapEntitlementsProvider);
    expect(failed.hasError, isTrue);
    expect(failed.forThisAccount, isNull, reason: 'an error keeps nothing');
    expect(failed.isReadingForThisAccount, isFalse);
  });

  group('subscription', () {
    test('a server with the feature off (404) means no subscription', () async {
      final h = Harness()..subscriptionStatus = 404;
      addTearDown(h.dispose);
      final container = containerOn(h);
      container.listen(iapSubscriptionProvider, (_, _) {});
      expect(await container.read(iapSubscriptionProvider.future), isNull);
    });

    test('signed out: none, and nothing is asked', () async {
      final h = Harness()..subscription = _sub('ACTIVE');
      addTearDown(h.dispose);
      final container = containerOn(h, signedIn: false);
      container.listen(iapSubscriptionProvider, (_, _) {});
      expect(await container.read(iapSubscriptionProvider.future), isNull);
      expect(h.subscriptionReads, 0);
    });

    test(
      'a grant reads it again, a failed read is tried again on resume',
      () async {
        final h = Harness()..subscriptionStatus = 503;
        addTearDown(h.dispose);
        final container = containerOn(h);
        container.listen(
          iapSubscriptionProvider,
          (_, _) {},
          onError: (_, _) {},
        );
        container.listen(iapServiceProvider, (_, _) {});
        container.listen(iapOutcomesProvider, (_, _) {});
        await pumpEventQueue();
        expect(container.read(iapSubscriptionProvider).hasError, isTrue);

        h.subscriptionStatus = null;
        h.subscription = _sub('ACTIVE');
        final binding = WidgetsBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(h.subscriptionReads, 2);
        expect(
          container.read(iapSubscriptionProvider).requireValue?.status,
          'ACTIVE',
        );

        // a purchase the server grants
        h.subscription = _sub('ACTIVE', plan: 'premium');
        await container.read(iapServiceProvider)!.loadCatalog();
        h.store.deliver(googlePurchase(product: 'premium', token: 'sub-1'));
        await pumpEventQueue();
        expect(h.subscriptionReads, 3);
      },
    );
  });

  subscriptionTests();
}

Map<String, Object?> _sub(
  String status, {
  String plan = 'standard',
  String? end,
}) => {
  'id': 's1',
  'status': status,
  'planCode': plan,
  'provider': 'googleplay',
  'currentPeriodEnd': end ?? '2999-01-01T00:00:00Z',
};

void subscriptionTests() {
  final now = DateTime.utc(2026, 6, 1);

  group('keepsOn: is this plan running and paid for', () {
    IapSubscription row(
      String status, {
      String plan = 'standard',
      String? end,
    }) => IapSubscription.fromJson(_sub(status, plan: plan, end: end));

    test('ACTIVE and CANCELING (paid to the end of the period) are on', () {
      expect(row('ACTIVE').keepsOn('standard', now), isTrue);
      expect(row('CANCELING').keepsOn('standard', now), isTrue);
    });

    test('PAST_DUE, PENDING and ENDED are not', () {
      for (final s in ['PAST_DUE', 'PENDING', 'ENDED']) {
        expect(row(s).keepsOn('standard', now), isFalse, reason: s);
      }
    });

    test('another plan, a period that is over, or no period end is not', () {
      expect(row('ACTIVE', plan: 'premium').keepsOn('standard', now), isFalse);
      expect(
        row('ACTIVE', end: '2026-05-31T00:00:00Z').keepsOn('standard', now),
        isFalse,
      );
      expect(
        IapSubscription.fromJson({..._sub('ACTIVE'), 'currentPeriodEnd': null})
            .keepsOn('standard', now),
        isFalse,
      );
    });
  });
}

class _Flag extends Notifier<bool> {
  _Flag([this._initial = true]);

  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) => state = value;
}
