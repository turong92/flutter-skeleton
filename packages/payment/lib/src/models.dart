/// An amount in the smallest unit of [currency] (`3000` `KRW`).
class Money {
  const Money({required this.amount, required this.currency});

  factory Money.fromJson(Map<String, Object?> json) => Money(
    amount: (json['amount']! as num).toInt(),
    currency: json['currency']! as String,
  );

  final int amount;
  final String currency;
}

/// `GET /payments/config`: whether an order can be paid at all, and whether the
/// provider keys are test keys.
class PaymentConfig {
  const PaymentConfig({required this.available, required this.testMode});

  factory PaymentConfig.fromJson(Map<String, Object?> json) => PaymentConfig(
    available: json['available']! as bool,
    testMode: json['testMode']! as bool,
  );

  final bool available;
  final bool testMode;
}

/// An order of the buyer. [status] is the server's name (`PENDING`,
/// `CONFIRMING`, `PAID`, `PARTIALLY_REFUNDED`, `REFUNDED`, `FAILED`, `EXPIRED`,
/// `CANCELED`); new names pass through.
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.status,
    required this.itemType,
    required this.itemRef,
    required this.quantity,
    required this.orderName,
    required this.amount,
    required this.testMode,
    required this.createdAt,
    this.failureCode,
    this.paidAt,
  });

  factory PaymentOrder.fromJson(Map<String, Object?> json) => PaymentOrder(
    id: json['id']! as String,
    status: json['status']! as String,
    itemType: json['itemType']! as String,
    itemRef: json['itemRef']! as String,
    quantity: json['quantity']! as int,
    orderName: json['orderName']! as String,
    amount: Money.fromJson(json['amount']! as Map<String, Object?>),
    testMode: json['testMode']! as bool,
    failureCode: json['failureCode'] as String?,
    createdAt: DateTime.parse(json['createdAt']! as String),
    paidAt: switch (json['paidAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  final String id;
  final String status;
  final String itemType;
  final String itemRef;
  final int quantity;
  final String orderName;
  final Money amount;
  final bool testMode;
  final String? failureCode;
  final DateTime createdAt;
  final DateTime? paidAt;

  /// Money came in at some point (a refund does not undo that).
  bool get isPaid =>
      status == 'PAID' ||
      status == 'PARTIALLY_REFUNDED' ||
      status == 'REFUNDED';

  bool get isConfirming => status == 'CONFIRMING';
}

/// What the checkout window needs, as the server handed it out.
class Checkout {
  const Checkout({
    required this.provider,
    required this.kind,
    required this.clientKey,
    required this.testMode,
    required this.orderId,
    required this.orderName,
    required this.amount,
  });

  factory Checkout.fromJson(Map<String, Object?> json) => Checkout(
    provider: json['provider']! as String,
    kind: json['kind']! as String,
    clientKey: json['clientKey'] as String?,
    testMode: json['testMode']! as bool,
    orderId: json['orderId']! as String,
    orderName: json['orderName']! as String,
    amount: Money.fromJson(json['amount']! as Map<String, Object?>),
  );

  final String provider;

  /// How the window opens (`TOSS_PAYMENT_WINDOW`). See [tossPaymentWindowKind].
  final String kind;
  final String? clientKey;
  final bool testMode;
  final String orderId;
  final String orderName;
  final Money amount;
}

/// `POST /payments/orders`: the order, and the checkout while it can still be
/// paid (null once it is no longer `PENDING`).
class CreatedOrder {
  const CreatedOrder({required this.order, this.checkout});

  factory CreatedOrder.fromJson(Map<String, Object?> json) => CreatedOrder(
    order: PaymentOrder.fromJson(json['order']! as Map<String, Object?>),
    checkout: switch (json['checkout']) {
      final Map<String, Object?> c => Checkout.fromJson(c),
      _ => null,
    },
  );

  final PaymentOrder order;
  final Checkout? checkout;
}

/// A page of the cursor envelope.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasNext => nextCursor != null;
}

/// The `checkout.kind` the Toss payment window answers to.
const tossPaymentWindowKind = 'TOSS_PAYMENT_WINDOW';
