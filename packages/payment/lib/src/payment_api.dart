import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend calls of the `payment` modules. Stores nothing.
///
/// `createOrder` needs a key per purchase (`newIdempotencyKey()`): the server
/// refuses it without one and answers a resend of the same key with the same
/// order.
class PaymentApi {
  PaymentApi(this._client);

  final ApiClient _client;

  /// `GET /payments/config`.
  Future<PaymentConfig> config() =>
      _client.value('/payments/config', decode: PaymentConfig.fromJson);

  /// `POST /payments/orders`. The amount is the server's: the order is made
  /// from `(itemType, itemRef, quantity)` only.
  Future<CreatedOrder> createOrder({
    required String itemType,
    required String itemRef,
    required String idempotencyKey,
    int quantity = 1,
  }) => _client.value(
    '/payments/orders',
    method: 'POST',
    json: {'itemType': itemType, 'itemRef': itemRef, 'quantity': quantity},
    headers: {'Idempotency-Key': idempotencyKey},
    decode: CreatedOrder.fromJson,
  );

  /// `POST /payments/orders/{id}/confirm`. 200 and 202 both answer the order;
  /// read its status (`PAID` or `CONFIRMING`). [amount] must be the amount of
  /// the server's order, never the one in the returned address.
  Future<PaymentOrder> confirm(
    String orderId, {
    required String paymentKey,
    required int amount,
  }) => _client.value(
    '/payments/orders/$orderId/confirm',
    method: 'POST',
    json: {'providerPaymentId': paymentKey, 'amount': amount},
    decode: PaymentOrder.fromJson,
  );

  /// `GET /payments/orders/{id}`.
  Future<PaymentOrder> order(String orderId) => _client.value(
    '/payments/orders/$orderId',
    decode: (json) =>
        PaymentOrder.fromJson(json['order']! as Map<String, Object?>),
  );

  /// `GET /payments/orders`: mine, newest first, never-paid attempts left out.
  /// Pass the previous page's [CursorPage.nextCursor] for the next page.
  Future<CursorPage<PaymentOrder>> myOrders({String? cursor, int? size}) async {
    try {
      final response = await _client.dio.get<Object?>(
        '/payments/orders',
        queryParameters: {'cursor': ?cursor, 'size': ?size},
      );
      final body = response.data;
      final values = body is Map ? body['values'] : null;
      if (values is! List) {
        throw ApiRequestError.http(
          response.statusCode ?? 0,
          detail: 'missing "values" in the response',
        );
      }
      final cursorMeta = body is Map ? body['cursor'] : null;
      return CursorPage(
        items: [
          for (final v in values)
            PaymentOrder.fromJson(v as Map<String, Object?>),
        ],
        nextCursor: cursorMeta is Map ? cursorMeta['nextCursor'] as String? : null,
      );
    } on DioException catch (e, stackTrace) {
      final error = ApiRequestError.fromDioException(e);
      _client.onError?.call(error);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
