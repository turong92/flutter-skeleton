import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [VerifyCodeForm] (defaults are English).
class VerifyCodeLabels {
  const VerifyCodeLabels({
    this.code = 'Code from the email',
    this.submit = 'Verify',
    this.resend = 'Send a new code',
    this.resendIn = _defaultResendIn,
    this.codeInvalid = _defaultCodeInvalid,
    this.codeExpired = 'This code expired. Start the sign-up again.',
    this.codeFormat = 'Enter the 6-digit code.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
    this.displayName = const DisplayNameLabels(),
  });

  final DisplayNameLabels displayName;
  final String code;
  final String submit;
  final String resend;

  /// Seconds left until the resend button works.
  final String Function(int seconds) resendIn;

  /// [attemptsLeft] tries remain after a wrong code.
  final String Function(int attemptsLeft) codeInvalid;
  final String codeExpired;
  final String codeFormat;
  final String networkError;
  final String genericError;
}

String _defaultResendIn(int seconds) => 'Send a new code in $seconds s';
String _defaultCodeInvalid(int left) =>
    'Wrong code. $left ${left == 1 ? 'try' : 'tries'} left.';

/// The 6-digit code screen of a sign-up. A right code is the login: the
/// session signs in, the attempt is removed and [onVerified] runs: the app
/// navigates there (the sign-up pages are in `publicPaths`, so a signed-in
/// session does not leave them by itself).
///
/// `409 ACCOUNT.DISPLAY_NAME_TAKEN` (the code was right, the nickname is not
/// free) does not use up the attempt: a nickname field appears and the next
/// submit repeats the same `signUpId` and code with the new nickname.
///
/// The resend countdown runs on the device clock; the server decides (`410
/// CODE_EXPIRED` removes the attempt and calls [onExpired]). A null
/// `resendAvailableAt` means no further mail: there is no resend button.
class VerifyCodeForm extends ConsumerStatefulWidget {
  const VerifyCodeForm({
    super.key,
    required this.attempt,
    this.onVerified,
    this.onExpired,
    this.labels = const VerifyCodeLabels(),
    this.now = DateTime.now,
  });

  static const codeKey = Key('skeleton_auth.verify.code');
  static const displayNameKey = Key('skeleton_auth.verify.display_name');

  final SignUpAttempt attempt;
  final VoidCallback? onVerified;
  final VoidCallback? onExpired;
  final VerifyCodeLabels labels;

  /// The clock, replaceable in tests.
  final DateTime Function() now;

  @override
  ConsumerState<VerifyCodeForm> createState() => _VerifyCodeFormState();
}

class _VerifyCodeFormState extends ConsumerState<VerifyCodeForm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _displayName = TextEditingController();
  late SignUpAttempt _attempt = widget.attempt;
  Timer? _ticker;
  var _busy = false;
  String? _error;

  /// The nickname field shows once the server refused the nickname.
  var _askName = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_attempt.resendAvailableAt != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _displayName.dispose();
    super.dispose();
  }

  int _secondsToResend() {
    final at = _attempt.resendAvailableAt;
    if (at == null) return 0;
    final ms = at.difference(widget.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> _verify() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    final session = ref.read(authSessionProvider.notifier);
    final store = ref.read(signUpAttemptStoreProvider);
    setState(() {
      _busy = true;
      _error = null;
      _nameError = null;
    });
    try {
      final result = await api.verifyEmail(
        signUpId: _attempt.signUpId,
        code: _code.text.trim(),
        displayName: _askName ? _displayName.text.trim() : null,
      );
      await store.clear();
      await session.signInWith(result);
      widget.onVerified?.call();
    } catch (e) {
      if (e is ApiRequestError && e.code == AccountErrorCodes.codeExpired) {
        await store.clear();
        widget.onExpired?.call();
      }
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    final api = ref.read(accountApiProvider);
    final store = ref.read(signUpAttemptStoreProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issued = await api.resendVerification(_attempt.signUpId);
      final next = _attempt.withWindow(issued);
      await store.save(next);
      if (mounted) setState(() => _attempt = next);
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    final labels = widget.labels.displayName;
    if (error is ApiRequestError) {
      if (error.code == AccountErrorCodes.displayNameTaken) {
        setState(() {
          _askName = true;
          _nameError = labels.taken;
        });
        return;
      }
      final code = fieldErrorCodesOf(error, {'displayName'})['displayName'];
      if (code != null) {
        setState(() {
          _askName = true;
          _nameError = labels.forCode(code) ?? widget.labels.genericError;
        });
        return;
      }
    }
    setState(() => _error = _messageFor(error));
  }

  String _messageFor(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) return labels.genericError;
    final left = attemptsLeftOf(error);
    if (left != null) return labels.codeInvalid(left);
    return switch (error.code) {
      AccountErrorCodes.codeExpired => labels.codeExpired,
      ClientErrorCodes.networkError => labels.networkError,
      _ => labels.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final wait = _secondsToResend();
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: VerifyCodeForm.codeKey,
            controller: _code,
            decoration: InputDecoration(labelText: labels.code),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onFieldSubmitted: (_) => _verify(),
            validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v.trim())
                ? null
                : labels.codeFormat,
          ),
          if (_askName) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: VerifyCodeForm.displayNameKey,
              controller: _displayName,
              decoration: InputDecoration(
                labelText: labels.displayName.label,
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              validator: (v) => v == null || v.trim().isEmpty
                  ? labels.displayName.required
                  : null,
            ),
          ],
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _verify),
          if (_attempt.resendAvailableAt != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy || wait > 0 ? null : _resend,
              child: Text(wait > 0 ? labels.resendIn(wait) : labels.resend),
            ),
          ],
        ],
      ),
    );
  }
}
