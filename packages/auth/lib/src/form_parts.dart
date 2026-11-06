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

  /// Korean texts, in the polite 해요 style.
  const PasswordPolicyLabels.ko()
    : this(hint: _koPasswordHint, violation: _koPasswordViolation);

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

  /// Korean texts, in the polite 해요 style.
  const DisplayNameLabels.ko()
    : this(
        label: '닉네임',
        optionalLabel: '닉네임 (선택)',
        required: '닉네임을 입력해 주세요.',
        taken: '이미 쓰는 닉네임이에요. 다른 닉네임을 정해 주세요.',
        tooLong: '닉네임이 너무 길어요 (60자까지예요).',
        invalid: '쓸 수 없는 문자가 들어 있어요.',
        reserved: '미리 정해 둔 닉네임이에요. 다른 닉네임을 정해 주세요.',
      );

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

  /// Korean texts, in the polite 해요 style.
  const LoginIdLabels.ko()
    : this(
        label: '아이디',
        hint: _koIdHint,
        required: '아이디를 입력해 주세요.',
        size: _koIdSize,
        invalid: '영문자, 숫자, . - _ 만 쓸 수 있어요 (기호가 맨 앞이나 맨 뒤, 연속으로 오면 안 되고 영문자가 하나는 있어야 해요).',
        taken: '이미 쓰는 아이디예요. 다른 아이디를 정해 주세요.',
        checking: '확인하는 중...',
        available: '쓸 수 있는 아이디예요.',
        checkUnknown: '지금은 아이디를 확인하지 못했어요. 그대로 계속할 수 있어요.',
      );

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

String _koPasswordHint(PasswordPolicy p) {
  final needs = [
    if (p.requireLetter) '영문자',
    if (p.requireDigit) '숫자',
    if (p.requireSymbol) '기호',
  ];
  return '${p.minLength}자 이상, ${p.maxBytes}바이트 이하로 정해 주세요'
      '${needs.isEmpty ? '' : '. ${needs.join(', ')}를 포함해야 해요'}.';
}

String _koPasswordViolation(PasswordViolation v) => switch (v) {
  PasswordViolation.tooShort => '비밀번호가 너무 짧아요.',
  PasswordViolation.tooLong => '비밀번호가 너무 길어요.',
  PasswordViolation.needsLetter => '비밀번호에 영문자가 필요해요.',
  PasswordViolation.needsDigit => '비밀번호에 숫자가 필요해요.',
  PasswordViolation.needsSymbol => '비밀번호에 기호가 필요해요.',
  PasswordViolation.containsEmail => '비밀번호에 이메일 앞부분을 넣을 수 없어요.',
  PasswordViolation.tooCommon => '너무 흔한 비밀번호예요.',
  PasswordViolation.breached => '유출된 적이 있는 비밀번호예요. 다른 비밀번호를 정해 주세요.',
};

String _koIdHint(LoginIdRules r) =>
    '${r.minLength}~${r.maxLength}자, 영문자 · 숫자 · . - _ 를 쓸 수 있어요';
String _koIdSize(LoginIdRules r) =>
    '아이디는 ${r.minLength}~${r.maxLength}자로 정해 주세요.';
