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

class _SignedOutSession extends AuthSession {
  @override
  AuthState build() => const SignedOut();
}

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

final _adsRemoved = Provider<bool>(
  (ref) => adsRemovedFor(ref, itemType: 'ads-removal', itemRef: 'remove'),
);

ProviderContainer _container(
  ResponseBody Function() entitlements, {
  bool signedIn = true,
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
            adapter: FakeAdapter((_) => entitlements()),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ResponseBody _owns(List<Map<String, String>> values) => FakeAdapter.json(200, {
  'value': {'values': values},
  'meta': _meta,
});

Future<bool> _settled(ProviderContainer container) async {
  container.listen(_adsRemoved, (_, _) {});
  await pumpEventQueue();
  return container.read(_adsRemoved);
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

    test('an app that does not sell it keeps its ads', () async {
      final container = _container(() => _owns([owned]));
      final off = Provider<bool>(
        (ref) => adsRemovedFor(ref, itemType: '', itemRef: ''),
      );
      expect(container.read(off), isFalse);
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
