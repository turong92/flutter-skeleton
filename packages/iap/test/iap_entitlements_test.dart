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
}

class _Flag extends Notifier<bool> {
  _Flag([this._initial = true]);

  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) => state = value;
}
