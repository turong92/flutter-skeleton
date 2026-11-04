import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'iap_api.dart';
import 'models.dart';

/// Opening the web checkout failed. The message never holds the address: it
/// carries a one-time sign-in code.
class IapWebLinkException implements Exception {
  const IapWebLinkException();

  @override
  String toString() =>
      'IapWebLinkException: the web checkout could not be opened';
}

/// Sells through the store and lets the server decide.
///
/// One service belongs to one signed-in account (the provider makes a new one
/// when the account changes). The rules:
/// - The account token in a purchase is the one `GET /iap/config` gave.
/// - A purchase is finished in the store (`completePurchase`) only after the
///   server answered `GRANTED`, or refused it for good. Every other answer
///   leaves it open so the store hands it back.
/// - This class opens no entitlement: [outcomes] only says that the server
///   granted, and the app reads the entitlement from the server.
class IapService {
  IapService({
    required this._api,
    required this._store,
    required this._platform,
  });

  final IapApi _api;
  final InAppPurchase _store;

  /// `ios` / `android`.
  final String _platform;

  final _outcomes = StreamController<IapOutcome>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Purchases being checked now, finished ones, and ones the server did not
  // settle yet (kept to send again).
  final _inFlight = <String>{};
  final _done = <String>{};
  final _unfinished = <String, PurchaseDetails>{};

  // The kind of each product the server maps (set by [loadCatalog]), for the
  // answers that carry no `kind`.
  final _kinds = <String, IapProductKind>{};

  bool get _isAndroid => _platform != 'ios';

  String get _storeId => _platform == 'ios' ? 'appstore' : 'googleplay';

  Stream<IapOutcome> get outcomes => _outcomes.stream;

  /// Starts listening to the store. Do it early. StoreKit hands over the
  /// purchases left from the last run when someone listens; Google Play does
  /// not, so on Android the unacknowledged ones are read here.
  void start() {
    if (_subscription != null) return;
    _subscription = _store.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          unawaited(_handle(purchase));
        }
      },
      // A broken stream must not take the app down; the next start listens again.
      onError: (Object _) {},
    );
    if (_isAndroid) unawaited(_sendUnacknowledged());
  }

  Future<void> _sendUnacknowledged() async {
    try {
      final past = await _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      // Acknowledged ones were settled before; sending them again only eats
      // the server's request limit.
      for (final purchase in past.pastPurchases) {
        if (!purchase.billingClientPurchase.isAcknowledged) {
          unawaited(_handle(purchase));
        }
      }
    } on Object {
      // Nothing to read now; the next start reads again.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _outcomes.close();
  }

  /// The server's products that the store lists, with the account token.
  Future<IapCatalog> loadCatalog() async {
    final config = await _api.config(
      platform: _platform,
      storefront: await _storefront(),
    );
    // No store for this platform on the server: it would answer 503 to a paid
    // purchase.
    if (config.store == null) return IapCatalog(config: config, offers: []);
    _kinds.addAll({for (final p in config.products) p.storeProductId: p.kind});
    final found = await _store.queryProductDetails({
      for (final p in config.products) p.storeProductId,
    });
    return IapCatalog(
      config: config,
      offers: [
        for (final product in config.products)
          for (final details in found.productDetails)
            if (details.id == product.storeProductId &&
                _isMappedPlan(product, details))
              IapOffer(
                product: product,
                details: details,
                accountToken: config.appAccountToken,
              ),
      ],
    );
  }

  /// Google lists one entry per subscription offer; the server maps one base
  /// plan only. Another plan would be paid and then refused.
  bool _isMappedPlan(IapProduct product, ProductDetails details) {
    if (product.kind != IapProductKind.subscription ||
        details is! GooglePlayProductDetails) {
      return true;
    }
    final index = details.subscriptionIndex;
    final offers = details.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null) return true;
    return offers[index].basePlanId == product.basePlanId;
  }

  /// Starts the store's purchase sheet. The result arrives on [outcomes].
  Future<void> buy(IapOffer offer) async {
    final param = PurchaseParam(
      productDetails: offer.details,
      applicationUserName: offer.accountToken,
    );
    // Not consumed on its own: the store would give it away before the server
    // has checked it. StoreKit insists on `true` and consumes only when the
    // purchase is completed; Google Play is consumed by hand in [_finish].
    if (offer.product.kind == IapProductKind.oneTime) {
      await _store.buyConsumable(
        purchaseParam: param,
        autoConsume: _platform == 'ios',
      );
    } else {
      await _store.buyNonConsumable(purchaseParam: param);
    }
  }

  /// Asks the store for what the person owns. It arrives like any purchase
  /// and goes to the server.
  Future<void> restore(IapCatalog catalog) => _store.restorePurchases(
    applicationUserName: catalog.config.appAccountToken,
  );

  /// Sends again what the server could not settle (no network, `429`, `503`,
  /// a pending payment).
  Future<void> retryUnfinished() async {
    final again = _unfinished.values.toList();
    _unfinished.clear();
    await Future.wait([for (final purchase in again) _handle(purchase)]);
  }

  /// Asks the server for a one-time sign-in address and opens it in the
  /// outside browser (never a web view). Throws [ApiRequestError] when the
  /// server refuses (`404` in an `IAP_ONLY` channel), [IapWebLinkException]
  /// when it cannot be opened.
  Future<void> openWebCheckout() async {
    final link = await _api.webCheckoutLink(
      platform: _platform,
      storefront: await _storefront(),
    );
    final uri = Uri.tryParse(link);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const IapWebLinkException();
    }
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // The platform's error text can hold the address.
      throw const IapWebLinkException();
    }
    if (!opened) throw const IapWebLinkException();
  }

  Future<String?> _storefront() async {
    try {
      return await _store.countryCode();
    } on Object {
      return null;
    }
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _emit(IapNotConfirmed(purchase.productID, IapWait.storePending));
      case PurchaseStatus.error:
      case PurchaseStatus.canceled:
        // Nothing was paid, nothing to check: finish it so the store drops it.
        await _finish(purchase);
        _emit(
          IapStoreError(
            purchase.productID,
            purchase.error?.message ?? purchase.status.name,
          ),
        );
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verify(purchase);
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final key =
        '${purchase.productID}|${purchase.purchaseID ?? purchase.verificationData.serverVerificationData}';
    if (_done.contains(key) || !_inFlight.add(key)) return;
    try {
      final result = await _api.confirmPurchase(_storeId, _body(purchase));
      if (result.granted) {
        _done.add(key);
        await _finish(
          purchase,
          oneTime:
              (result.kind ?? _kinds[purchase.productID]) ==
              IapProductKind.oneTime,
        );
        _emit(
          IapGranted(
            purchase.productID,
            orderId: result.orderId,
            subscription: result.subscription,
          ),
        );
      } else {
        _unfinished[key] = purchase;
        _emit(IapNotConfirmed(purchase.productID, IapWait.storePending));
      }
    } on ApiRequestError catch (e) {
      if (_refusedForGood(e)) {
        _done.add(key);
        await _finish(
          purchase,
          oneTime: _kinds[purchase.productID] == IapProductKind.oneTime,
        );
        _emit(IapRejected(purchase.productID, e.code));
      } else if (e.code == IapErrorCodes.ownedElsewhere) {
        _emit(IapNotConfirmed(purchase.productID, IapWait.otherAccount));
      } else {
        _unfinished[key] = purchase;
        _emit(IapNotConfirmed(purchase.productID, IapWait.retryLater));
      }
    } finally {
      _inFlight.remove(key);
    }
  }

  Map<String, Object?> _body(PurchaseDetails purchase) => _platform == 'ios'
      ? {'transactionId': purchase.purchaseID}
      : {
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
        };

  /// The server's table of answers that end a purchase without a grant.
  bool _refusedForGood(ApiRequestError e) => switch ((e.status, e.code)) {
    (404, IapErrorCodes.notFound) => true,
    (409, IapErrorCodes.alreadySubscribed) => true,
    (422, IapErrorCodes.productUnknown) => true,
    (422, IapErrorCodes.revoked) => true,
    (422, IapErrorCodes.notEligible) => true,
    _ => false,
  };

  /// Ends the purchase in the store. A one-time Google Play purchase is
  /// consumed (that also acknowledges it); without it the same product could
  /// not be bought again. Everything else is completed.
  Future<void> _finish(PurchaseDetails purchase, {bool oneTime = false}) async {
    try {
      if (_isAndroid && oneTime) {
        await _store
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(purchase);
        return;
      }
      if (!purchase.pendingCompletePurchase) return;
      await _store.completePurchase(purchase);
    } on Object {
      // The server already settled it; the store hands it back at the next
      // start and the server answers the same.
    }
  }

  void _emit(IapOutcome outcome) {
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }
}
