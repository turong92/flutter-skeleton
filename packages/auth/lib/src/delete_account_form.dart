import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [DeleteAccountForm] (defaults are English).
class DeleteAccountLabels {
  const DeleteAccountLabels({
    this.password = 'Current password',
    this.submit = 'Delete my account',
    this.required = 'Required',
    this.wrongPassword = 'Wrong password.',
    this.code = 'Code from the email',
    this.sendCode = 'Send me a code',
    this.codeSent = 'We mailed you a code. It is valid for 10 minutes.',
    this.wrongCode = 'That code is wrong.',
    this.codeExpired = 'The code expired. Ask for a new one.',
    this.reauthFailed = 'We could not confirm it is you. Please try again.',
    this.blocked = 'Your account cannot be deleted right now. Finish or cancel what is still open, then try again.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String password;
  final String submit;
  final String required;
  final String wrongPassword;

  /// The mailed-code field and its button (accounts without a password).
  final String code;
  final String sendCode;
  final String codeSent;

  /// `400 ACCOUNT.CODE_INVALID`.
  final String wrongCode;

  /// `410 ACCOUNT.CODE_EXPIRED` (also a code asked for in another session).
  final String codeExpired;

  /// The social proof was refused or missing (`400 ACCOUNT.REAUTH_FAILED` for
  /// an account without a password, `403 ACCOUNT.REAUTH_REQUIRED`).
  final String reauthFailed;

  /// `409 ACCOUNT.DELETION_BLOCKED`: another part of the service holds the
  /// account.
  final String blocked;
  final String networkError;
  final String genericError;
}

enum _Proof { password, code, social }

/// Account deletion (Apple 5.1.1(v) wants it inside the app) with the proof
/// that fits the account, read from `GET /account/me`: the password typed again;
/// without a password but with an address, a 6-digit code mailed on request;
/// without an address, the social re-authentication the app runs in
/// [socialReauth]. While `/account/me` is unread or fails the password field
/// shows, so the form works as before.
///
/// [socialReauth] runs the provider's sign-in again and returns the
/// `socialReauth` object (`{provider, idToken | accessToken, nonce?}`), or null
/// when the person backed out. `auth` does not know the social package; the app
/// connects the two.
///
/// One submit uses one `Idempotency-Key`; pressing the button again after a
/// failure sends the same key, so a lost answer cannot schedule two deletions.
/// On `202` this device signs out locally (the server has ended the sessions)
/// and [onDeleted] runs.
class DeleteAccountForm extends ConsumerStatefulWidget {
  const DeleteAccountForm({
    super.key,
    this.onDeleted,
    this.socialReauth,
    this.labels = const DeleteAccountLabels(),
  });

  static const passwordKey = Key('skeleton_auth.delete.password');
  static const codeKey = Key('skeleton_auth.delete.code');

  final void Function(DeletionScheduled scheduled)? onDeleted;
  final Future<Map<String, Object?>?> Function()? socialReauth;
  final DeleteAccountLabels labels;

  @override
  ConsumerState<DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends ConsumerState<DeleteAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _code = TextEditingController();
  String? _key;
  var _proof = _Proof.password;
  var _codeSent = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadProof() async {
    try {
      final me = await ref.read(accountApiProvider).me();
      if (!mounted) return;
      setState(() {
        _proof = me.hasPassword
            ? _Proof.password
            : me.email != null
            ? _Proof.code
            : _Proof.social;
      });
    } catch (_) {
      // Stay on the password field; the server judges the proof anyway.
    }
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).requestDeleteConfirmation();
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    final session = ref.read(authSessionProvider.notifier);
    // Made on the first press, kept until it worked: a retry is the same submit.
    final key = _key ??= newIdempotencyKey();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, Object?>? reauth;
      if (_proof == _Proof.social) {
        reauth = await widget.socialReauth?.call();
        // The person backed out of the provider's sheet: nothing to send.
        if (widget.socialReauth != null && reauth == null) return;
      }
      final scheduled = await api.deleteAccount(
        currentPassword: _proof == _Proof.password ? _password.text : null,
        confirmationCode: _proof == _Proof.code ? _code.text.trim() : null,
        socialReauth: reauth,
        idempotencyKey: key,
      );
      await session.signOutLocally();
      widget.onDeleted?.call(scheduled);
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
      AccountErrorCodes.deletionBlocked => labels.blocked,
      AccountErrorCodes.currentPasswordInvalid => labels.wrongPassword,
      AccountErrorCodes.reauthFailed =>
        _proof == _Proof.password ? labels.wrongPassword : labels.reauthFailed,
      AccountErrorCodes.reauthRequired => labels.reauthFailed,
      AccountErrorCodes.codeInvalid => labels.wrongCode,
      AccountErrorCodes.codeExpired => labels.codeExpired,
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
          if (_proof == _Proof.password)
            TextFormField(
              key: DeleteAccountForm.passwordKey,
              controller: _password,
              decoration: InputDecoration(labelText: labels.password),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => v == null || v.isEmpty ? labels.required : null,
            ),
          if (_proof == _Proof.code) ...[
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(labels.sendCode),
            ),
            if (_codeSent) Text(labels.codeSent),
            TextFormField(
              key: DeleteAccountForm.codeKey,
              controller: _code,
              decoration: InputDecoration(labelText: labels.code),
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? labels.required : null,
            ),
          ],
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
