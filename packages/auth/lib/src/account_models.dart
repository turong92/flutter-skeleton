import 'dart:convert';

import 'package:skeleton_api_client/skeleton_api_client.dart';

/// Error codes of the backend `account` module (and the legal gate on sign-up)
/// that the forms branch on.
abstract final class AccountErrorCodes {
  static const codeInvalid = 'ACCOUNT.CODE_INVALID';
  static const codeExpired = 'ACCOUNT.CODE_EXPIRED';
  static const tokenInvalid = 'ACCOUNT.TOKEN_INVALID';
  static const passwordPolicy = 'ACCOUNT.PASSWORD_POLICY';
  static const currentPasswordInvalid = 'ACCOUNT.CURRENT_PASSWORD_INVALID';
  static const reauthFailed = 'ACCOUNT.REAUTH_FAILED';
  static const deletionBlocked = 'ACCOUNT.DELETION_BLOCKED';
  static const emailTaken = 'ACCOUNT.EMAIL_TAKEN';

  /// From the `legal` module: sign-up without a required consent.
  static const legalConsentRequired = 'LEGAL.CONSENT_REQUIRED';
}

/// One consent sent with the sign-up: the document type and the exact version
/// the person saw. The `legal` package builds these; auth does not know it.
class ConsentClaim {
  const ConsentClaim({required this.type, required this.version, this.locale});

  final String type;
  final String version;
  final String? locale;

  Map<String, Object?> toJson() => {
    'type': type,
    'version': version,
    'locale': ?locale,
  };
}

/// A sign-up that waits for the mailed code. Kept in a [SignUpAttemptStore] so
/// the code screen can come back after the OS killed the app.
class SignUpAttempt {
  const SignUpAttempt({
    required this.signUpId,
    required this.expiresAt,
    this.resendAvailableAt,
  });

  factory SignUpAttempt.fromJson(Map<String, Object?> json) => SignUpAttempt(
    signUpId: json['signUpId']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    resendAvailableAt: _time(json['resendAvailableAt']),
  );

  final String signUpId;
  final DateTime expiresAt;

  /// Null = the backend does not allow another mail for this attempt: hide the
  /// resend button.
  final DateTime? resendAvailableAt;

  Map<String, Object?> toJson() => {
    'signUpId': signUpId,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'resendAvailableAt': resendAvailableAt?.toUtc().toIso8601String(),
  };

  SignUpAttempt withWindow(CodeIssued issued) => SignUpAttempt(
    signUpId: signUpId,
    expiresAt: issued.expiresAt,
    resendAvailableAt: issued.resendAvailableAt,
  );

  /// Never print the attempt: the id is half of what finishes a sign-up.
  @override
  String toString() => 'SignUpAttempt(<redacted>)';

  String encode() => jsonEncode(toJson());
}

enum SignUpStatus {
  /// `202`: a code was mailed (also when the address already has an account).
  verificationSent,

  /// `201`: email verification is switched off, the account exists.
  created,
}

class SignUpOutcome {
  const SignUpOutcome({required this.status, this.attempt});

  factory SignUpOutcome.fromJson(Map<String, Object?> json) {
    final status = json['status'];
    final id = json['signUpId'];
    final expires = _time(json['expiresAt']);
    return SignUpOutcome(
      status: status == 'CREATED'
          ? SignUpStatus.created
          : SignUpStatus.verificationSent,
      attempt: id is String && expires != null
          ? SignUpAttempt(
              signUpId: id,
              expiresAt: expires,
              resendAvailableAt: _time(json['resendAvailableAt']),
            )
          : null,
    );
  }

  final SignUpStatus status;
  final SignUpAttempt? attempt;
}

/// `CodeIssuedResponse`: a code was mailed. [resendAvailableAt] null means no
/// further mail (limit reached).
class CodeIssued {
  const CodeIssued({required this.expiresAt, this.resendAvailableAt});

  factory CodeIssued.fromJson(Map<String, Object?> json) => CodeIssued(
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    resendAvailableAt: _time(json['resendAvailableAt']),
  );

  final DateTime expiresAt;
  final DateTime? resendAvailableAt;
}

class DeletionScheduled {
  const DeletionScheduled({required this.purgeAfter});

  factory DeletionScheduled.fromJson(Map<String, Object?> json) =>
      DeletionScheduled(
        purgeAfter: DateTime.parse(json['purgeAfter']! as String),
      );

  final DateTime purgeAfter;
}

enum PasswordViolation {
  tooShort,
  tooLong,
  needsLetter,
  needsDigit,
  needsSymbol,
  containsEmail,
  tooCommon,
  breached;

  /// `data.violations` of `ACCOUNT.PASSWORD_POLICY` use the Kotlin names.
  static PasswordViolation? fromServer(Object? name) => switch (name) {
    'TOO_SHORT' => tooShort,
    'TOO_LONG' => tooLong,
    'NEEDS_LETTER' => needsLetter,
    'NEEDS_DIGIT' => needsDigit,
    'NEEDS_SYMBOL' => needsSymbol,
    'CONTAINS_EMAIL' => containsEmail,
    'TOO_COMMON' => tooCommon,
    'BREACHED' => breached,
    _ => null,
  };
}

/// `GET /account/password/policy`. [maxBytes] counts UTF-8 **bytes**, not
/// characters; [minLength] counts characters.
class PasswordPolicy {
  const PasswordPolicy({
    required this.minLength,
    required this.maxBytes,
    required this.requireLetter,
    required this.requireDigit,
    required this.requireSymbol,
    required this.forbidEmailLocalPart,
  });

  factory PasswordPolicy.fromJson(Map<String, Object?> json) => PasswordPolicy(
    minLength: json['minLength']! as int,
    maxBytes: json['maxBytes']! as int,
    requireLetter: json['requireLetter']! as bool,
    requireDigit: json['requireDigit']! as bool,
    requireSymbol: json['requireSymbol']! as bool,
    forbidEmailLocalPart: json['forbidEmailLocalPart']! as bool,
  );

  final int minLength;
  final int maxBytes;
  final bool requireLetter;
  final bool requireDigit;
  final bool requireSymbol;
  final bool forbidEmailLocalPart;

  /// The rules this device can check (the server also knows common and
  /// breached passwords and stays the judge).
  List<PasswordViolation> violations(String password, {String? email}) {
    final found = <PasswordViolation>[];
    if (password.runes.length < minLength) {
      found.add(PasswordViolation.tooShort);
    }
    if (utf8.encode(password).length > maxBytes) {
      found.add(PasswordViolation.tooLong);
    }
    if (requireLetter && !RegExp(r'\p{L}', unicode: true).hasMatch(password)) {
      found.add(PasswordViolation.needsLetter);
    }
    if (requireDigit && !RegExp(r'\p{Nd}', unicode: true).hasMatch(password)) {
      found.add(PasswordViolation.needsDigit);
    }
    if (requireSymbol &&
        !RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true).hasMatch(password)) {
      found.add(PasswordViolation.needsSymbol);
    }
    if (forbidEmailLocalPart && email != null) {
      final local = email.split('@').first.toLowerCase();
      // The server ignores a very short local part.
      if (local.length >= 3 && password.toLowerCase().contains(local)) {
        found.add(PasswordViolation.containsEmail);
      }
    }
    return found;
  }
}

/// `data.attemptsLeft` of `ACCOUNT.CODE_INVALID`; null for anything else.
int? attemptsLeftOf(ApiRequestError error) {
  if (error.code != AccountErrorCodes.codeInvalid) return null;
  final data = error.apiError.data;
  final left = data is Map ? data['attemptsLeft'] : null;
  return left is int ? left : null;
}

/// `data.violations` of `ACCOUNT.PASSWORD_POLICY`; empty for anything else.
List<PasswordViolation> violationsOf(ApiRequestError error) {
  if (error.code != AccountErrorCodes.passwordPolicy) return const [];
  final data = error.apiError.data;
  final list = data is Map ? data['violations'] : null;
  if (list is! List) return const [];
  return [for (final name in list) ?PasswordViolation.fromServer(name)];
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.parse(value) : null;
