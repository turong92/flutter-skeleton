import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
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
    this.loginIdOrEmail = 'ID or email',
    this.invalidCredentialsWithLoginId = 'Wrong ID, email or password.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  /// Korean texts, in the polite 해요 style.
  const LoginLabels.ko()
    : this(
        email: '이메일',
        password: '비밀번호',
        submit: '로그인',
        required: '입력해 주세요',
        invalidCredentials: '이메일이나 비밀번호가 맞지 않아요.',
        loginIdOrEmail: '아이디 또는 이메일',
        invalidCredentialsWithLoginId: '아이디, 이메일 또는 비밀번호가 맞지 않아요.',
        networkError: '연결할 수 없어요. 인터넷 연결을 확인해 주세요.',
        genericError: '문제가 생겼어요. 다시 시도해 주세요.',
      );

  final String email;
  final String password;
  final String submit;
  final String required;
  final String invalidCredentials;

  /// The first field's label and the wrong-password text while the server has
  /// login IDs on (`GET /auth/methods` has a `loginId` key); [email] and
  /// [invalidCredentials] otherwise.
  final String loginIdOrEmail;
  final String invalidCredentialsWithLoginId;
  final String networkError;
  final String genericError;
}

/// Email (or login ID, when the server has them on) + password sign-in. On success the session changes and the router's
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
      final input = _email.text.trim();
      // With login IDs on, an input without `@` is an ID (the server reads a
      // `username` that way); otherwise it is always an email.
      final asId =
          ref.read(authMethodsProvider).value?.loginId != null &&
          !input.contains('@');
      await ref
          .read(authSessionProvider.notifier)
          .login(
            email: asId ? null : input,
            username: asId ? input : null,
            password: _password.text,
          );
    } catch (e) {
      // A deletion grace is not an error: the app shows the offer to cancel it
      // (`pendingDeletionProvider`).
      if (mounted && deletionPendingOf(e) == null) {
        setState(() => _error = _messageFor(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) return labels.genericError;
    final withId = ref.read(authMethodsProvider).value?.loginId != null;
    return switch (error.code) {
      ErrorCodes.authInvalidCredentials =>
        withId
            ? labels.invalidCredentialsWithLoginId
            : labels.invalidCredentials,
      ClientErrorCodes.networkError => labels.networkError,
      _ => labels.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final withId = ref.watch(authMethodsProvider).value?.loginId != null;
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
            decoration: InputDecoration(
              labelText: withId ? labels.loginIdOrEmail : labels.email,
            ),
            keyboardType: withId
                ? TextInputType.text
                : TextInputType.emailAddress,
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
