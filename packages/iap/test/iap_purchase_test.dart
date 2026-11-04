import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

import 'support/fakes.dart';

void main() {
  // The first InAppPurchase.instance registers the Android platform, which
  // needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the account token', () {
    test(
      'a purchase carries the token the server gave, not one of the app',
      () async {
        final h = Harness();
        addTearDown(h.dispose);

        final catalog = await h.service.loadCatalog();
        await h.service.buy(catalog.offers.first);

        expect(h.store.bought.single.param.applicationUserName, serverToken);
      },
    );

    test(
      'a one-time product is not consumed before the server agrees',
      () async {
        final h = Harness();
        addTearDown(h.dispose);

        final catalog = await h.service.loadCatalog();
        await h.service.buy(
          catalog.offers.firstWhere(
            (o) => o.product.storeProductId == 'cheer_3000',
          ),
        );

        expect(h.store.bought.single.consumable, isTrue);
        expect(h.store.bought.single.autoConsume, isFalse);
      },
    );

    test('a restore carries the server token too', () async {
      final h = Harness();
      addTearDown(h.dispose);

      final catalog = await h.service.loadCatalog();
      await h.service.restore(catalog);

      expect(h.store.restoreNames, [serverToken]);
    });
  });

  group('before the server answers', () {
    test('nothing is completed and nothing is granted', () async {
      final answer = Completer<ResponseBody>();
      final h = Harness(onPurchase: (_) => answer.future);
      addTearDown(h.dispose);
      await h.start();

      h.store.deliver(purchase());
      await pumpEventQueue();

      expect(h.purchaseCalls, hasLength(1));
      expect(h.store.completed, isEmpty);
      expect(h.outcomes, isEmpty);

      answer.complete(granted());
      await pumpEventQueue();

      expect(h.store.completed, hasLength(1));
      expect(h.outcomes.single, isA<IapGranted>());
    });

    test(
      'Google sends the product and the purchase token, nothing else',
      () async {
        final h = Harness();
        addTearDown(h.dispose);
        await h.start();

        h.store.deliver(purchase(data: 'google-token'));
        await pumpEventQueue();

        expect(
          h.purchaseCalls.single.path,
          '/payments/iap/googleplay/purchases',
        );
        expect(h.purchaseCalls.single.data, {
          'productId': 'cheer_3000',
          'purchaseToken': 'google-token',
        });
      },
    );

    test('Apple sends the transaction id', () async {
      final h = Harness(platform: 'ios');
      addTearDown(h.dispose);
      await h.start();

      h.store.deliver(purchase(id: '2000000123'));
      await pumpEventQueue();

      expect(h.purchaseCalls.single.path, '/payments/iap/appstore/purchases');
      expect(h.purchaseCalls.single.data, {'transactionId': '2000000123'});
    });
  });

  group('what the server answers', () {
    // Not granted, and left open for a later run.
    final keepsOpen = <String, FutureOr<ResponseBody> Function()>{
      '202 PENDING': () => valueBody({'result': 'PENDING'}, status: 202),
      '409 owned elsewhere': () =>
          errorBody(409, 'PAYMENT.IAP_PURCHASE_OWNED_ELSEWHERE'),
      '429': () => errorBody(429, 'COMMON.TOO_MANY_REQUESTS'),
      '503': () => errorBody(503, 'PAYMENT.UNAVAILABLE'),
      '500 of a kind the table does not know': () =>
          errorBody(500, 'COMMON.INTERNAL'),
      'no network': () => throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    };
    for (final entry in keepsOpen.entries) {
      test('${entry.key} keeps the purchase open and grants nothing', () async {
        final h = Harness(onPurchase: (_) => entry.value());
        addTearDown(h.dispose);
        await h.start();

        h.store.deliver(purchase());
        await pumpEventQueue();

        expect(h.store.completed, isEmpty);
        expect(h.outcomes.whereType<IapGranted>(), isEmpty);
      });
    }

    // Refused for good: finished so the store stops handing it back.
    final refused = <String, ResponseBody Function()>{
      '404 not found': () => errorBody(404, 'PAYMENT.IAP_PURCHASE_NOT_FOUND'),
      '409 already subscribed': () =>
          errorBody(409, 'PAYMENT.ALREADY_SUBSCRIBED'),
      '422 product unknown': () =>
          errorBody(422, 'PAYMENT.IAP_PRODUCT_UNKNOWN'),
      '422 revoked': () => errorBody(422, 'PAYMENT.IAP_PURCHASE_REVOKED'),
      '422 not eligible': () =>
          errorBody(422, 'PAYMENT.IAP_PURCHASE_NOT_ELIGIBLE'),
    };
    for (final entry in refused.entries) {
      test('${entry.key} finishes the purchase without granting', () async {
        final h = Harness(onPurchase: (_) => entry.value());
        addTearDown(h.dispose);
        await h.start();

        h.store.deliver(purchase());
        await pumpEventQueue();

        expect(h.store.completed, hasLength(1));
        expect(h.outcomes.single, isA<IapRejected>());
      });
    }

    test('what failed for a while is sent again by retryUnfinished', () async {
      var calls = 0;
      final h = Harness(
        onPurchase: (_) =>
            ++calls == 1 ? errorBody(503, 'PAYMENT.UNAVAILABLE') : granted(),
      );
      addTearDown(h.dispose);
      await h.start();

      h.store.deliver(purchase());
      await pumpEventQueue();
      expect(h.store.completed, isEmpty);

      await h.service.retryUnfinished();
      await pumpEventQueue();

      expect(h.store.completed, hasLength(1));
      expect(h.outcomes.whereType<IapGranted>(), hasLength(1));
    });
  });

  group('the same purchase', () {
    test('is sent once and completed once, however often it arrives', () async {
      final answer = Completer<ResponseBody>();
      final h = Harness(onPurchase: (_) => answer.future);
      addTearDown(h.dispose);
      await h.start();

      h.store.deliver(purchase());
      h.store.deliver(purchase());
      await pumpEventQueue();
      answer.complete(granted());
      await pumpEventQueue();
      h.store.deliver(purchase());
      await pumpEventQueue();

      expect(h.purchaseCalls, hasLength(1));
      expect(h.store.completed, hasLength(1));
      expect(h.outcomes.whereType<IapGranted>(), hasLength(1));
    });
  });

  group('purchases from before this run', () {
    test('what the store hands over at start goes the same way', () async {
      final h = Harness();
      h.store.leftOver = [purchase(id: 'old-1')];
      addTearDown(h.dispose);

      await h.start();

      expect(h.purchaseCalls, hasLength(1));
      expect(h.store.completed.single.purchaseID, 'old-1');
    });

    test('a restored purchase is checked by the server too', () async {
      final answer = Completer<ResponseBody>();
      final h = Harness(onPurchase: (_) => answer.future);
      addTearDown(h.dispose);
      await h.start();

      h.store.deliver(purchase(status: PurchaseStatus.restored));
      await pumpEventQueue();

      expect(h.purchaseCalls, hasLength(1));
      expect(h.store.completed, isEmpty);
      answer.complete(granted());
      await pumpEventQueue();
      expect(h.outcomes.single, isA<IapGranted>());
    });
  });
}
