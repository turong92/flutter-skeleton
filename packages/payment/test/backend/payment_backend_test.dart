@Tags(['backend'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

// Runs the payment calls against a real kotlin-skeleton `apps/sample` (local
// profile, seed account, Toss TEST keys from Toss's public docs):
// config, an order for the sample `cheer-3000` item, the same key sent twice
// (one order), an item the server does not sell, and the history. No payment
// window opens, so no confirm: that needs a buyer in the window.
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend/payment_backend_test.dart
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL, API_SEED_EMAIL and API_SEED_PASSWORD to run against a backend'
      : null;

  Future<ApiClient> signedIn() async {
    final login = await Dio(BaseOptions(baseUrl: _baseUrl!))
        .post<Map<String, Object?>>(
          '/auth/login',
          data: {
            'email': _env['API_SEED_EMAIL'] ?? 'user@example.com',
            'password': _env['API_SEED_PASSWORD'] ?? 'password',
          },
        );
    final token = (login.data!['value']! as Map)['accessToken']! as String;
    return ApiClient(
      baseUrl: _baseUrl!,
      headerProviders: [
        () => {'Authorization': 'Bearer $token'},
      ],
    );
  }

  test('config says payments are open in test mode', () async {
    final api = PaymentApi(await signedIn());

    final config = await api.config();

    expect(config.available, isTrue);
    expect(config.testMode, isTrue);
  }, skip: skip);

  test('an order for cheer-3000 comes with a Toss window, and a resend is the same order', () async {
    final api = PaymentApi(await signedIn());
    final key = newIdempotencyKey();

    final first = await api.createOrder(
      itemType: 'cheer',
      itemRef: 'cheer-3000',
      idempotencyKey: key,
    );
    final again = await api.createOrder(
      itemType: 'cheer',
      itemRef: 'cheer-3000',
      idempotencyKey: key,
    );

    expect(first.order.status, 'PENDING');
    expect(first.order.amount.amount, 3000);
    expect(first.order.amount.currency, 'KRW');
    expect(first.checkout?.kind, tossPaymentWindowKind);
    expect(first.checkout?.clientKey, startsWith('test_ck_'));
    expect(first.checkout?.orderId, first.order.id);
    expect(again.order.id, first.order.id);

    final read = await api.order(first.order.id);
    expect(read.id, first.order.id);
  }, skip: skip);

  test('an item the server does not sell is refused', () async {
    final api = PaymentApi(await signedIn());

    await expectLater(
      api.createOrder(
        itemType: 'cheer',
        itemRef: 'cheer-1',
        idempotencyKey: newIdempotencyKey(),
      ),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          'PAYMENT.ITEM_NOT_PURCHASABLE',
        ),
      ),
    );
  }, skip: skip);

  test(
    'the history reads, and an attempt that was never paid is not in it',
    () async {
      final api = PaymentApi(await signedIn());
      final created = await api.createOrder(
        itemType: 'cheer',
        itemRef: 'cheer-3000',
        idempotencyKey: newIdempotencyKey(),
      );

      final page = await api.myOrders(size: 5);

      expect(page.items.map((o) => o.id), isNot(contains(created.order.id)));
    },
    skip: skip,
  );
}
