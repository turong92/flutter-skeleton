import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';
import 'package:skeleton_push/advertising.dart';
import 'package:skeleton_push/skeleton_push.dart';

import 'email_gate.dart';
import 'login_id_gate.dart';
import 'router.dart';

/// True when no account gate (ID, address that blocks, re-consent) is up. The
/// server refuses background reads under a gate with a 403; the push and board
/// providers depend on this, so they start (again) when the gate closes
/// instead of keeping the refusal.
final _gatesClearProvider = Provider<bool>(
  (ref) =>
      !ref.watch(needsLoginIdProvider) &&
      !ref.watch(emailGateProvider.select((g) => g.blocking)) &&
      ref.watch(reconsentProvider).isEmpty,
);

/// Where the packages meet. They do not know each other; the app hands each
/// the one `ApiClient` that `auth` builds, so every call carries the token and
/// a `403 LEGAL.RECONSENT_REQUIRED` reaches the interceptor.
final sampleWiring = <Override>[
  legalApiProvider.overrideWith(
    (ref) => LegalApi(ref.watch(apiClientProvider)),
  ),
  boardApiProvider.overrideWith((ref) {
    // a new BoardApi when the gate closes re-reads the config that a gate refused
    ref.watch(_gatesClearProvider);
    return BoardApi(ref.watch(apiClientProvider));
  }),
  // The sample server wants an author profile for a post; the first one of the
  // account is used. A server without profiles never calls this.
  boardAuthorResolverProvider.overrideWith((ref) {
    final client = ref.watch(apiClientProvider);
    return () async {
      final ids = await client.list(
        '/author-profiles',
        decode: (json) => json['id']! as String,
      );
      return ids.isEmpty ? null : ids.first;
    };
  }),
  pushApiProvider.overrideWith((ref) => PushApi(ref.watch(apiClientProvider))),
  // true only once the stored session is checked: a tap that started the app
  // waits until then
  pushSignedInProvider.overrideWith(
    (ref) =>
        ref.watch(authSessionProvider) is SignedIn &&
        ref.watch(_gatesClearProvider),
  ),
  iapApiProvider.overrideWith((ref) => IapApi(ref.watch(apiClientProvider))),
  // true only once the stored session is checked, as for push
  iapSignedInProvider.overrideWith(
    (ref) => ref.watch(authSessionProvider) is SignedIn,
  ),
  pushOpenLinkProvider.overrideWith(
    (ref) =>
        (link) => ref.read(routerProvider).go(link),
  ),
  // A tapped push without a link lands on the inbox.
  pushFallbackLinkProvider.overrideWithValue('/notifications'),
  advertisingApiProvider.overrideWith(
    (ref) => AdvertisingApi(ref.watch(apiClientProvider)),
  ),
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
      // The board's comment rows have no link, only the post id.
      final postId = int.tryParse('${item.payload['postId']}');
      final path = item.safeLink ?? (postId == null ? null : '/board/$postId');
      if (path != null) ref.read(routerProvider).go(path);
    },
  ),
];
