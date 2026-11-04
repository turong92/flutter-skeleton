import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

import 'support/fakes.dart';

IapApi apiFor(Map<String, Object?>? subscription) => IapApi(
  ApiClient(
    baseUrl: 'http://x/api/v1',
    adapter: FakeAdapter(
      (_) => valueBody({'subscription': subscription, 'orders': <Object?>[]}),
    ),
  ),
);

Map<String, Object?> subscription(String provider, String status) => {
  'id': 'sub_1',
  'status': status,
  'planCode': 'premium-monthly',
  'provider': provider,
  'providerManaged': true,
};

void main() {
  test('only a channel with a web shows the web checkout', () {
    expect(IapChannel.parse('IAP_ONLY').showsWebCheckout, isFalse);
    expect(IapChannel.parse('IAP_AND_WEB').showsWebCheckout, isTrue);
    expect(IapChannel.parse('WEB_ONLY').showsWebCheckout, isTrue);
    expect(IapChannel.parse('something new').showsWebCheckout, isFalse);
  });

  group('the store subscription to cancel before deleting the account', () {
    test('a store subscription in use is named', () async {
      for (final provider in ['appstore', 'googleplay']) {
        for (final status in ['ACTIVE', 'CANCELING', 'PAST_DUE']) {
          expect(
            await apiFor(subscription(provider, status))
                .storeSubscriptionToCancel(),
            provider,
            reason: '$provider $status',
          );
        }
      }
    });

    test('none when it ended, is not from a store, or there is none', () async {
      expect(
        await apiFor(subscription('appstore', 'ENDED'))
            .storeSubscriptionToCancel(),
        isNull,
      );
      expect(
        await apiFor(subscription('toss', 'ACTIVE'))
            .storeSubscriptionToCancel(),
        isNull,
      );
      expect(await apiFor(null).storeSubscriptionToCancel(), isNull);
    });
  });
}
