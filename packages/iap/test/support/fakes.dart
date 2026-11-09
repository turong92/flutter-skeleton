import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

/// The token the server hands out. A test that sees any other value in a
/// purchase has found an app-made token.
const serverToken = '6f1c0a4e-0000-4000-8000-000000000001';

ResponseBody valueBody(Object? value, {int status = 200}) =>
    FakeAdapter.json(status, {'value': value, 'meta': meta});

ResponseBody errorBody(int status, String code) =>
    FakeAdapter.json(status, {'code': code, 'title': 'x', 'status': status});

Map<String, Object?> configJson({
  String channel = 'IAP_ONLY',
  String? store = 'googleplay',
  String token = serverToken,
}) => {
  'channel': channel,
  'webCheckoutUrl': null,
  'store': store,
  'appAccountToken': token,
  'products': [
    {
      'kind': 'ONE_TIME',
      'itemType': 'cheer',
      'itemRef': 'cheer-3000',
      'plan': null,
      'storeProductId': 'cheer_3000',
      'basePlanId': null,
    },
    {
      'kind': 'ONE_TIME',
      'itemType': 'ads-removal',
      'itemRef': 'remove',
      'plan': null,
      'storeProductId': 'ads_removal',
      'basePlanId': null,
      'consumable': false,
    },
    {
      'kind': 'SUBSCRIPTION',
      'itemType': null,
      'itemRef': null,
      'plan': 'premium-monthly',
      'storeProductId': 'premium',
      'basePlanId': 'monthly',
    },
  ],
};

ResponseBody granted() => valueBody({
  'result': 'GRANTED',
  'kind': 'ONE_TIME',
  'orderId': 'ord_1',
  'subscription': null,
});

/// What Android has beyond the shared store API: past purchases and consume.
class FakeAndroidAddition implements InAppPurchaseAndroidPlatformAddition {
  /// What `queryPastPurchases` returns.
  List<GooglePlayPurchaseDetails> past = [];
  final consumed = <PurchaseDetails>[];

  @override
  Future<QueryPurchaseDetailsResponse> queryPastPurchases({
    String? applicationUserName,
  }) async => QueryPurchaseDetailsResponse(pastPurchases: past);

  @override
  Future<BillingResultWrapper> consumePurchase(PurchaseDetails purchase) async {
    consumed.add(purchase);
    return const BillingResultWrapper(responseCode: BillingResponse.ok);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Google Play purchase as the plugin builds it.
GooglePlayPurchaseDetails googlePurchase({
  String orderId = 'GPA.1',
  String product = 'cheer_3000',
  String token = 'gtoken-1',
  bool acknowledged = false,
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: orderId,
    packageName: 'com.example.app',
    purchaseTime: 0,
    purchaseToken: token,
    signature: 'sig',
    products: [product],
    isAutoRenewing: false,
    originalJson: '{}',
    isAcknowledged: acknowledged,
    purchaseState: PurchaseStateWrapper.purchased,
  ),
).single..status = PurchaseStatus.purchased;

/// The store side: what `in_app_purchase` calls on the platform.
class FakeStorePlatform extends InAppPurchasePlatform
    with MockPlatformInterfaceMixin {
  /// Delivered when the app starts listening (what the store keeps from the
  /// last run). Only StoreKit does this; Android hands nothing over on listen.
  List<PurchaseDetails> leftOver = [];
  bool redeliversOnListen = true;

  /// Replaces the plain details for a product id (Google Play lists one per
  /// subscription offer).
  final Map<String, List<ProductDetails>> productOverrides = {};
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  final bought = <({PurchaseParam param, bool consumable, bool autoConsume})>[];
  final restoreNames = <String?>[];
  bool completeFails = false;

  void deliver(PurchaseDetails purchase) => _controller.add([purchase]);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    late StreamController<List<PurchaseDetails>> out;
    StreamSubscription<List<PurchaseDetails>>? inner;
    out = StreamController<List<PurchaseDetails>>(
      onListen: () {
        inner = _controller.stream.listen(out.add);
        if (redeliversOnListen && leftOver.isNotEmpty) {
          final first = leftOver;
          scheduleMicrotask(() => out.add(first));
        }
      },
      onCancel: () => inner?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      for (final id in identifiers)
        ...productOverrides[id] ??
            [
              ProductDetails(
                id: id,
                title: id,
                description: '',
                price: r'$1.00',
                rawPrice: 1,
                currencyCode: 'USD',
              ),
            ],
    ],
    notFoundIDs: const [],
  );

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    bought.add((
      param: purchaseParam,
      consumable: true,
      autoConsume: autoConsume,
    ));
    return true;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add((param: purchaseParam, consumable: false, autoConsume: false));
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completeFails) throw StateError('store said no');
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async =>
      restoreNames.add(applicationUserName);

  @override
  Future<String> countryCode() async => 'US';
}

PurchaseDetails purchase({
  String id = 'tx-1',
  String product = 'cheer_3000',
  String data = 'token-1',
  PurchaseStatus status = PurchaseStatus.purchased,
}) => PurchaseDetails(
  purchaseID: id,
  productID: product,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: data,
    source: 'test',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = true;

/// A service on a fake store and a scripted server.
class Harness {
  Harness({
    this.platform = 'android',
    FutureOr<ResponseBody> Function(RequestOptions options)? onPurchase,
    String channel = 'IAP_ONLY',
    String? configStore = 'googleplay',
    this.linkUrl = 'https://example.com/pricing#handoff=SECRET-CODE',
    this.linkResponse,
  }) {
    store = FakeStorePlatform();
    // On android/ios the first access registers the real platform and opens
    // its billing connection; on another platform it registers nothing.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    final iap = InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    InAppPurchasePlatform.instance = store;
    store.redeliversOnListen = platform == 'ios';
    InAppPurchasePlatformAddition.instance = platform == 'android'
        ? android
        : null;
    this.onPurchase = onPurchase ?? (_) => granted();
    adapter = FakeAdapter((options) {
      switch (options.path) {
        case '/payments/iap/config':
          if (configFails) return errorBody(503, 'COMMON.UNAVAILABLE');
          return valueBody(configJson(channel: channel, store: configStore));
        case '/payments/iap/entitlements':
          entitlementReads++;
          if (entitlementsFail) return errorBody(503, 'COMMON.UNAVAILABLE');
          return valueBody({'values': entitlements});
        case '/payments/iap/web-checkout-link':
          return linkResponse ?? valueBody({'url': linkUrl});
        default:
          if (options.path.endsWith('/purchases')) {
            return this.onPurchase(options);
          }
          throw StateError('unscripted ${options.path}');
      }
    });
    service = IapService(
      api: IapApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter)),
      store: iap,
      platform: platform,
    );
    outcomesSub = service.outcomes.listen(outcomes.add);
  }

  final String platform;
  final String linkUrl;
  final ResponseBody? linkResponse;

  /// What `GET /iap/entitlements` answers: `{itemType, itemRef}` rows.
  List<Map<String, String>> entitlements = [];
  int entitlementReads = 0;
  bool entitlementsFail = false;
  bool configFails = false;
  late final FakeStorePlatform store;
  final android = FakeAndroidAddition();
  late final FakeAdapter adapter;
  late final IapService service;
  late final FutureOr<ResponseBody> Function(RequestOptions) onPurchase;
  late final StreamSubscription<IapOutcome> outcomesSub;
  final outcomes = <IapOutcome>[];

  List<RequestOptions> get purchaseCalls => [
    for (final r in adapter.requests)
      if (r.path.endsWith('/purchases')) r,
  ];

  /// Starts listening and lets the first delivery (left-over purchases) run.
  Future<void> start() async {
    service.start();
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    await outcomesSub.cancel();
    await service.dispose();
  }
}

/// Captures what the app prints and `debugPrint`s while [body] runs.
Future<List<String>> capturingLogs(Future<void> Function() body) async {
  final lines = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => lines.add('$message');
  try {
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
  } finally {
    debugPrint = previous;
  }
  return lines;
}
