import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:skeleton_auth/skeleton_auth.dart';
// #if board
import 'package:skeleton_board/skeleton_board.dart';
// #endif
// #if iap
import 'package:skeleton_iap/skeleton_iap.dart';
// #endif
import 'package:skeleton_legal/skeleton_legal.dart';
// #if notifications
import 'package:skeleton_notifications/skeleton_notifications.dart';
// #endif
// #if push
import 'package:skeleton_push/advertising.dart';
import 'package:skeleton_push/skeleton_push.dart';
// #endif
// #if storage
import 'package:skeleton_storage/skeleton_storage.dart';
// #endif

// #if notifications|push
import 'router.dart';

// #endif

/// Where the packages meet. `auth` and `legal` do not know each other; the app
/// gives `legal` the one `ApiClient` that `auth` builds, so its calls carry the
/// token and a `403 LEGAL.RECONSENT_REQUIRED` reaches the interceptor.
final starterWiring = <Override>[
  legalApiProvider.overrideWith(
    (ref) => LegalApi(ref.watch(apiClientProvider)),
  ),
  // #if board
  // A server whose config says `authorRequired` also needs
  // `boardAuthorResolverProvider` (the id of the author profile to write as).
  boardApiProvider.overrideWith(
    (ref) => BoardApi(ref.watch(apiClientProvider)),
  ),
  // #endif
  // #if iap
  iapApiProvider.overrideWith((ref) => IapApi(ref.watch(apiClientProvider))),
  // true only once the stored session is checked
  iapSignedInProvider.overrideWith(
    (ref) => ref.watch(authSessionProvider) is SignedIn,
  ),
  // #endif
  // #if push
  pushApiProvider.overrideWith((ref) => PushApi(ref.watch(apiClientProvider))),
  // true only once the stored session is checked: a tap that started the app
  // waits until then
  pushSignedInProvider.overrideWith(
    (ref) => ref.watch(authSessionProvider) is SignedIn,
  ),
  pushOpenLinkProvider.overrideWith(
    (ref) =>
        (link) => ref.read(routerProvider).go(link),
  ),
  advertisingApiProvider.overrideWith(
    (ref) => AdvertisingApi(ref.watch(apiClientProvider)),
  ),
  // #endif
  // #if notifications push
  // A tapped push without a link lands on the inbox.
  pushFallbackLinkProvider.overrideWithValue('/notifications'),
  // #endif
  // #if notifications
  notificationsApiProvider.overrideWith(
    (ref) => NotificationsApi(ref.watch(apiClientProvider)),
  ),
  // Everything of the inbox is keyed by this, so another account never sees
  // the previous one's rows.
  notificationsAccountProvider.overrideWith((ref) {
    final session = ref.watch(authSessionProvider);
    return session is SignedIn ? session.principal.accountId : null;
  }),
  notificationOpenProvider.overrideWith(
    (ref) => (item) {
      String? path = item.safeLink;
      // #endif
      // #if notifications board
      // The board's comment rows have no link, only the post id.
      final postId = int.tryParse('${item.payload['postId']}');
      if (path == null && postId != null) path = '/board/$postId';
      // #endif
      // #if notifications
      if (path != null) ref.read(routerProvider).go(path);
    },
  ),
  // #endif
  // #if storage
  storageApiProvider.overrideWith(
    (ref) => StorageApi(ref.watch(apiClientProvider)),
  ),
  // #endif
];
