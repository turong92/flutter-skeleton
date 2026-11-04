import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'legal_api.dart';
import 'models.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `legalApiProvider.overrideWith((ref) => LegalApi(ref.watch(apiClientProvider)))`.
final legalApiProvider = Provider<LegalApi>(
  (ref) => throw UnimplementedError(
    'Override legalApiProvider with a LegalApi built on the app\'s ApiClient',
  ),
);

/// The current documents. After a `400 LEGAL.CONSENT_REQUIRED` on sign-up,
/// `ref.invalidate(legalDocumentsProvider)` reads them again (a new version
/// may have come out while the form was open).
final legalDocumentsProvider =
    FutureProvider.autoDispose<List<LegalDocumentSummary>>(
      (ref) => ref.watch(legalApiProvider).documents(),
      retry: (_, _) => null,
    );

typedef LegalDocumentRef = ({String type, String? version, String? locale});

/// One document with its text.
final legalDocumentProvider = FutureProvider.autoDispose
    .family<LegalDocument, LegalDocumentRef>(
      (ref, key) => ref
          .watch(legalApiProvider)
          .document(key.type, version: key.version, locale: key.locale),
      retry: (_, _) => null,
    );
