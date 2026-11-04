import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
