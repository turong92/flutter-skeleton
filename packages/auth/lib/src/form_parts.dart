import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';

/// The password rule texts of the account forms. The package does not
/// translate: the app passes its own (defaults are English).
class PasswordPolicyLabels {
  const PasswordPolicyLabels({
    this.hint = _defaultHint,
    this.violation = _defaultViolation,
  });

  /// One sentence for the rules the server reports. [PasswordPolicy.maxBytes]
  /// is UTF-8 bytes: a non-ASCII character takes two to four of them.
  final String Function(PasswordPolicy policy) hint;

  /// What to say about one broken rule.
  final String Function(PasswordViolation violation) violation;
}

String _defaultHint(PasswordPolicy p) {
  final needs = [
    if (p.requireLetter) 'a letter',
    if (p.requireDigit) 'a digit',
    if (p.requireSymbol) 'a symbol',
  ];
  return 'At least ${p.minLength} characters and at most ${p.maxBytes} bytes'
      '${needs.isEmpty ? '' : ', with ${needs.join(', ')}'}.';
}

String _defaultViolation(PasswordViolation v) => switch (v) {
  PasswordViolation.tooShort => 'The password is too short.',
  PasswordViolation.tooLong => 'The password is too long.',
  PasswordViolation.needsLetter => 'The password needs a letter.',
  PasswordViolation.needsDigit => 'The password needs a digit.',
  PasswordViolation.needsSymbol => 'The password needs a symbol.',
  PasswordViolation.containsEmail =>
    'The password must not contain the first part of the email.',
  PasswordViolation.tooCommon => 'This password is too common.',
  PasswordViolation.breached =>
    'This password appeared in a data breach. Choose another.',
};

/// The nickname texts shared by the sign-up, code and nickname forms (defaults
/// are English). `errors[].message` of the server is for logs and never shown.
class DisplayNameLabels {
  const DisplayNameLabels({
    this.label = 'Nickname',
    this.optionalLabel = 'Nickname (optional)',
    this.required = 'Enter a nickname.',
    this.taken = 'That nickname is taken. Try another.',
    this.tooLong = 'The nickname is too long (60 characters at most).',
    this.invalid = 'This nickname has characters that are not allowed.',
    this.reserved = 'This nickname is reserved. Try another.',
  });

  final String label;
  final String optionalLabel;
  final String required;
  final String taken;
  final String tooLong;
  final String invalid;
  final String reserved;

  /// The text for a field error [code] of `displayName`; null for a code this
  /// form does not know.
  String? forCode(String code) => switch (code) {
    'Required' => required,
    'Size' => tooLong,
    'Pattern' => invalid,
    'Reserved' => reserved,
    _ => null,
  };
}

/// The login ID texts shared by the sign-up, code and ID forms (defaults are
/// English). `errors[].message` of the server is for logs and never shown.
class LoginIdLabels {
  const LoginIdLabels({
    this.label = 'ID',
    this.hint = _defaultIdHint,
    this.required = 'Enter an ID.',
    this.size = _defaultIdSize,
    this.invalid =
        'Use letters, digits and . - _ (no symbol first, last or twice in a '
        'row, at least one letter).',
    this.taken = 'That ID is taken. Try another.',
    this.checking = 'Checking...',
    this.available = 'This ID is free.',
    this.checkUnknown = 'Could not check this ID now. You can still continue.',
  });

  final String label;

  /// The line under the field.
  final String Function(LoginIdRules rules) hint;
  final String required;
  final String Function(LoginIdRules rules) size;
  final String invalid;
  final String taken;
  final String checking;
  final String available;
  final String checkUnknown;

  /// The text for a field error [code] of `loginId`; null for a code this form
  /// does not know.
  String? forCode(String code, LoginIdRules? rules) => switch (code) {
    'Required' => required,
    'Size' => rules == null ? invalid : size(rules),
    'Pattern' => invalid,
    _ => null,
  };
}

String _defaultIdHint(LoginIdRules r) =>
    '${r.minLength}-${r.maxLength} characters: letters, digits, . - _';
String _defaultIdSize(LoginIdRules r) =>
    'The ID must be ${r.minLength}-${r.maxLength} characters.';

/// What to say under the ID field about [error]: `409 LOGIN_ID_TAKEN` or a
/// field error on `loginId`. Null for any other error.
String? loginIdErrorText(
  ApiRequestError error,
  LoginIdLabels labels,
  LoginIdRules? rules,
) {
  if (error.code == AccountErrorCodes.loginIdTaken) return labels.taken;
  final code = fieldErrorCodesOf(error, {'loginId'})['loginId'];
  return code == null ? null : labels.forCode(code, rules) ?? labels.invalid;
}

/// What this device can say about an ID before the server does (not blank,
/// the length of [rules]); null when there is nothing to say.
String? loginIdLocalProblem(
  String? value,
  LoginIdLabels labels,
  LoginIdRules? rules,
) {
  final id = value?.trim() ?? '';
  if (id.isEmpty) return labels.required;
  return rules != null &&
          (id.length < rules.minLength || id.length > rules.maxLength)
      ? labels.size(rules)
      : null;
}

/// The login ID text field. Checks what this device can (not blank, the
/// length of [rules]); the shape rules are the server's. [helperText] replaces
/// the hint line (the live check's answer).
class LoginIdField extends StatelessWidget {
  const LoginIdField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.labels,
    this.rules,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final LoginIdLabels labels;
  final LoginIdRules? rules;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final r = rules;
    return TextFormField(
      key: fieldKey,
      controller: controller,
      decoration: InputDecoration(
        labelText: labels.label,
        errorText: errorText,
        helperText: helperText ?? (r == null ? null : labels.hint(r)),
        helperMaxLines: 2,
        errorMaxLines: 3,
      ),
      autofillHints: const [AutofillHints.username],
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      textInputAction: textInputAction,
      validator: (v) => loginIdLocalProblem(v, labels, rules),
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// The `errors[]` of a `400 COMMON.VALIDATION_FAILED`: the first code per
/// field, only for the [fields] the form has. Empty for any other error.
Map<String, String> fieldErrorCodesOf(
  ApiRequestError error,
  Set<String> fields,
) {
  if (error.code != ErrorCodes.commonValidationFailed) return const {};
  final found = <String, String>{};
  for (final e in error.fieldErrors) {
    if (fields.contains(e.field)) found.putIfAbsent(e.field, () => e.code);
  }
  return found;
}

/// The server's password rules as one sentence under a password field. Shows
/// nothing while they load or when they cannot be read (the server still
/// checks).
class PasswordPolicyHint extends ConsumerWidget {
  const PasswordPolicyHint({
    super.key,
    this.labels = const PasswordPolicyLabels(),
  });

  final PasswordPolicyLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(passwordPolicyProvider).value;
    if (policy == null) return const SizedBox.shrink();
    return Text(
      labels.hint(policy),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// The primary button of the account forms: filled even at rest, a spinner
/// while busy.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
