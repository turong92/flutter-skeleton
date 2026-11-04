import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'support/fake_payment.dart';

void main() {
  test('config reads available and testMode', () async {
    final server = FakePayment()
      ..available = false
      ..testMode = true;

    final config = await server.api.config();

    expect(config.available, isFalse);
    expect(config.testMode, isTrue);
  });

  test(
    'createOrder sends the item and the key, reads order and checkout',
    () async {
      final server = FakePayment();

      final created = await server.api.createOrder(
        itemType: 'cheer',
        itemRef: 'cheer-3000',
        quantity: 2,
        idempotencyKey: 'key-key-key-key-1',
      );

      final request = server.where('POST', '/payments/orders').single;
      expect(request.data, {
        'itemType': 'cheer',
        'itemRef': 'cheer-3000',
        'quantity': 2,
      });
      expect(request.headers['Idempotency-Key'], 'key-key-key-key-1');
      expect(created.order.id, 'ord_1');
      expect(created.order.amount.amount, 3000);
      expect(created.order.amount.currency, 'KRW');
      expect(created.checkout?.kind, 'TOSS_PAYMENT_WINDOW');
      expect(created.checkout?.clientKey, 'test_ck_public_docs_key');
    },
  );

  test('order reads the order out of the detail', () async {
    final server = FakePayment()..pollStatuses = ['PAID'];

    final order = await server.api.order('ord_1');

    expect(order.status, 'PAID');
    expect(order.isPaid, isTrue);
  });

  test('myOrders follows the cursor', () async {
    final server = FakePayment()
      ..orderPages = [
        [orderJson('a', status: 'PAID'), orderJson('b', status: 'PAID')],
        [orderJson('c', status: 'REFUNDED')],
      ];

    final first = await server.api.myOrders();
    final second = await server.api.myOrders(cursor: first.nextCursor);

    expect(first.items.map((o) => o.id), ['a', 'b']);
    expect(first.hasNext, isTrue);
    expect(second.items.map((o) => o.id), ['c']);
    expect(second.hasNext, isFalse);
    expect(second.items.single.isPaid, isTrue);
  });

  test('a failed call throws the standard error', () async {
    final server = FakePayment()
      ..respond = (o) => errorBody(403, 'LEGAL.RECONSENT_REQUIRED');

    await expectLater(
      server.api.myOrders(),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          'LEGAL.RECONSENT_REQUIRED',
        ),
      ),
    );
  });
}
