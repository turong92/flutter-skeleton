// #file ads iap
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

/// Whether ads are off for the signed-in person because they paid to remove
/// them: they bought the once-bought product ([itemType] / [itemRef] are its
/// `itemType` / `itemRef` on the server) **or** a subscription to the plan
/// [planCode] is running (`ACTIVE`, or `CANCELING` until the paid period ends).
/// An empty pair / an empty plan means the app does not sell that way.
///
/// While the session is checked and a source is still being read the answer is
/// yes: a person who paid should not see ads flash at every start. A failed
/// read is no for that source: the ads stay. Signed out is no. Paid through
/// either way wins over a read still going on in the other.
bool adsRemovedFor(
  Ref ref, {
  required String itemType,
  required String itemRef,
  String planCode = '',
  DateTime Function() now = DateTime.now,
}) {
  final byPurchase = itemType.isNotEmpty && itemRef.isNotEmpty;
  final bySubscription = planCode.isNotEmpty;
  if (!byPurchase && !bySubscription) return false;
  final session = ref.watch(authSessionProvider);
  // the stored session is still being checked: treated like "reading"
  if (session is AuthChecking) return true;
  if (session is! SignedIn) return false;

  var reading = false;
  if (byPurchase) {
    final entitlements = ref.watch(iapEntitlementsProvider);
    if (entitlements.forThisAccount?.owns(itemType, itemRef) ?? false) {
      return true;
    }
    reading |= entitlements.isReadingForThisAccount;
  }
  if (bySubscription) {
    final subscription = ref.watch(iapSubscriptionProvider);
    final row = subscription.forThisAccount;
    if (row != null && row.keepsOn(planCode, now())) return true;
    reading |= subscription.isReadingForThisAccount;
  }
  return reading;
}
