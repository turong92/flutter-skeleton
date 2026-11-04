import 'dart:async';

import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> orderJson(
  String id, {
  String status = 'PENDING',
  int amount = 3000,
  String orderName = 'Cheer 3,000',
}) => {
  'id': id,
  'status': status,
  'kind': 'ONE_TIME',
  'itemType': 'cheer',
  'itemRef': 'cheer-3000',
  'quantity': 1,
  'orderName': orderName,
  'amount': {'amount': amount, 'currency': 'KRW'},
  'refundedAmount': 0,
  'refundableAmount': 0,
  'refundPending': false,
  'openRefundStatus': null,
  'method': null,
  'card': null,
  'easyPayBrand': null,
  'testMode': true,
  'failureCode': null,
  'createdAt': '2026-01-01T00:00:00Z',
  'paidAt': null,
  'fulfilled': false,
  'originalAmount': null,
  'discountAmount': 0,
  'discounts': <Object?>[],
  'settlement': 'PROVIDER',
};

Map<String, Object?> checkoutJson(
  String orderId, {
  int amount = 3000,
  String kind = 'TOSS_PAYMENT_WINDOW',
  String? clientKey = 'test_ck_public_docs_key',
}) => {
  'provider': 'toss',
  'kind': kind,
  'clientKey': clientKey,
  'testMode': true,
  'orderId': orderId,
  'orderName': 'Cheer 3,000',
  'amount': {'amount': amount, 'currency': 'KRW'},
  'attributes': <String, String>{},
};

ResponseBody valueBody(Object? value, {int status = 200}) =>
    FakeAdapter.json(status, {'value': value, 'meta': meta});

ResponseBody cursorBody(List<Map<String, Object?>> values, {String? next}) =>
    FakeAdapter.json(200, {
      'values': values,
      'cursor': {'nextCursor': next, 'hasNext': next != null},
      'meta': meta,
    });

ResponseBody errorBody(int status, String code, {Object? data}) =>
    FakeAdapter.json(status, {
      'code': code,
      'title': 'x',
      'status': status,
      'data': ?data,
    });

ApiClient clientWith(FakeAdapter adapter) =>
    ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter);

/// A scripted payment server. [respond] wins over the defaults when it
/// returns something.
class FakePayment {
  bool available = true;
  bool testMode = true;
  int orderAmount = 3000;
  String orderId = 'ord_1';
  String? checkoutKind;
  bool noCheckout = false;

  /// Answer of `POST .../confirm`.
  ResponseBody Function(RequestOptions options)? onConfirm;

  /// Statuses answered by `GET .../orders/{id}`, one per call (the last one
  /// repeats).
  List<String> pollStatuses = ['PAID'];
  int polls = 0;
  List<List<Map<String, Object?>>> orderPages = [];
  ResponseBody? Function(RequestOptions options)? respond;

  late final FakeAdapter adapter = FakeAdapter((o) async => _handle(o));

  List<RequestOptions> where(String method, String path) => [
    for (final r in adapter.requests)
      if (r.method == method && r.path == path) r,
  ];

  ResponseBody _handle(RequestOptions o) {
    final custom = respond?.call(o);
    if (custom != null) return custom;
    final path = o.path;
    switch (o.method) {
      case 'GET' when path == '/payments/config':
        return valueBody({'available': available, 'testMode': testMode});
      case 'POST' when path == '/payments/orders':
        return valueBody({
          'order': orderJson(orderId, amount: orderAmount),
          'checkout': noCheckout
              ? null
              : checkoutJson(
                  orderId,
                  amount: orderAmount,
                  kind: checkoutKind ?? 'TOSS_PAYMENT_WINDOW',
                ),
        }, status: 201);
      case 'POST' when path == '/payments/orders/$orderId/confirm':
        return onConfirm?.call(o) ??
            valueBody(orderJson(orderId, status: 'PAID'));
      case 'GET' when path == '/payments/orders/$orderId':
        final status = pollStatuses[polls < pollStatuses.length
            ? polls
            : pollStatuses.length - 1];
        polls++;
        return valueBody({
          'order': orderJson(orderId, status: status, amount: orderAmount),
          'refunds': <Object?>[],
        });
      case 'GET' when path == '/payments/orders':
        final cursor = o.queryParameters['cursor'] as String?;
        final index = cursor == null ? 0 : int.parse(cursor);
        return cursorBody(
          orderPages[index],
          next: index + 1 < orderPages.length ? '${index + 1}' : null,
        );
    }
    return errorBody(404, 'COMMON.NOT_FOUND');
  }

  PaymentApi get api => PaymentApi(clientWith(adapter));
}

/// A launcher that answers [result] without showing anything.
class FakeLauncher {
  FakeLauncher(this.result);

  CheckoutReturn? result;
  final List<Checkout> opened = [];

  Future<CheckoutReturn?> call(Checkout checkout) async {
    opened.add(checkout);
    return result;
  }
}
