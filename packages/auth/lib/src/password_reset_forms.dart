import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [ForgotPasswordForm] (defaults are English).
class ForgotPasswordLabels {
  const ForgotPasswordLabels({
    this.email = 'Email',
    this.submit = 'Send reset link',
    this.required = 'Required',
    this.sent = 'If an account exists for this address, a reset link is on its way.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String email;
  final String submit;
  final String required;

  /// Shown after every successful request: the answer must not tell whether
  /// the address has an account.
  final String sent;
  final String networkError;
  final String genericError;
}

/// Asks for a password-reset mail. The backend always answers 202 and so does
/// the form: [labels.sent].
class ForgotPasswordForm extends ConsumerStatefulWidget {
  const ForgotPasswordForm({
    super.key,
    this.onSent,
    this.labels = const ForgotPasswordLabels(),
  });

  static const emailKey = Key('skeleton_auth.forgot.email');

  final VoidCallback? onSent;
  final ForgotPasswordLabels labels;

  @override
  ConsumerState<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  var _busy = false;
  var _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
      widget.onSent?.call();
    } catch (e) {
      final labels = widget.labels;
      if (mounted) {
        setState(
          () => _error =
              e is ApiRequestError && e.code == ClientErrorCodes.networkError
              ? labels.networkError
              : labels.genericError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: ForgotPasswordForm.emailKey,
            controller: _email,
            decoration: InputDecoration(labelText: labels.email),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                v == null || v.trim().isEmpty ? labels.required : null,
          ),
          if (_sent) Padding(padding: const EdgeInsets.only(top: 12), child: Text(labels.sent)),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

/// The texts of [ResetPasswordForm] (defaults are English).
class ResetPasswordLabels {
  const ResetPasswordLabels({
    this.password = 'New password',
    this.submit = 'Set new password',
    this.required = 'Required',
    this.tokenInvalid = 'This link is invalid or expired. Ask for a new one.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
    this.passwordPolicy = const PasswordPolicyLabels(),
  });

  final String password;
  final String submit;
  final String required;
  final String tokenInvalid;
  final String networkError;
  final String genericError;
  final PasswordPolicyLabels passwordPolicy;
}

/// Sets a new password with the [token] of the mailed link
/// (`<link-base-url>/reset-password?token=`). The server ends every session of
/// the account, so on success this device signs out locally too, then
/// [onReset] runs (the app goes to the login screen). The token is never
/// shown, logged or put in an error text.
class ResetPasswordForm extends ConsumerStatefulWidget {
  const ResetPasswordForm({
    super.key,
    required this.token,
    this.onReset,
    this.labels = const ResetPasswordLabels(),
  });

  static const passwordKey = Key('skeleton_auth.reset.password');

  final String token;
  final VoidCallback? onReset;
  final ResetPasswordLabels labels;

  @override
  ConsumerState<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends ConsumerState<ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String? _passwordProblem(String? value) {
    final labels = widget.labels;
    if (value == null || value.isEmpty) return labels.required;
    final found = ref.read(passwordPolicyProvider).value?.violations(value);
    return found == null || found.isEmpty
        ? null
        : labels.passwordPolicy.violation(found.first);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    final session = ref.read(authSessionProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.resetPassword(
        token: widget.token,
        newPassword: _password.text,
      );
      await session.signOutLocally();
      widget.onReset?.call();
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) return labels.genericError;
    final violations = violationsOf(error);
    if (violations.isNotEmpty) {
      return labels.passwordPolicy.violation(violations.first);
    }
    return switch (error.code) {
      AccountErrorCodes.tokenInvalid => labels.tokenInvalid,
      ClientErrorCodes.networkError => labels.networkError,
      _ => labels.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: ResetPasswordForm.passwordKey,
            controller: _password,
            decoration: InputDecoration(labelText: labels.password),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _submit(),
            validator: _passwordProblem,
          ),
          const SizedBox(height: 4),
          PasswordPolicyHint(labels: labels.passwordPolicy),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
