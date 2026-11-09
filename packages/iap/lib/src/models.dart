import 'package:in_app_purchase/in_app_purchase.dart';

/// Where the server lets this app sell (`channel` of `GET /iap/config`).
enum IapChannel {
  iapOnly('IAP_ONLY'),
  iapAndWeb('IAP_AND_WEB'),
  webOnly('WEB_ONLY');

  const IapChannel(this.wire);
  final String wire;

  /// A value this app does not know is read as the safe one: no web checkout.
  static IapChannel parse(String? value) => values.firstWhere(
    (c) => c.wire == value,
    orElse: () => IapChannel.iapOnly,
  );

  bool get showsWebCheckout => this != iapOnly;
}

enum IapProductKind { oneTime, subscription }

/// One row of the server's product map for this platform.
class IapProduct {
  const IapProduct({
    required this.kind,
    required this.storeProductId,
    this.itemType,
    this.itemRef,
    this.plan,
    this.basePlanId,
    this.consumable = true,
  });

  factory IapProduct.fromJson(Map<String, Object?> json) => IapProduct(
    kind: json['kind'] == 'SUBSCRIPTION'
        ? IapProductKind.subscription
        : IapProductKind.oneTime,
    storeProductId: json['storeProductId']! as String,
    itemType: json['itemType'] as String?,
    itemRef: json['itemRef'] as String?,
    plan: json['plan'] as String?,
    basePlanId: json['basePlanId'] as String?,
    consumable: json['consumable'] != false,
  );

  final IapProductKind kind;
  final String storeProductId;
  final String? itemType;
  final String? itemRef;

  /// The plan code of a subscription.
  final String? plan;

  /// Google subscriptions only.
  final String? basePlanId;

  /// A one-time product the person can buy again (`true`, the default and the
  /// answer of a server that has no such column) or one that is bought once
  /// and kept, like "remove ads" (`false`: never consumed in the store, so it
  /// can be restored and cannot be bought twice).
  final bool consumable;
}

/// `GET /iap/config`.
class IapConfig {
  const IapConfig({
    required this.channel,
    required this.appAccountToken,
    required this.products,
    this.store,
  });

  factory IapConfig.fromJson(Map<String, Object?> json) => IapConfig(
    channel: IapChannel.parse(json['channel'] as String?),
    store: json['store'] as String?,
    appAccountToken: json['appAccountToken']! as String,
    products: [
      for (final p in json['products']! as List)
        IapProduct.fromJson(p as Map<String, Object?>),
    ],
  );

  final IapChannel channel;

  /// `appstore` / `googleplay`; null when the server has no store for this
  /// platform.
  final String? store;

  /// Made by the server for this account. The app puts it into a purchase as
  /// it is and never makes one.
  final String appAccountToken;
  final List<IapProduct> products;

  bool get showsWebCheckout => channel.showsWebCheckout;
}

/// A product the store knows, ready to buy.
class IapOffer {
  const IapOffer({
    required this.product,
    required this.details,
    required this.accountToken,
  });

  final IapProduct product;
  final ProductDetails details;
  final String accountToken;
}

class IapCatalog {
  const IapCatalog({required this.config, required this.offers});

  final IapConfig config;

  /// The server's products that the store also lists.
  final List<IapOffer> offers;
}

/// The subscription row of `GET /subscriptions/me` (the part this package
/// reads).
class IapSubscription {
  const IapSubscription({
    required this.id,
    required this.status,
    required this.planCode,
    this.planName,
    this.provider,
    this.currentPeriodEnd,
  });

  factory IapSubscription.fromJson(Map<String, Object?> json) =>
      IapSubscription(
        id: json['id']! as String,
        status: json['status']! as String,
        planCode: json['planCode']! as String,
        planName: json['planName'] as String?,
        provider: json['provider'] as String?,
        currentPeriodEnd: DateTime.tryParse(
          json['currentPeriodEnd'] as String? ?? '',
        ),
      );

  final String id;

  /// `PENDING` / `ACTIVE` / `PAST_DUE` / `CANCELING` / `ENDED`.
  final String status;
  final String planCode;
  final String? planName;

  /// `toss` / `paddle` / `appstore` / `googleplay`.
  final String? provider;
  final DateTime? currentPeriodEnd;

  /// A store bills this one and only the store can end it.
  bool get isFromStore => provider == 'appstore' || provider == 'googleplay';

  /// The plan [plan] is running and paid for now: `ACTIVE` or `CANCELING`
  /// (cancelled but paid to the end of the period), the period not over.
  /// `PAST_DUE`, `PENDING` and `ENDED` are not.
  bool keepsOn(String plan, DateTime now) =>
      planCode == plan &&
      (status == 'ACTIVE' || status == 'CANCELING') &&
      (currentPeriodEnd?.isAfter(now) ?? false);

  /// Still billed or running: `ACTIVE`, `CANCELING`, `PAST_DUE`.
  bool get isInUse =>
      status == 'ACTIVE' || status == 'CANCELING' || status == 'PAST_DUE';
}

/// What the server said to a purchase it was asked to check.
sealed class IapOutcome {
  const IapOutcome(this.productId);

  /// The store's product id.
  final String productId;
}

/// The server checked the purchase and granted it. Read the entitlement from
/// the server; this is only the signal to do so.
class IapGranted extends IapOutcome {
  const IapGranted(super.productId, {this.orderId, this.subscription});

  final String? orderId;
  final IapSubscription? subscription;
}

/// The server refused this purchase for good; nothing is granted.
class IapRejected extends IapOutcome {
  const IapRejected(super.productId, this.code);

  /// The server's `ApiError.code`.
  final String code;
}

enum IapWait {
  /// The store has not finished the payment (Ask to Buy, a pending payment).
  storePending,

  /// The purchase belongs to another account; sign in with that one.
  otherAccount,

  /// The server could not be reached or said "later"; use
  /// `IapService.retryUnfinished`.
  retryLater,
}

/// Nothing granted yet; the purchase stays open in the store.
class IapNotConfirmed extends IapOutcome {
  const IapNotConfirmed(super.productId, this.reason);

  final IapWait reason;
}

/// The store itself reported a failure or a cancel.
class IapStoreError extends IapOutcome {
  const IapStoreError(super.productId, this.message);

  final String message;
}

/// `GET /iap/entitlements`: the once-bought items the account owns.
class IapEntitlements {
  const IapEntitlements(this._items);

  static const none = IapEntitlements({});

  factory IapEntitlements.fromJson(Map<String, Object?> json) =>
      IapEntitlements({
        for (final v in json['values']! as List)
          '${(v as Map)['itemType']}|${v['itemRef']}',
      });

  final Set<String> _items;

  bool owns(String itemType, String itemRef) =>
      _items.contains('$itemType|$itemRef');
}
