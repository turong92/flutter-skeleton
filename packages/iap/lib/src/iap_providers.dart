import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_api.dart';
import 'iap_service.dart';
import 'models.dart';

/// The app overrides this with the `IapApi` built on its one `ApiClient`.
final iapApiProvider = Provider<IapApi>(
  (ref) => throw UnimplementedError(
    'Override iapApiProvider with an IapApi built on the app\'s ApiClient',
  ),
);

/// The app says whether a session exists, so `iap` needs no auth import:
/// `iapSignedInProvider.overrideWith((ref) => ref.watch(sessionProvider) is SignedIn)`.
final iapSignedInProvider = Provider<bool>((ref) => false);

final iapStoreProvider = Provider<InAppPurchase>(
  (ref) => InAppPurchase.instance,
);

/// `ios` / `android`; null where there is no store (web, desktop).
final iapPlatformProvider = Provider<String?>(
  (ref) => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  },
);

/// Null when signed out or there is no store. A new service (and so a new
/// catalog and account token) comes with every sign-in, never one from the
/// account before. Watch it once from the app root so the store's left-over
/// purchases are picked up at start.
final iapServiceProvider = Provider<IapService?>((ref) {
  final platform = ref.watch(iapPlatformProvider);
  if (!ref.watch(iapSignedInProvider) || platform == null) return null;
  final service = IapService(
    api: ref.watch(iapApiProvider),
    store: ref.watch(iapStoreProvider),
    platform: platform,
  )..start();
  ref.onDispose(service.dispose);
  return service;
});

final iapCatalogProvider = FutureProvider<IapCatalog?>(
  (ref) => ref.watch(iapServiceProvider)?.loadCatalog(),
);

/// What the server said to each purchase.
final iapOutcomesProvider = StreamProvider<IapOutcome>(
  (ref) => ref.watch(iapServiceProvider)?.outcomes ?? const Stream.empty(),
);

/// `appstore` / `googleplay` when the account still has a store subscription
/// in use; show "cancel it in the store" before deleting the account.
final iapStoreSubscriptionToCancelProvider =
    FutureProvider.autoDispose<String?>(
      (ref) => ref.watch(iapApiProvider).storeSubscriptionToCancel(),
    );
