/// The ad removal bought for real against StoreKit, on the iOS simulator.
///
/// What is real: the sample app, the `skeleton_iap` service, the
/// `in_app_purchase` plugin and StoreKit (the local test store of
/// `ios/Runner/Products.storekit`, driven by `ios/RunnerTests/RunnerTests.swift`).
/// What stands in: the sample server and Apple's server. [_Server] answers the
/// requests of the contract and, where the real server would ask Apple, asks
/// the test store instead (`storekit_test` channel): a purchase it never saw
/// is `404`, a refunded one is `422`, a subscription is over when the store
/// says it expired. It checks no signature (kotlin `payment-appstore` does);
/// this run proves the app side only.
///
/// Run: `scripts/test-ios-storekit.sh`.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sample/main.dart';
import 'package:sample/wiring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_ads/testing.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_i18n/skeleton_i18n.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

const _storekit = MethodChannel('storekit_test');
const _meta = {'timestamp': '2026-01-01T00:00:00Z'};
const _principal = {
  'accountId': 'acc_user',
  'email': 'user@example.com',
  'roles': ['USER'],
  'permissions': <String>[],
};

const _removeAds = 'com.example.sample.removeads';
const _monthly = 'com.example.sample.standard.monthly';

/// The transactions the test store holds (finished ones too).
Future<List<Map<String, Object?>>> _transactions() async {
  final rows = await _storekit.invokeListMethod<Map<Object?, Object?>>(
    'transactions',
  );
  return [for (final row in rows!) row.cast<String, Object?>()];
}

DateTime? _time(Object? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);

ResponseBody _value(Object? value, {int status = 200}) =>
    FakeAdapter.json(status, {'value': value, 'meta': _meta});

ResponseBody _error(int status, String code) =>
    FakeAdapter.json(status, {'code': code, 'title': 'x', 'status': status});

/// An account of the sample server: what it has confirmed with "Apple" (the
/// transaction ids the app sent). It outlives an app restart, like the
/// account on the real server.
class _Server {
  /// Transaction ids the server accepted, by store product id.
  final confirmed = <String, String>{};

  late final adapter = FakeAdapter((o) {
    _seen.add(o);
    return _handle(o);
  });

  List<RequestOptions> get requests => adapter.requests;

  Future<ResponseBody> _handle(RequestOptions options) async {
    switch ((options.method, options.path)) {
      case ('POST', '/auth/login'):
        return _value({
          'accessToken': 'access-1',
          'tokenType': 'Bearer',
          'expiresAt': '2999-01-01T00:15:00Z',
          'principal': _principal,
          'refreshToken': 'refresh-1',
        });
      case ('GET', '/auth/me'):
        return _value(_principal);
      case ('POST', '/auth/logout'):
        return FakeAdapter.empty(204);
      case ('GET', '/payments/iap/config'):
        return _value({
          'channel': 'IAP_ONLY',
          'webCheckoutUrl': null,
          'store': 'appstore',
          'appAccountToken': '6f1c0a4e-0000-4000-8000-000000000001',
          'products': [
            {
              'kind': 'ONE_TIME',
              'itemType': 'ads-removal',
              'itemRef': 'ads-removal',
              'plan': null,
              'storeProductId': _removeAds,
              'basePlanId': null,
              'consumable': false,
            },
            {
              'kind': 'SUBSCRIPTION',
              'itemType': null,
              'itemRef': null,
              'plan': 'standard',
              'storeProductId': _monthly,
              'basePlanId': null,
            },
          ],
        });
      case ('POST', '/payments/iap/appstore/purchases'):
        return _confirm((options.data as Map)['transactionId'] as String);
      case ('GET', '/payments/iap/entitlements'):
        return _entitlements();
      case ('GET', '/payments/subscriptions/me'):
        return _subscription();
    }
    return _error(404, 'COMMON.NOT_FOUND');
  }

  /// `POST /payments/iap/appstore/purchases`: the real server asks Apple for
  /// the transaction; here the test store is asked.
  Future<ResponseBody> _confirm(String transactionId) async {
    final found = (await _transactions()).where(
      (t) => t['id'] == transactionId,
    );
    if (found.isEmpty) return _error(404, 'PAYMENT.IAP_PURCHASE_NOT_FOUND');
    final transaction = found.first;
    final product = transaction['productId']! as String;
    if (transaction['revokedAt'] != null) {
      return _error(422, 'PAYMENT.IAP_PURCHASE_REVOKED');
    }
    if (product != _removeAds && product != _monthly) {
      return _error(422, 'PAYMENT.IAP_PRODUCT_UNKNOWN');
    }
    confirmed[product] = transactionId;
    return _value({
      'result': 'GRANTED',
      'kind': product == _removeAds ? 'ONE_TIME' : 'SUBSCRIPTION',
      'orderId': 'ord_$transactionId',
      'subscription': null,
    });
  }

  Future<ResponseBody> _entitlements() async {
    final id = confirmed[_removeAds];
    final live =
        id != null &&
        (await _transactions()).any(
          (t) => t['id'] == id && t['revokedAt'] == null,
        );
    return _value({
      'values': [
        if (live) {'itemType': 'ads-removal', 'itemRef': 'ads-removal'},
      ],
    });
  }

  Future<ResponseBody> _subscription() async {
    if (!confirmed.containsKey(_monthly)) {
      return _value({'subscription': null, 'orders': <Object?>[]});
    }
    // the latest period of the subscription in the store (a renewal is a new
    // transaction of the same product)
    final rows = [
      for (final t in await _transactions())
        if (t['productId'] == _monthly) t,
    ];
    DateTime? end;
    var revoked = false;
    for (final t in rows) {
      final expires = _time(t['expiresAt']);
      if (expires != null && (end == null || expires.isAfter(end))) {
        end = expires;
      }
      revoked |= t['revokedAt'] != null;
    }
    final over = revoked || end == null || !end.isAfter(DateTime.now());
    return _value({
      'subscription': {
        'id': 's1',
        'status': over ? 'ENDED' : 'ACTIVE',
        'planCode': 'standard',
        'provider': 'appstore',
        'currentPeriodEnd': end?.toUtc().toIso8601String(),
      },
      'orders': <Object?>[],
    });
  }
}

Widget _app(_Server server, TokenStore tokens) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    // the texts the test looks for are English, whatever language the simulator has
    savedLocaleProvider.overrideWithValue(const Locale('en')),
    tokenStoreProvider.overrideWithValue(tokens),
    signUpAttemptStoreProvider.overrideWithValue(MemorySignUpAttemptStore()),
    httpAdapterProvider.overrideWithValue(server.adapter),
    ...sampleWiring,
    socialProvidersProvider.overrideWithValue(const []),
    // the ad SDK stays a double (no network); the store is the real one
    adsSdkProvider.overrideWithValue(FakeAdsSdk()),
  ],
  child: const SampleApp(),
);

/// Waits in real time (the store answers on its own clock).
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    for (final e
        in find
            .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
            .evaluate()) {
      _snacks.add((e.widget as Text).data ?? '');
    }
    if (DateTime.now().isAfter(end)) {
      fail(
        'timed out waiting for: $what\n'
        'server saw: ${_seen.map((r) => '${r.method} ${r.path}${r.data == null ? '' : ' ${r.data}'}').join(', ')}\n'
        'messages shown: $_snacks\n'
        'store holds: ${await _transactions()}\n'
        'session holds: ${await _storekit.invokeMethod<List<Object?>>('sessionTransactions')}\n'
        'on screen: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList()}',
      );
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// What the server was asked in this test, for a failure message.
final _seen = <RequestOptions>[];
final _snacks = <String>{};

final _banner = find.byKey(FakeAdsSdk.bannerKey);

Future<void> _signIn(WidgetTester tester) async {
  await _until(
    tester,
    () => find.byKey(LoginForm.emailKey).evaluate().isNotEmpty,
    what: 'the sign-in form',
  );
  await tester.enterText(find.byKey(LoginForm.emailKey), 'user@example.com');
  await tester.enterText(find.byKey(LoginForm.passwordKey), 'password');
  await tester.tap(find.text('Sign in'));
  await _until(
    tester,
    () => find.byType(NavigationBar).evaluate().isNotEmpty,
    what: 'the tabs',
  );
}

Future<void> _openStore(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Store'),
    ),
  );
  await _until(
    tester,
    () => find.widgetWithText(FilledButton, r'$4.99').evaluate().isNotEmpty,
    what: 'the products of StoreKit',
  );
}

/// The app ends and starts again: new providers, the same account on the
/// server and the same transactions in the store.
Future<void> _restart(
  WidgetTester tester,
  _Server server,
  TokenStore tokens,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(_app(server, tokens));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // The Dart side starts with the app, the native test a moment later (it
  // makes the store session and the channel): wait for it.
  setUpAll(() async {
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (true) {
      try {
        await _storekit.invokeMethod<void>('reset');
        return;
      } on MissingPluginException {
        if (DateTime.now().isAfter(end)) fail('no StoreKit test session');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _seen.clear();
    _snacks.clear();
    await _storekit.invokeMethod<void>('reset');
  });

  testWidgets('StoreKit lists the products of the server with their prices', (
    tester,
  ) async {
    final server = _Server();
    await tester.pumpWidget(_app(server, MemoryTokenStore()));
    await _signIn(tester);
    expect(_banner, findsOneWidget);

    await _openStore(tester);

    expect(find.text('Remove ads'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, r'$4.99'), findsOneWidget);
    expect(find.text('Standard monthly'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, r'$2.99'), findsOneWidget);
    // a product the server does not map is not offered
    expect(find.text('Cheer'), findsNothing);
  });

  testWidgets(
    'the one-time purchase removes the banner, keeps it away after a restart '
    'and comes back with a restore on a new account',
    (tester) async {
      final server = _Server();
      final tokens = MemoryTokenStore();
      await tester.pumpWidget(_app(server, tokens));
      await _signIn(tester);
      await _openStore(tester);
      expect(_banner, findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, r'$4.99'));
      await _until(tester, () => _banner.evaluate().isEmpty, what: 'no banner');

      // the server was shown a transaction that the store holds
      final store = await _transactions();
      expect(server.confirmed[_removeAds], isNotNull);
      expect(store.map((t) => t['id']), contains(server.confirmed[_removeAds]));

      // restart: the account is restored and the ads stay off
      await _restart(tester, server, tokens);
      await _until(
        tester,
        () =>
            find.byType(NavigationBar).evaluate().isNotEmpty &&
            server.requests
                    .where((r) => r.path.endsWith('/entitlements'))
                    .length >=
                2,
        what: 'the entitlements read again after the restart',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_banner, findsNothing);

      // a new account on the server (nothing confirmed) shows the banner again
      server.confirmed.clear();
      await _restart(tester, server, tokens);
      await _until(tester, () => _banner.evaluate().isNotEmpty, what: 'banner');

      // restore hands the store's purchase to the server and the ads go
      await _openStore(tester);
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Restore purchases'),
      );
      await _until(tester, () => _banner.evaluate().isEmpty, what: 'no banner');
      expect(server.confirmed[_removeAds], isNotNull);
    },
  );

  testWidgets('a refunded one-time purchase brings the banner back', (
    tester,
  ) async {
    final server = _Server();
    final tokens = MemoryTokenStore();
    await tester.pumpWidget(_app(server, tokens));
    await _signIn(tester);
    await _openStore(tester);
    await tester.tap(find.widgetWithText(FilledButton, r'$4.99'));
    await _until(tester, () => _banner.evaluate().isEmpty, what: 'no banner');

    await _storekit.invokeMethod<void>('refund', {
      'id': server.confirmed[_removeAds],
    });
    await _restart(tester, server, tokens);

    await _until(tester, () => _banner.evaluate().isNotEmpty, what: 'banner');
  });

  testWidgets(
    'the subscription removes the banner until it runs out, then it returns',
    (tester) async {
      // a month is thirty seconds in the test store
      await _storekit.invokeMethod<void>('fastTime');
      final server = _Server();
      await tester.pumpWidget(_app(server, MemoryTokenStore()));
      await _signIn(tester);
      await _openStore(tester);

      await tester.tap(find.widgetWithText(FilledButton, r'$2.99'));
      await _until(tester, () => _banner.evaluate().isEmpty, what: 'no banner');
      expect(server.confirmed[_monthly], isNotNull);

      // the person cancels: the period still runs, the banner stays away
      await _storekit.invokeMethod<void>('cancelRenewal', {
        'id': server.confirmed[_monthly],
      });
      await tester.pump(const Duration(seconds: 2));
      expect(_banner, findsNothing);

      // the period ends; the app coming back to the front reads it again
      await _until(
        tester,
        () {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          return _banner.evaluate().isNotEmpty;
        },
        what: 'the banner back after the period ended',
        timeout: const Duration(seconds: 90),
      );
    },
  );
}
