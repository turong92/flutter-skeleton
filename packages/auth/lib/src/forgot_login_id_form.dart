import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [ForgotLoginIdForm] (defaults are English).
class ForgotLoginIdLabels {
  const ForgotLoginIdLabels({
    this.email = 'Email',
    this.submit = 'Send my ID',
    this.required = 'Required',
    this.invalidEmail = 'That does not look like an email address.',
    this.sent =
        'If an account exists for this address, a mail with its ID is on its '
        'way.',
    this.tooManyRequests = 'Too many tries. Please wait a while.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String email;
  final String submit;
  final String required;
  final String invalidEmail;

  /// Shown after every successful request: the answer must not tell whether
  /// the address has an account.
  final String sent;
  final String tooManyRequests;
  final String networkError;
  final String genericError;
}

/// Asks for the "your ID is ..." mail (`POST /account/login-id/forgot`). The
/// backend always answers 202 and so does the form: [labels.sent]. Offer it
/// only where the server has login IDs on (`authMethodsProvider` has the
/// `loginId` key).
class ForgotLoginIdForm extends ConsumerStatefulWidget {
  const ForgotLoginIdForm({
    super.key,
    this.labels = const ForgotLoginIdLabels(),
  });

  static const emailKey = Key('skeleton_auth.forgot_login_id.email');

  final ForgotLoginIdLabels labels;

  @override
  ConsumerState<ForgotLoginIdForm> createState() => _ForgotLoginIdFormState();
}

class _ForgotLoginIdFormState extends ConsumerState<ForgotLoginIdForm> {
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
      await api.forgotLoginId(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      final labels = widget.labels;
      if (mounted) {
        setState(
          () => _error = e is! ApiRequestError
              ? labels.genericError
              : switch (e.code) {
                  'ACCOUNT.RATE_LIMITED' => labels.tooManyRequests,
                  ClientErrorCodes.networkError => labels.networkError,
                  _ => labels.genericError,
                },
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
            key: ForgotLoginIdForm.emailKey,
            controller: _email,
            decoration: InputDecoration(labelText: labels.email),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return labels.required;
              return value.contains('@') ? null : labels.invalidEmail;
            },
          ),
          if (_sent)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(labels.sent),
            ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
