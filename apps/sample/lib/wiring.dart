import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_push/skeleton_push.dart';

import 'router.dart';

/// Where the packages meet. They do not know each other; the app hands each
/// the one `ApiClient` that `auth` builds, so every call carries the token and
/// a `403 LEGAL.RECONSENT_REQUIRED` reaches the interceptor.
final sampleWiring = <Override>[
  legalApiProvider.overrideWith(
    (ref) => LegalApi(ref.watch(apiClientProvider)),
  ),
  boardApiProvider.overrideWith(
    (ref) => BoardApi(ref.watch(apiClientProvider)),
  ),
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
    (ref) => ref.watch(authSessionProvider) is SignedIn,
  ),
  pushOpenLinkProvider.overrideWith(
    (ref) =>
        (link) => ref.read(routerProvider).go(link),
  ),
];
