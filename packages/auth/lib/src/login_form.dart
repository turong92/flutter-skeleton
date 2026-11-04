import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'auth_session.dart';

/// The texts of [LoginForm]. The package does not translate: the app passes its
/// own (defaults are English).
class LoginLabels {
  const LoginLabels({
    this.email = 'Email',
    this.password = 'Password',
    this.submit = 'Sign in',
    this.required = 'Required',
    this.invalidCredentials = 'Wrong email or password.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String email;
  final String password;
  final String submit;
  final String required;
  final String invalidCredentials;
  final String networkError;
  final String genericError;
}

/// Email + password sign-in. On success the session changes and the router's
/// redirect leaves the login screen; the form does not navigate.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key, this.labels = const LoginLabels()});

  static const emailKey = Key('skeleton_auth.login.email');
  static const passwordKey = Key('skeleton_auth.login.password');

  final LoginLabels labels;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) return labels.genericError;
    return switch (error.code) {
      ErrorCodes.authInvalidCredentials => labels.invalidCredentials,
      ClientErrorCodes.networkError => labels.networkError,
      _ => labels.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    String? requiredValue(String? value) =>
        value == null || value.trim().isEmpty ? labels.required : null;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: LoginForm.emailKey,
            controller: _email,
            decoration: InputDecoration(labelText: labels.email),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: requiredValue,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: LoginForm.passwordKey,
            controller: _password,
            decoration: InputDecoration(labelText: labels.password),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            validator: requiredValue,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(labels.submit),
          ),
        ],
      ),
    );
  }
}
