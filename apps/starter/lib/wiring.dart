import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

/// Where the packages meet. `auth` and `legal` do not know each other; the app
/// gives `legal` the one `ApiClient` that `auth` builds, so its calls carry the
/// token and a `403 LEGAL.RECONSENT_REQUIRED` reaches the interceptor.
final starterWiring = <Override>[
  legalApiProvider.overrideWith(
    (ref) => LegalApi(ref.watch(apiClientProvider)),
  ),
];
