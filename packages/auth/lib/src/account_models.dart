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
  static const reauthRequired = 'ACCOUNT.REAUTH_REQUIRED';
  static const deletionBlocked = 'ACCOUNT.DELETION_BLOCKED';
  static const emailTaken = 'ACCOUNT.EMAIL_TAKEN';
  static const displayNameTaken = 'ACCOUNT.DISPLAY_NAME_TAKEN';
  static const loginIdTaken = 'ACCOUNT.LOGIN_ID_TAKEN';
  static const loginIdRequired = 'ACCOUNT.LOGIN_ID_REQUIRED';
  static const loginIdAlreadySet = 'ACCOUNT.LOGIN_ID_ALREADY_SET';
  static const emailRequired = 'ACCOUNT.EMAIL_REQUIRED';
  static const discardNotAllowed = 'ACCOUNT.DISCARD_NOT_ALLOWED';

  /// 403 on a sign-in whose proof was right while the account is in its
  /// deletion grace (an `AUTH.` code that only the account flows read).
  static const deletionPending = 'AUTH.ACCOUNT_DELETION_PENDING';

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

/// What `GET /account/me` says about how the person can prove who they are:
/// a password, else the address (mailed code), else only a social provider.
class AccountMe {
  const AccountMe({
    required this.hasPassword,
    this.email,
    this.displayName,
    this.displayTag,
    this.loginId,
    this.loginIdRequired = false,
    this.contactEmail,
    this.contactEmailEnabled = false,
    this.emailRequired = false,
    this.emailRequiredToWrite = false,
    this.avatarEnabled = false,
    this.avatarKey,
    this.avatar,
  });

  factory AccountMe.fromJson(Map<String, Object?> json) => AccountMe(
    hasPassword: json['hasPassword'] == true,
    email: json['email'] as String?,
    displayName: json['displayName'] as String?,
    displayTag: json['displayTag'] as String?,
    loginId: json['loginId'] as String?,
    // The key exists only on a server with login IDs on; null = not chosen.
    loginIdRequired: json.containsKey('loginId') && json['loginId'] == null,
    // The key exists only when the server runs the contact-email feature.
    contactEmail: json['contactEmail'] as String?,
    contactEmailEnabled: json.containsKey('contactEmail'),
    emailRequired: json['emailRequired'] == true,
    emailRequiredToWrite: json['emailRequiredToWrite'] == true,
    // The keys exist only on a server with the `storage` module.
    avatarEnabled: json.containsKey('avatarKey'),
    avatarKey: json['avatarKey'] as String?,
    avatar: json['avatar'] is Map<String, Object?>
        ? AccountAvatar.fromJson(json['avatar']! as Map<String, Object?>)
        : null,
  );

  final bool hasPassword;

  /// False when the server has no `storage` module: `avatarKey` is absent from
  /// `me`, a `PATCH` carrying it is refused, and no picture slot is drawn.
  final bool avatarEnabled;

  /// The upload key of the profile picture (this caller only); null = none yet.
  final String? avatarKey;

  /// How to draw the picture; null without one.
  final AccountAvatar? avatar;

  /// The confirmed contact address (notices and service messages only, never
  /// sign-in or recovery); null = none yet.
  final String? contactEmail;

  /// False when the server has the contact-email feature off: the key is
  /// absent from `me`, so the section is not drawn.
  final bool contactEmailEnabled;
  final String? email;

  /// The account's login ID; null without one or on a server without IDs.
  final String? loginId;

  /// True when the server has login IDs on and this account has not chosen
  /// one: it answers `403 ACCOUNT.LOGIN_ID_REQUIRED` until it does.
  final bool loginIdRequired;

  /// True when the server wants an address right after sign-in (`emailRequired`
  /// in `me`): it answers `403 ACCOUNT.EMAIL_REQUIRED` to everything outside
  /// its allow list, reads included. False when the key is absent too.
  final bool emailRequired;

  /// True when the server wants the address only for changes
  /// (`emailRequiredToWrite`): reads pass, a write is refused with `403
  /// ACCOUNT.EMAIL_REQUIRED`. Tell the person before a write screen opens.
  final bool emailRequiredToWrite;

  /// Null = the account has no nickname yet (a social sign-up, or the server
  /// generates none): the app asks for one ([DisplayNameForm]).
  final String? displayName;

  /// The four digits that tell equal nicknames apart; null unless the server
  /// runs `uniqueness: TAGGED`.
  final String? displayTag;

  /// `name#tag` when there is a tag, the bare name otherwise, null without a
  /// nickname.
  String? get displayLabel => displayName == null
      ? null
      : displayTag == null
      ? displayName
      : '$displayName#$displayTag';
}

/// `me.avatar`: with the storage public area on, [url] is the public address
/// and [image] the converted copies (images whose copies are ready); [pending]
/// while the server converts. All three empty = nothing public to show.
class AccountAvatar {
  const AccountAvatar({this.url, this.image, this.pending = false});

  factory AccountAvatar.fromJson(Map<String, Object?> json) {
    final image = json['image'];
    return AccountAvatar(
      url: json['url'] as String?,
      image: image is Map<String, Object?>
          ? AccountAvatarImage.fromJson(image)
          : null,
      pending: json['pending'] == true,
    );
  }

  final String? url;
  final AccountAvatarImage? image;
  final bool pending;

  /// The best small address to draw, or null.
  String? get thumbUrl => image?.thumb ?? url;
}

class AccountAvatarImage {
  const AccountAvatarImage({
    required this.thumb,
    required this.display,
    this.width,
    this.height,
  });

  factory AccountAvatarImage.fromJson(Map<String, Object?> json) =>
      AccountAvatarImage(
        thumb: json['thumb']! as String,
        display: json['display']! as String,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
      );

  final String thumb;
  final String display;
  final int? width;
  final int? height;
}

/// `GET /account/me/avatar`: a signed address that works for a short while. Do
/// not keep it.
class AvatarAddress {
  const AvatarAddress({required this.url, required this.expiresInSeconds});

  factory AvatarAddress.fromJson(Map<String, Object?> json) => AvatarAddress(
    url: json['url']! as String,
    expiresInSeconds: (json['expiresInSeconds']! as num).toInt(),
  );

  final String url;
  final int expiresInSeconds;
}

/// What `403 AUTH.ACCOUNT_DELETION_PENDING` says: the account is in its
/// deletion grace. [restoreToken] comes only when the server runs
/// `deletion.self-restore`; without it the person is only told the date.
///
/// The token is single-use proof of a correct sign-in: keep it in memory only
/// (`pendingDeletionProvider`), never in a store, a route, a log or an error
/// message. [toString] hides it.
class DeletionPending {
  const DeletionPending({this.purgeAfter, this.restoreToken});

  /// The account's data is erased at this time.
  final DateTime? purgeAfter;
  final String? restoreToken;

  @override
  String toString() => 'DeletionPending(<redacted>)';
}

/// The pending deletion [error] reports, or null for any other error.
DeletionPending? deletionPendingOf(Object error) {
  if (error is! ApiRequestError ||
      error.code != AccountErrorCodes.deletionPending) {
    return null;
  }
  final data = error.apiError.data;
  final token = data is Map ? data['restoreToken'] : null;
  return DeletionPending(
    purgeAfter: data is Map ? _time(data['purgeAfter']) : null,
    restoreToken: token is String && token.isNotEmpty ? token : null,
  );
}

/// The length rules of a login ID, from `GET /auth/methods`. The shape rules
/// (letters, digits, `.` `-` `_`) are the server's to judge.
class LoginIdRules {
  const LoginIdRules({required this.minLength, required this.maxLength});

  final int minLength;
  final int maxLength;
}

/// What `GET /auth/methods` says that the account forms use. [loginId] is null
/// unless the server has login IDs on (a missing or unusable key = off).
class AuthMethods {
  const AuthMethods({this.loginId});

  factory AuthMethods.fromJson(Map<String, Object?> json) {
    final rules = json['loginId'];
    final min = rules is Map ? rules['minLength'] : null;
    final max = rules is Map ? rules['maxLength'] : null;
    return AuthMethods(
      loginId: min is int && max is int && min >= 1 && min <= max
          ? LoginIdRules(minLength: min, maxLength: max)
          : null,
    );
  }

  final LoginIdRules? loginId;
}

/// `POST /account/login-id/availability`. "Free" is not a reservation: the
/// claim decides again.
class LoginIdAvailability {
  const LoginIdAvailability({required this.available, this.reason, this.code});

  factory LoginIdAvailability.fromJson(Map<String, Object?> json) =>
      LoginIdAvailability(
        available: json['available'] == true,
        reason: json['reason'] as String?,
        code: json['code'] as String?,
      );

  final bool available;

  /// `INVALID` or `TAKEN` when not [available].
  final String? reason;

  /// `Required` · `Size` · `Pattern`, with `INVALID`.
  final String? code;
}

/// Whether the sign-up form asks for a nickname. The server does not say, so
/// the app picks the mode that matches its own server settings
/// (`required-on-sign-up`).
enum DisplayNameMode { none, optional, required }

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
