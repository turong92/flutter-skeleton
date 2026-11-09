import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

/// What the signed-in account owns of the once-bought products
/// (`consumable: false`), read from the server. Read again after every grant
/// (a purchase or a restore) and for each sign-in; signed out owns nothing.
/// A failed read is an error state: decide what the app does then.
final FutureProvider<IapEntitlements>
iapEntitlementsProvider = FutureProvider<IapEntitlements>(
  (ref) async {
    ref.listen(iapOutcomesProvider, (_, next) {
      if (next.value is IapGranted) ref.invalidateSelf();
    });
    // A failed read is tried again when the app comes back to the front, so a
    // buyer is not left with the ads for the whole run.
    var failed = false;
    final observer = _ResumeObserver(() {
      if (failed) ref.invalidateSelf();
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    if (!ref.watch(iapSignedInProvider)) return IapEntitlements.none;
    try {
      return await ref.watch(iapApiProvider).entitlements();
    } on Object {
      failed = true;
      rethrow;
    }
  },
  // no automatic retry: a failed read must show as an error at once (the app
  // decides), not stay "loading" through the waits
  retry: (_, _) => null,
);

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final void Function() _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}
