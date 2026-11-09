// #file ads iap
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:starter/ads_removal.dart';
import 'package:starter/l10n/l10n.dart';
import 'package:starter/screens/store_screen.dart';

class _SignedInSession extends AuthSession {
  @override
  AuthState build() =>
      const SignedIn(Principal(accountId: 'acc_1', roles: <String>[]));
}

class _CheckingSession extends AuthSession {
  @override
  AuthState build() => const AuthChecking();
}

final signedFlag = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

class _SignedOutSession extends AuthSession {
  @override
  AuthState build() => const SignedOut();
}

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

final _adsRemoved = Provider<bool>(
  (ref) => adsRemovedFor(ref, itemType: 'ads-removal', itemRef: 'remove'),
);

final _now = DateTime.utc(2026, 6, 1);

// the subscription way only, standard plan
final _adsRemovedBySub = Provider<bool>(
  (ref) => adsRemovedFor(
    ref,
    itemType: '',
    itemRef: '',
    planCode: 'standard',
    now: () => _now,
  ),
);

// both ways
final _adsRemovedByBoth = Provider<bool>(
  (ref) => adsRemovedFor(
    ref,
    itemType: 'ads-removal',
    itemRef: 'remove',
    planCode: 'standard',
    now: () => _now,
  ),
);

ProviderContainer _container(
  ResponseBody Function() entitlements, {
  bool signedIn = true,
  ResponseBody Function()? subscription,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(
        () => signedIn ? _SignedInSession() : _SignedOutSession(),
      ),
      iapSignedInProvider.overrideWithValue(signedIn),
      iapApiProvider.overrideWithValue(
        IapApi(
          ApiClient(
            baseUrl: 'http://x/api/v1',
            adapter: FakeAdapter(
              (o) => o.path.endsWith('/subscriptions/me')
                  ? (subscription ?? _noSubscription)()
                  : entitlements(),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ResponseBody _noSubscription() => FakeAdapter.json(200, {
  'value': {'subscription': null, 'orders': <Object>[]},
  'meta': _meta,
});

ResponseBody _sub(String status, {String plan = 'standard', String? end}) =>
    FakeAdapter.json(200, {
      'value': {
        'subscription': {
          'id': 's1',
          'status': status,
          'planCode': plan,
          'provider': 'googleplay',
          'currentPeriodEnd': end ?? '2999-01-01T00:00:00Z',
        },
        'orders': <Object>[],
      },
      'meta': _meta,
    });

ResponseBody _owns(List<Map<String, String>> values) => FakeAdapter.json(200, {
  'value': {'values': values},
  'meta': _meta,
});

Future<bool> _settled(
  ProviderContainer container, [
  Provider<bool>? provider,
]) async {
  final p = provider ?? _adsRemoved;
  container.listen(p, (_, _) {});
  await pumpEventQueue();
  return container.read(p);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owned = {'itemType': 'ads-removal', 'itemRef': 'remove'};

  group('ads removed', () {
    test('while the entitlements are being read the ads are off', () {
      final container = _container(() => _owns([owned]));
      container.listen(_adsRemoved, (_, _) {});
      expect(container.read(_adsRemoved), isTrue);
    });

    test('an account that owns it: off', () async {
      expect(await _settled(_container(() => _owns([owned]))), isTrue);
    });

    test('an account that does not own it: ads show', () async {
      expect(await _settled(_container(() => _owns([]))), isFalse);
    });

    test('a failed read: ads show', () async {
      final container = _container(
        () => FakeAdapter.json(500, {
          'code': 'COMMON.INTERNAL',
          'title': 'x',
          'status': 500,
        }),
      );
      expect(await _settled(container), isFalse);
    });

    test('signed out: ads show, and nothing is asked', () async {
      var asked = 0;
      final container = _container(() {
        asked++;
        return _owns([owned]);
      }, signedIn: false);
      expect(await _settled(container), isFalse);
      expect(asked, 0);
    });

    test('while the stored session is checked the ads are off', () {
      final container = ProviderContainer(
        overrides: [authSessionProvider.overrideWith(_CheckingSession.new)],
      );
      addTearDown(container.dispose);
      expect(container.read(_adsRemoved), isTrue);
    });

    test('another account after a logout does not inherit the ads removal', () async {
      var fails = false;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(_SignedInSession.new),
          signedFlag.overrideWith(() => _Flag()),
          iapPlatformProvider.overrideWithValue('android'),
          iapSignedInProvider.overrideWith((ref) => ref.watch(signedFlag)),
          iapApiProvider.overrideWithValue(
            IapApi(
              ApiClient(
                baseUrl: 'http://x/api/v1',
                adapter: FakeAdapter(
                  (o) => o.path.endsWith('/subscriptions/me')
                      ? _noSubscription()
                      : fails
                      ? FakeAdapter.json(500, {
                          'code': 'COMMON.X',
                          'title': 'x',
                          'status': 500,
                        })
                      : _owns([owned]),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // the app root watches the signed-in flag (through the iap service)
      container.listen(iapServiceProvider, (_, _) {});
      expect(await _settled(container), isTrue, reason: 'account A owns it');

      // A signs out (nobody reads while signed out), B signs in, the read fails
      container.read(signedFlag.notifier).set(false);
      await pumpEventQueue();
      fails = true;
      container.read(signedFlag.notifier).set(true);
      await pumpEventQueue();
      await pumpEventQueue();
      expect(container.read(_adsRemoved), isFalse);
    });

    test('an app that does not sell it keeps its ads', () async {
      final container = _container(() => _owns([owned]));
      final off = Provider<bool>(
        (ref) => adsRemovedFor(ref, itemType: '', itemRef: ''),
      );
      expect(container.read(off), isFalse);
    });
  });

  group('ads removed by a subscription', () {
    Future<bool> by(
      ResponseBody Function() sub, {
      ResponseBody Function()? owns,
      Provider<bool>? provider,
    }) => _settled(
      _container(owns ?? () => _owns([]), subscription: sub),
      provider ?? _adsRemovedBySub,
    );

    ResponseBody failure(int status) => FakeAdapter.json(status, {
      'code': 'COMMON.X',
      'title': 'x',
      'status': status,
    });

    test('ACTIVE and CANCELING (paid to the end) of the plan: off', () async {
      expect(await by(() => _sub('ACTIVE')), isTrue);
      expect(await by(() => _sub('CANCELING')), isTrue);
    });

    test('PAST_DUE, PENDING, ENDED: ads show', () async {
      for (final status in ['PAST_DUE', 'PENDING', 'ENDED']) {
        expect(await by(() => _sub(status)), isFalse, reason: status);
      }
    });

    test('a period that is over, or another plan: ads show', () async {
      expect(
        await by(() => _sub('ACTIVE', end: '2026-05-31T00:00:00Z')),
        isFalse,
      );
      expect(await by(() => _sub('ACTIVE', plan: 'premium')), isFalse);
    });

    test('no subscription, a server without the feature (404), a failed read: ads show', () async {
      expect(await by(_noSubscription), isFalse);
      expect(await by(() => failure(404)), isFalse);
      expect(await by(() => failure(500)), isFalse);
    });

    test('while it is being read the ads are off', () {
      final container = _container(
        () => _owns([]),
        subscription: () => _sub('ACTIVE'),
      );
      container.listen(_adsRemovedBySub, (_, _) {});
      expect(container.read(_adsRemovedBySub), isTrue);
    });

    test('either way is enough: bought, or subscribed', () async {
      expect(
        await by(
          _noSubscription,
          owns: () => _owns([owned]),
          provider: _adsRemovedByBoth,
        ),
        isTrue,
      );
      expect(
        await by(() => _sub('ACTIVE'), provider: _adsRemovedByBoth),
        isTrue,
      );
      expect(
        await by(() => _sub('PAST_DUE'), provider: _adsRemovedByBoth),
        isFalse,
      );
    });
  });

  testWidgets(
    'a once-bought product that is owned reads Purchased, not a buy button',
    (tester) async {
      IapOffer offer(String id, {required bool consumable, String? ref}) =>
          IapOffer(
            product: IapProduct(
              kind: IapProductKind.oneTime,
              storeProductId: id,
              itemType: 'x',
              itemRef: ref ?? id,
              consumable: consumable,
            ),
            details: ProductDetails(
              id: id,
              title: 'Title $id',
              description: '',
              price: r'$1.00',
              rawPrice: 1,
              currencyCode: 'USD',
            ),
            accountToken: 'token',
          );
      final catalog = IapCatalog(
        config: const IapConfig(
          channel: IapChannel.iapOnly,
          appAccountToken: 'token',
          products: [],
          store: 'googleplay',
        ),
        offers: [
          offer('remove_ads', consumable: false),
          offer('another_once', consumable: false),
          offer('coins', consumable: true),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iapCatalogProvider.overrideWith((ref) => catalog),
            iapServiceProvider.overrideWithValue(null),
            iapEntitlementsProvider.overrideWith(
              (ref) => const IapEntitlements({'x|remove_ads'}),
            ),
            mySubscriptionProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const StoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Purchased'), findsOneWidget);
      // the owned one has no buy button; the other two do
      expect(find.byType(FilledButton), findsNWidgets(2));
    },
  );
}
