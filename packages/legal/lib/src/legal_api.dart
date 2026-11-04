import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend calls of the `legal` module. Stores nothing.
class LegalApi {
  LegalApi(this._client);

  final ApiClient _client;

  /// `GET /legal/documents`: the current version of every document, one entry
  /// per language. Public.
  Future<List<LegalDocumentSummary>> documents() => _client.list(
    '/legal/documents',
    skipAuth: true,
    decode: LegalDocumentSummary.fromJson,
  );

  /// `GET /legal/documents/{type}`: the current version, or [version] when it
  /// is already in force. [locale] falls back to the backend's default.
  Future<LegalDocument> document(
    String type, {
    String? version,
    String? locale,
  }) => _client.value(
    '/legal/documents/$type',
    skipAuth: true,
    query: {'version': ?version, 'locale': ?locale},
    decode: LegalDocument.fromJson,
  );

  /// `GET /legal/consents/me`.
  Future<ConsentStatus> status() =>
      _client.value('/legal/consents/me', decode: ConsentStatus.fromJson);

  /// `POST /legal/consents`: agree to these versions. A version that is no
  /// longer agreeable is refused with 409 LEGAL.VERSION_STALE. [source] names
  /// the screen it came from.
  Future<ConsentStatus> agree(List<ConsentClaim> claims, {String? source}) =>
      _client.value(
        '/legal/consents',
        method: 'POST',
        json: {
          'consents': [for (final claim in claims) claim.toJson()],
          'source': ?source,
        },
        decode: ConsentStatus.fromJson,
      );

  /// `POST /legal/consents/{type}/withdraw`: withdraw an optional agreement
  /// (marketing ...). Idempotent. A required type is refused with 409
  /// LEGAL.WITHDRAWAL_NOT_ALLOWED.
  Future<ConsentStatus> withdraw(String type) => _client.value(
    '/legal/consents/$type/withdraw',
    method: 'POST',
    decode: ConsentStatus.fromJson,
  );
}
