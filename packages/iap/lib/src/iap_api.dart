import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// `ApiError.code` of the payment modules that this package branches on
/// (kotlin `payment-iap`).
abstract final class IapErrorCodes {
  /// 404: the store does not know this purchase.
  static const notFound = 'PAYMENT.IAP_PURCHASE_NOT_FOUND';

  /// 409: a purchase of another account. Do not finish it.
  static const ownedElsewhere = 'PAYMENT.IAP_PURCHASE_OWNED_ELSEWHERE';

  /// 409: another subscription is alive.
  static const alreadySubscribed = 'PAYMENT.ALREADY_SUBSCRIBED';

  /// 422: no grant, finish it.
  static const productUnknown = 'PAYMENT.IAP_PRODUCT_UNKNOWN';
  static const revoked = 'PAYMENT.IAP_PURCHASE_REVOKED';
  static const notEligible = 'PAYMENT.IAP_PURCHASE_NOT_ELIGIBLE';
}

/// The answer to a purchase check: `200 GRANTED` or `202 PENDING`.
class IapPurchaseResult {
  const IapPurchaseResult({
    required this.granted,
    this.kind,
    this.orderId,
    this.subscription,
  });

  factory IapPurchaseResult.fromJson(Map<String, Object?> json) {
    final subscription = json['subscription'];
    return IapPurchaseResult(
      granted: json['result'] == 'GRANTED',
      kind: switch (json['kind']) {
        'ONE_TIME' => IapProductKind.oneTime,
        'SUBSCRIPTION' => IapProductKind.subscription,
        _ => null,
      },
      orderId: json['orderId'] as String?,
      subscription: subscription is Map<String, Object?>
          ? IapSubscription.fromJson(subscription)
          : null,
    );
  }

  final bool granted;

  /// What the server says was bought; null when the answer has no `kind`.
  final IapProductKind? kind;
  final String? orderId;
  final IapSubscription? subscription;
}

/// The backend calls of the payment-iap module and the subscription lookup.
/// Stores nothing.
class IapApi {
  IapApi(this._client);

  final ApiClient _client;

  /// `GET /payments/iap/config`.
  Future<IapConfig> config({required String platform, String? storefront}) =>
      _client.value(
        '/payments/iap/config',
        query: {'platform': platform, 'storefront': ?storefront},
        decode: IapConfig.fromJson,
      );

  /// `POST /payments/iap/{store}/purchases`. [body] is `{transactionId}`
  /// (appstore) or `{productId, purchaseToken}` (googleplay).
  Future<IapPurchaseResult> confirmPurchase(
    String store,
    Map<String, Object?> body,
  ) => _client.value(
    '/payments/iap/$store/purchases',
    method: 'POST',
    json: body,
    decode: IapPurchaseResult.fromJson,
  );

  /// `GET /payments/iap/entitlements`: the once-bought items (products with
  /// `consumable: false`) this account has paid for and not had refunded.
  Future<IapEntitlements> entitlements() => _client.value(
    '/payments/iap/entitlements',
    decode: IapEntitlements.fromJson,
  );

  /// `POST /payments/iap/web-checkout-link`: a one-time address with a sign-in
  /// code in it. A secret: open it, never log or store it.
  Future<String> webCheckoutLink({
    required String platform,
    String? storefront,
  }) => _client.value(
    '/payments/iap/web-checkout-link',
    method: 'POST',
    query: {'platform': platform, 'storefront': ?storefront},
    decode: (json) => json['url']! as String,
  );

  /// `GET /payments/subscriptions/me`: null when there is none.
  Future<IapSubscription?> mySubscription() => _client.value(
    '/payments/subscriptions/me',
    decode: (json) {
      final subscription = json['subscription'];
      return subscription is Map<String, Object?>
          ? IapSubscription.fromJson(subscription)
          : null;
    },
  );

  /// Before deleting the account: `appstore` / `googleplay` when a store
  /// subscription is still in use (the server cannot end it, tell the person
  /// to cancel in the store), else null.
  Future<String?> storeSubscriptionToCancel() async {
    final subscription = await mySubscription();
    if (subscription != null &&
        subscription.isFromStore &&
        subscription.isInUse) {
      return subscription.provider;
    }
    return null;
  }
}
