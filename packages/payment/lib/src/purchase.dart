import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'checkout_navigation.dart';
import 'models.dart';
import 'payment_api.dart';

/// Opens the payment window for [checkout] and answers what came back through
/// its return address; null when the buyer closed the window.
typedef CheckoutLauncher = Future<CheckoutReturn?> Function(Checkout checkout);

/// How a purchase ended.
sealed class PurchaseResult {
  const PurchaseResult();
}

/// Paid.
class PurchasePaid extends PurchaseResult {
  const PurchasePaid(this.order);

  final PaymentOrder order;
}

/// The server has not settled yet, or the answer never arrived: the money may
/// or may not have moved. Tell the buyer to look in the order history.
class PurchaseConfirming extends PurchaseResult {
  const PurchaseConfirming(this.order);

  final PaymentOrder order;
}

/// The provider turned the payment down. [category] is the server's grouping
/// (`LIMIT_OR_BALANCE`, `CARD_DECLINED`, `TEMPORARY`, `OTHER`); choose the
/// words by it. [providerCode] is for support, not for the buyer.
class PurchaseDeclined extends PurchaseResult {
  const PurchaseDeclined({this.category, this.providerCode});

  final String? category;
  final String? providerCode;
}

/// The buyer closed the window or cancelled in it. The order stays `PENDING`
/// and the server closes it.
class PurchaseCanceled extends PurchaseResult {
  const PurchaseCanceled();
}

/// Anything else that stopped the purchase. [code] is the server's error code
/// or one of `RETURN_MISMATCH`, `CHECKOUT_UNAVAILABLE`, `INVALID_RETURN` or the
/// provider's own code from the window.
class PurchaseFailed extends PurchaseResult {
  const PurchaseFailed(this.code);

  final String code;
}

/// The server cannot take payments now (`503 PAYMENT.UNAVAILABLE`).
class PurchaseUnavailable extends PurchaseResult {
  const PurchaseUnavailable();
}

/// The server wants a window this package does not open ([kind]).
class PurchaseUnsupported extends PurchaseResult {
  const PurchaseUnsupported(this.kind);

  final String kind;
}

/// Waits before each re-read of a `CONFIRMING` order; the length is the limit
/// on how often it asks.
const defaultPollSchedule = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
];

/// One purchase: order, payment window, confirm, and asking again while the
/// server says `CONFIRMING`.
///
/// - [idempotencyKey] is one per purchase (a new one when null). Pass the same
///   key to retry the same attempt after a failed network call: the server then
///   answers with the same order.
/// - The amount sent to confirm is the server order's, never the returned
///   address's. An address whose order id or amount differs from the order is
///   not confirmed.
/// - Which window opens is decided by `checkout.kind`, here and nowhere else.
/// - [wait] is a parameter so tests need no real time.
Future<PurchaseResult> purchase({
  required PaymentApi api,
  required String itemType,
  required String itemRef,
  required CheckoutLauncher launch,
  int quantity = 1,
  String? idempotencyKey,
  List<Duration> pollSchedule = defaultPollSchedule,
  Future<void> Function(Duration) wait = _wait,
}) async {
  final CreatedOrder created;
  try {
    created = await api.createOrder(
      itemType: itemType,
      itemRef: itemRef,
      quantity: quantity,
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    );
  } on ApiRequestError catch (e) {
    return e.code == 'PAYMENT.UNAVAILABLE'
        ? const PurchaseUnavailable()
        : PurchaseFailed(e.code);
  }
  final order = created.order;
  final checkout = created.checkout;
  if (checkout == null) {
    return order.isPaid
        ? PurchasePaid(order)
        : const PurchaseFailed('CHECKOUT_UNAVAILABLE');
  }
  if (checkout.kind != tossPaymentWindowKind) {
    return PurchaseUnsupported(checkout.kind);
  }

  final returned = await launch(checkout);
  switch (returned) {
    case null:
      return const PurchaseCanceled();
    case CheckoutFailed(:final code):
      return code == 'PAY_PROCESS_CANCELED'
          ? const PurchaseCanceled()
          : PurchaseFailed(code);
    case CheckoutSucceeded():
      if (returned.orderId != order.id ||
          returned.amount != order.amount.amount) {
        return const PurchaseFailed('RETURN_MISMATCH');
      }
      return _confirm(
        api,
        order,
        returned.paymentKey,
        pollSchedule: pollSchedule,
        wait: wait,
      );
  }
}

Future<PurchaseResult> _confirm(
  PaymentApi api,
  PaymentOrder order,
  String paymentKey, {
  required List<Duration> pollSchedule,
  required Future<void> Function(Duration) wait,
}) async {
  final PaymentOrder confirmed;
  try {
    confirmed = await api.confirm(
      order.id,
      paymentKey: paymentKey,
      amount: order.amount.amount,
    );
  } on ApiRequestError catch (e) {
    if (e.code == 'PAYMENT.DECLINED') {
      final data = e.apiError.data;
      return PurchaseDeclined(
        category: data is Map ? data['category'] as String? : null,
        providerCode: data is Map ? data['providerCode'] as String? : null,
      );
    }
    // 4xx other than the ones that say "ask again later": the server did not
    // take the request. Everything else may have got through.
    final status = e.status;
    final refused =
        status >= 400 && status < 500 && !_notAVerdict.contains(status);
    return refused ? PurchaseFailed(e.code) : PurchaseConfirming(order);
  }
  if (confirmed.isPaid) return PurchasePaid(confirmed);
  if (!confirmed.isConfirming) {
    return PurchaseFailed(confirmed.failureCode ?? confirmed.status);
  }
  return _poll(api, confirmed, pollSchedule, wait);
}

const _notAVerdict = {401, 402, 403, 408, 425, 429};

Future<PurchaseResult> _poll(
  PaymentApi api,
  PaymentOrder confirming,
  List<Duration> schedule,
  Future<void> Function(Duration) wait,
) async {
  var latest = confirming;
  for (final delay in schedule) {
    await wait(delay);
    try {
      latest = await api.order(confirming.id);
    } on ApiRequestError {
      continue; // a failed read is one used-up try, not an answer
    }
    if (latest.isPaid) return PurchasePaid(latest);
    if (!latest.isConfirming) {
      return PurchaseFailed(latest.failureCode ?? latest.status);
    }
  }
  return PurchaseConfirming(latest);
}

Future<void> _wait(Duration d) => Future<void>.delayed(d);
