/// One document in one language, as `GET /legal/documents` lists it (the
/// current version).
class LegalDocumentSummary {
  const LegalDocumentSummary({
    required this.type,
    required this.locale,
    required this.version,
    required this.title,
    required this.required,
    required this.requiredAtSignUp,
  });

  factory LegalDocumentSummary.fromJson(Map<String, Object?> json) =>
      LegalDocumentSummary(
        type: json['type']! as String,
        locale: json['locale']! as String,
        version: json['version']! as String,
        title: json['title'] as String?,
        required: json['required']! as bool,
        requiredAtSignUp: json['requiredAtSignUp']! as bool,
      );

  final String type;
  final String locale;
  final String version;
  final String? title;

  /// Everybody has to agree to it at some point.
  final bool required;

  /// It has to be agreed to before the account exists.
  final bool requiredAtSignUp;
}

/// A document with its text: markdown source, not rendered.
class LegalDocument {
  const LegalDocument({
    required this.type,
    required this.locale,
    required this.version,
    required this.title,
    required this.markdown,
  });

  factory LegalDocument.fromJson(Map<String, Object?> json) => LegalDocument(
    type: json['type']! as String,
    locale: json['locale']! as String,
    version: json['version']! as String,
    title: json['title'] as String?,
    markdown: json['markdown']! as String,
  );

  final String type;
  final String locale;
  final String version;
  final String? title;
  final String markdown;
}

/// "I agree to this version of this document", as the backend takes it: in
/// `POST /legal/consents` and in the sign-up request's `consents`.
class ConsentClaim {
  const ConsentClaim({required this.type, required this.version, this.locale});

  final String type;
  final String version;
  final String? locale;

  Map<String, String> toJson() => {
    'type': type,
    'version': version,
    'locale': ?locale,
  };
}

/// A document the caller still has to agree to (`missing[]` of the consent
/// status and of the `403 LEGAL.RECONSENT_REQUIRED` body).
class MissingConsent {
  const MissingConsent({
    required this.type,
    required this.version,
    required this.reason,
  });

  factory MissingConsent.fromJson(Map<String, Object?> json) => MissingConsent(
    type: json['type']! as String,
    version: json['version'] as String?,
    reason: json['reason'] as String? ?? '',
  );

  final String type;

  /// The version to agree to; null when the backend names none.
  final String? version;
  final String reason;
}

/// The caller's consent state (`POST /legal/consents`, `GET /legal/consents/me`).
class ConsentStatus {
  const ConsentStatus({required this.blocked, required this.missing});

  factory ConsentStatus.fromJson(Map<String, Object?> json) => ConsentStatus(
    blocked: json['blocked']! as bool,
    missing: [
      for (final item in json['missing']! as List)
        MissingConsent.fromJson(item as Map<String, Object?>),
    ],
  );

  final bool blocked;
  final List<MissingConsent> missing;
}

/// One entry of the caller's consent history (`GET /legal/consents/me/history`):
/// an agreement or a withdrawal. Consent is only ever added to, so a withdrawal
/// is an event of its own.
class ConsentEvent {
  const ConsentEvent({
    required this.type,
    required this.version,
    required this.action,
    required this.locale,
    required this.source,
    required this.at,
  });

  factory ConsentEvent.fromJson(Map<String, Object?> json) => ConsentEvent(
    type: json['type']! as String,
    version: json['version']! as String,
    action: json['action']! as String,
    locale: json['locale'] as String?,
    source: json['source'] as String?,
    at: DateTime.parse(json['at']! as String),
  );

  final String type;
  final String version;

  /// `AGREED` or `WITHDRAWN`.
  final String action;
  final String? locale;
  final String? source;
  final DateTime at;

  bool get withdrawn => action == 'WITHDRAWN';
}
