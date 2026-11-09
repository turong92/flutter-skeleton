import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

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

/// The service is new for every sign-in (and the app watches it from its root),
/// so depending on it makes a read start again for the next account even when
/// nobody read in between and the signed-in flag is `true` at both ends. The
/// value Riverpod keeps over that reload is not to be used: see
/// [IapAccountValue].
void _bindToAccount(Ref ref) => ref.watch(iapServiceProvider);

/// When the app comes back to the front, [shouldRead] decides on a new read:
/// after a failed read (so a buyer is not left with the ads for the whole
/// run), or when a period that was paid for has run out.
void _retryOnResume(Ref ref, bool Function() shouldRead) {
  final observer = _ResumeObserver(() {
    if (shouldRead()) ref.invalidateSelf();
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
}

/// What the signed-in account owns of the once-bought products
/// (`consumable: false`), read from the server. Read again after every grant
/// (a purchase or a restore) and for each sign-in; signed out owns nothing.
/// A failed read is an error state: decide what the app does then. Read it
/// with [IapAccountValue.forThisAccount].
final FutureProvider<IapEntitlements>
iapEntitlementsProvider = FutureProvider<IapEntitlements>(
  (ref) async {
    _bindToAccount(ref);
    ref.listen(iapOutcomesProvider, (_, next) {
      if (next.value is IapGranted) ref.invalidateSelf();
    });
    var failed = false;
    _retryOnResume(ref, () => failed);
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

/// The signed-in account's subscription as the server has it (`null` when it
/// has none, when signed out, and on a server with the subscription feature
/// off: `404`). Read again after every grant, and when the app comes back to
/// the front after a failed read or after the paid period ran out. A failed
/// read is an error state. Read it with [IapAccountValue.forThisAccount], and
/// ask [IapSubscription.keepsOn] whether a plan is running.
final FutureProvider<IapSubscription?> iapSubscriptionProvider =
    FutureProvider<IapSubscription?>((ref) async {
      _bindToAccount(ref);
      ref.listen(iapOutcomesProvider, (_, next) {
        if (next.value is IapGranted) ref.invalidateSelf();
      });
      var failed = false;
      DateTime? periodEnd;
      _retryOnResume(ref, () {
        final end = periodEnd;
        return failed || (end != null && !end.isAfter(DateTime.now()));
      });
      if (!ref.watch(iapSignedInProvider)) return null;
      try {
        final row = await ref.watch(iapApiProvider).mySubscription();
        periodEnd = row?.currentPeriodEnd;
        return row;
      } on ApiRequestError catch (e) {
        if (e.status == 404) return null;
        failed = true;
        rethrow;
      } on Object {
        failed = true;
        rethrow;
      }
    }, retry: (_, _) => null);

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final void Function() _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

/// Reading an entitlement or a subscription for the account that is signed in
/// now. Riverpod keeps the last value while a provider loads again or fails,
/// and these providers are not read while signed out, so after another account
/// signs in the "previous value" can still be the one of the account before.
extension IapAccountValue<T> on AsyncValue<T> {
  /// The value, but not the one kept over a reload (the account changed) or
  /// over an error. A refresh of the same account (after a grant) keeps it.
  T? get forThisAccount => (isReloading || hasError) ? null : value;

  /// Still reading for this account: the first read, or a reload after the
  /// account changed. A refresh after a grant is not (the last value holds).
  bool get isReadingForThisAccount => isLoading && (isReloading || !hasValue);
}
