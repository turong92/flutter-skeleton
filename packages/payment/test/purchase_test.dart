import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

import 'support/fake_payment.dart';

CheckoutSucceeded back({
  String paymentKey = 'pk_1',
  String orderId = 'ord_1',
  int amount = 3000,
}) =>
    CheckoutSucceeded(paymentKey: paymentKey, orderId: orderId, amount: amount);

void main() {
  late FakePayment server;
  late FakeLauncher launcher;
  late List<Duration> waits;

  setUp(() {
    server = FakePayment();
    launcher = FakeLauncher(back());
    waits = [];
  });

  Future<PurchaseResult> run({String? key}) => purchase(
    api: server.api,
    itemType: 'cheer',
    itemRef: 'cheer-3000',
    launch: launcher.call,
    idempotencyKey: key,
    wait: (d) async => waits.add(d),
  );

  test(
    'order, window, confirm: paid, with the amount of the server order',
    () async {
      server.orderAmount = 3000;

      final result = await run();

      expect(result, isA<PurchasePaid>());
      final create = server.where('POST', '/payments/orders').single;
      expect(create.data, {
        'itemType': 'cheer',
        'itemRef': 'cheer-3000',
        'quantity': 1,
      });
      final confirm = server
          .where('POST', '/payments/orders/ord_1/confirm')
          .single;
      expect(confirm.data, {'providerPaymentId': 'pk_1', 'amount': 3000});
      expect(launcher.opened.single.clientKey, 'test_ck_public_docs_key');
    },
  );

  test('one purchase uses one Idempotency-Key, a given key is kept', () async {
    await run(key: 'attempt-key-0001');

    final create = server.where('POST', '/payments/orders').single;
    expect(create.headers['Idempotency-Key'], 'attempt-key-0001');
  });

  test('every purchase without a key takes a new one', () async {
    await run();
    await run();

    final keys = [
      for (final r in server.where('POST', '/payments/orders'))
        r.headers['Idempotency-Key'],
    ];
    expect(keys[0], isNotNull);
    expect(keys[0], isNot(keys[1]));
  });

  test(
    'a returned amount that differs from the order is not confirmed',
    () async {
      launcher.result = back(amount: 1);

      final result = await run();

      expect(
        result,
        isA<PurchaseFailed>().having((r) => r.code, 'code', 'RETURN_MISMATCH'),
      );
      expect(server.where('POST', '/payments/orders/ord_1/confirm'), isEmpty);
    },
  );

  test(
    'a returned order id that differs from the order is not confirmed',
    () async {
      launcher.result = back(orderId: 'ord_other');

      final result = await run();

      expect(
        result,
        isA<PurchaseFailed>().having((r) => r.code, 'code', 'RETURN_MISMATCH'),
      );
      expect(server.where('POST', '/payments/orders/ord_1/confirm'), isEmpty);
    },
  );

  test('closing the window is a cancel and nothing is confirmed', () async {
    launcher.result = null;

    final result = await run();

    expect(result, isA<PurchaseCanceled>());
    expect(server.where('POST', '/payments/orders/ord_1/confirm'), isEmpty);
  });

  test('the buyer cancelling inside the window is a cancel', () async {
    launcher.result = const CheckoutFailed(
      code: 'PAY_PROCESS_CANCELED',
      orderId: 'ord_1',
    );

    expect(await run(), isA<PurchaseCanceled>());
  });

  test('another failure of the window carries its code', () async {
    launcher.result = const CheckoutFailed(
      code: 'INVALID_CARD_COMPANY',
      orderId: 'ord_1',
    );

    expect(
      await run(),
      isA<PurchaseFailed>().having(
        (r) => r.code,
        'code',
        'INVALID_CARD_COMPANY',
      ),
    );
  });

  test(
    'a kind other than the Toss window is not supported and no window opens',
    () async {
      server.checkoutKind = 'PADDLE_OVERLAY';

      final result = await run();

      expect(
        result,
        isA<PurchaseUnsupported>().having(
          (r) => r.kind,
          'kind',
          'PADDLE_OVERLAY',
        ),
      );
      expect(launcher.opened, isEmpty);
    },
  );

  test('a server that cannot open a window is unavailable', () async {
    server.respond = (o) => o.path == '/payments/orders'
        ? errorBody(503, 'PAYMENT.UNAVAILABLE')
        : null;

    expect(await run(), isA<PurchaseUnavailable>());
  });

  test('an order that is already paid needs no window', () async {
    server.noCheckout = true;
    server.respond = (o) => o.path == '/payments/orders'
        ? valueBody({
            'order': orderJson('ord_1', status: 'PAID'),
            'checkout': null,
          }, status: 200)
        : null;

    expect(await run(), isA<PurchasePaid>());
    expect(launcher.opened, isEmpty);
  });

  test('an order that is no longer payable and has no window fails', () async {
    server.noCheckout = true;

    expect(
      await run(),
      isA<PurchaseFailed>().having(
        (r) => r.code,
        'code',
        'CHECKOUT_UNAVAILABLE',
      ),
    );
  });

  group('202 CONFIRMING', () {
    setUp(() {
      server.onConfirm = (o) =>
          valueBody(orderJson('ord_1', status: 'CONFIRMING'), status: 202);
    });

    test('asks again with growing waits until the order is paid', () async {
      server.pollStatuses = ['CONFIRMING', 'CONFIRMING', 'PAID'];

      final result = await run();

      expect(result, isA<PurchasePaid>());
      expect(server.polls, 3);
      expect(waits, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('stops at the limit and says it is still being checked', () async {
      server.pollStatuses = ['CONFIRMING'];

      final result = await run();

      expect(result, isA<PurchaseConfirming>());
      expect(server.polls, defaultPollSchedule.length);
      expect(waits, defaultPollSchedule);
      // the waits only grow
      for (var i = 1; i < waits.length; i++) {
        expect(waits[i] > waits[i - 1], isTrue);
      }
    });

    test('an order the server closed as failed ends the asking', () async {
      server.pollStatuses = ['CONFIRMING', 'FAILED'];

      final result = await run();

      expect(result, isA<PurchaseFailed>());
      expect(server.polls, 2);
    });
  });

  test('402 DECLINED hands over the category', () async {
    server.onConfirm = (o) => errorBody(
      402,
      'PAYMENT.DECLINED',
      data: {
        'category': 'LIMIT_OR_BALANCE',
        'providerCode': 'REJECT_CARD_PAYMENT',
      },
    );

    final result = await run();

    expect(
      result,
      isA<PurchaseDeclined>()
          .having((r) => r.category, 'category', 'LIMIT_OR_BALANCE')
          .having((r) => r.providerCode, 'providerCode', 'REJECT_CARD_PAYMENT'),
    );
  });

  test(
    'a confirm that got no answer is still being checked, not failed',
    () async {
      server.onConfirm = (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionTimeout,
      );

      expect(await run(), isA<PurchaseConfirming>());
    },
  );

  test('a confirm the server refused is a failure with its code', () async {
    server.onConfirm = (o) => errorBody(400, 'PAYMENT.AMOUNT_MISMATCH');

    expect(
      await run(),
      isA<PurchaseFailed>().having(
        (r) => r.code,
        'code',
        'PAYMENT.AMOUNT_MISMATCH',
      ),
    );
  });
}
