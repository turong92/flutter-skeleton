// #file ads iap
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';

/// Whether ads are off for the signed-in person because they bought the ad
/// removal ([itemType] / [itemRef] are the product's `itemType` / `itemRef` on
/// the server). Empty values mean the app does not sell it.
///
/// While the session is checked and the entitlements are being read the answer is yes: a person who
/// bought it should not see ads flash at every start. A failed read is no: the
/// ads stay. Signed out is no.
bool adsRemovedFor(
  Ref ref, {
  required String itemType,
  required String itemRef,
}) {
  if (itemType.isEmpty || itemRef.isEmpty) return false;
  final session = ref.watch(authSessionProvider);
  // the stored session is still being checked: treated like "reading"
  if (session is AuthChecking) return true;
  if (session is! SignedIn) return false;
  return ref
      .watch(iapEntitlementsProvider)
      .when(
        data: (owned) => owned.owns(itemType, itemRef),
        loading: () => true,
        error: (_, _) => false,
      );
}
