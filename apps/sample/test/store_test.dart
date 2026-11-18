import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:sample/screens/account_screen.dart';
import 'package:sample/screens/store_screen.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

IapCatalog _catalog(IapChannel channel, {bool withOffer = false}) => IapCatalog(
  config: IapConfig(
    channel: channel,
    appAccountToken: 'token-from-server',
    products: const [],
  ),
  offers: [
    if (withOffer)
      IapOffer(
        product: const IapProduct(
          kind: IapProductKind.subscription,
          storeProductId: 'pro_monthly',
          plan: 'PRO',
        ),
        details: ProductDetails(
          id: 'pro_monthly',
          title: 'Pro monthly',
          description: 'Everything unlocked',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
        accountToken: 'token-from-server',
      ),
  ],
);

Widget _screen(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: child),
);

/// The real subscription read against a scripted server: it answers `404`
/// (the subscription feature is off, or no plan: not an error).
List<Override> _store(IapCatalog catalog, {int subscriptionStatus = 404}) => [
  iapCatalogProvider.overrideWith((ref) async => catalog),
  iapSignedInProvider.overrideWithValue(true),
  iapServiceProvider.overrideWithValue(null),
  iapApiProvider.overrideWithValue(
    IapApi(
      ApiClient(
        baseUrl: 'http://x/api/v1',
        adapter: FakeAdapter(
          (_) => FakeAdapter.json(subscriptionStatus, {
            'code': 'COMMON.NOT_FOUND',
            'title': 'Not found',
            'status': subscriptionStatus,
          }),
        ),
      ),
    ),
  ),
];

void main() {
  group('store screen', () {
    testWidgets('lists the products the store knows with a price to buy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          const StoreScreen(),
          _store(_catalog(IapChannel.iapOnly, withOffer: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pro monthly'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '\$4.99'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Restore purchases'),
        findsOneWidget,
      );
    });

    testWidgets('no subscription (404) reads as none, not as a bar that never '
        'ends', (tester) async {
      await tester.pumpWidget(
        _screen(const StoreScreen(), _store(_catalog(IapChannel.iapOnly))),
      );
      await tester.pumpAndSettle();

      expect(find.text('No subscription.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a device without usable billing says so instead of loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          const StoreScreen(),
          _store(
            IapCatalog(
              config: const IapConfig(
                channel: IapChannel.iapOnly,
                appAccountToken: 'token-from-server',
                products: [],
              ),
              offers: const [],
              storeAvailable: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Purchases are not available on this device.'),
        findsOneWidget,
      );
      expect(find.text('Nothing to buy right now.'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
    });

    testWidgets('the web checkout button is not there when the channel is '
        'IAP_ONLY', (tester) async {
      await tester.pumpWidget(
        _screen(const StoreScreen(), _store(_catalog(IapChannel.iapOnly))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pay on the web'), findsNothing);
    });

    testWidgets('the web checkout button shows when the channel has the web', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(const StoreScreen(), _store(_catalog(IapChannel.iapAndWeb))),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Pay on the web'),
        findsOneWidget,
      );
    });
  });

  group('account screen', () {
    testWidgets('asks to cancel a live store subscription before deleting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(const AccountScreen(), [
          iapStoreSubscriptionToCancelProvider.overrideWith(
            (ref) async => 'appstore',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cancel it in the App Store'), findsOneWidget);
    });

    testWidgets('says nothing when no store subscription is in use', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(const AccountScreen(), [
          iapStoreSubscriptionToCancelProvider.overrideWith(
            (ref) async => null,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cancel it in'), findsNothing);
    });
  });
}
