import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [EmailRegisterForm] and [DiscardAccountButton]. The package
/// does not translate: the app passes its own (defaults are English).
class EmailRegisterLabels {
  const EmailRegisterLabels({
    this.email = 'Email',
    this.send = 'Send code',
    this.code = 'Code from the email',
    this.confirm = 'Confirm',
    this.resend = 'Send again',
    this.required = 'Required',
    this.invalidEmail = 'That does not look like an email address.',
    this.codeFormat = 'Enter the 6 digits.',
    this.noCodeHint =
        'No code? That address may already have an account. Sign in with it '
        'and link this sign-in method in settings.',
    this.codeExpired = 'The code expired. Enter the address again.',
    this.reauthFailed = 'We could not confirm it is you. Please try again.',
    this.tooManyRequests = 'Too many tries. Please wait a while.',
    this.blocked = 'This address cannot be registered.',
    this.discard = 'Discard',
    this.discardOpen = 'I already have an account',
    this.discardTitle = 'Discard this account?',
    this.discardBody =
        'The account is deleted at once and cannot be restored. Use this '
        'only if you already have an account with another sign-in method.',
    this.discardCancel = 'Cancel',
    this.discardNotAllowed = 'This account cannot be discarded.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String email;
  final String send;
  final String code;
  final String confirm;
  final String resend;
  final String required;
  final String invalidEmail;
  final String codeFormat;

  /// Under the code step: the server answers the same whether or not another
  /// account owns the address, so a code that never comes needs this hint.
  final String noCodeHint;
  final String codeExpired;
  final String reauthFailed;
  final String tooManyRequests;

  /// `403 ACCOUNT.REGISTRATION_BLOCKED`.
  final String blocked;

  /// [DiscardAccountButton]: the confirm button, the dialog and the refusal.
  final String discard;
  final String discardOpen;
  final String discardTitle;
  final String discardBody;
  final String discardCancel;
  final String discardNotAllowed;
  final String networkError;
  final String genericError;

  String codeInvalid(int attemptsLeft) =>
      'That code is wrong. $attemptsLeft tries left.';

  String resendIn(int seconds) => 'Send again in ${seconds}s';
}

/// Registers the first address of an account that has none (`me` says
/// `emailRequired` or `emailRequiredToWrite`, or a call answered `403
/// ACCOUNT.EMAIL_REQUIRED`): the address, then the 6-digit code mailed to it.
/// The form does not navigate: [onRegistered] runs once the address is
/// confirmed. A call that was refused for want of an address is held by
/// [EmailRequiredInterceptor] and sent again by the app once [onRegistered]
/// has told the gate (see [HeldCalls]); the form itself does not send it.
///
/// An old session gets `403 ACCOUNT.REAUTH_REQUIRED` for the first address:
/// [socialReauth] runs the provider's sign-in again and returns the
/// `socialReauth` object (null = the person backed out). Without it that
/// answer reads as "could not confirm".
class EmailRegisterForm extends ConsumerStatefulWidget {
  const EmailRegisterForm({
    super.key,
    required this.onRegistered,
    this.socialReauth,
    this.labels = const EmailRegisterLabels(),
  });

  static const emailKey = Key('skeleton_auth.email_register.email');
  static const codeKey = Key('skeleton_auth.email_register.code');

  final VoidCallback onRegistered;
  final Future<Map<String, Object?>?> Function()? socialReauth;
  final EmailRegisterLabels labels;

  @override
  ConsumerState<EmailRegisterForm> createState() => _EmailRegisterFormState();
}

class _EmailRegisterFormState extends ConsumerState<EmailRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  Timer? _ticker;
  CodeIssued? _issued;
  var _busy = false;
  String? _emailError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_issued?.resendAvailableAt != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  int get _secondsToResend {
    final at = _issued?.resendAvailableAt;
    if (at == null) return 0;
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Asks for the code (the first time and a resend are the same call).
  /// A resend skips the form check (the code box is empty then, as in
  /// `VerifyCodeForm._resend`).
  Future<void> _send({bool resend = false}) async {
    if (_busy || (!resend && !_formKey.currentState!.validate())) return;
    final api = ref.read(accountApiProvider);
    // One press, one key (the reauth retry reuses it); every press a new one,
    // or the server would replay the stored answer and send no mail.
    final key = newIdempotencyKey();
    final address = _email.text.trim();
    setState(() {
      _busy = true;
      _emailError = null;
      _error = null;
    });
    try {
      CodeIssued issued;
      try {
        issued = await api.requestEmailChange(address, idempotencyKey: key);
      } on ApiRequestError catch (e) {
        final reauth = widget.socialReauth;
        if (e.code != AccountErrorCodes.reauthRequired || reauth == null) {
          rethrow;
        }
        final proof = await reauth();
        // The person backed out of the provider's sheet: nothing to send.
        if (proof == null) return;
        issued = await api.requestEmailChange(
          address,
          idempotencyKey: key,
          socialReauth: proof,
        );
      }
      if (mounted) setState(() => _issued = issued);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).confirmEmailChange(_code.text.trim());
      widget.onRegistered();
    } catch (e) {
      if (mounted) {
        if (e is ApiRequestError && e.code == AccountErrorCodes.codeExpired) {
          // A new code needs the address again.
          setState(() {
            _issued = null;
            _code.clear();
          });
        }
        _showError(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) {
      setState(() => _error = labels.genericError);
      return;
    }
    if (fieldErrorCodesOf(error, {'newEmail'}).containsKey('newEmail')) {
      setState(() => _emailError = labels.invalidEmail);
      return;
    }
    final left = attemptsLeftOf(error);
    setState(
      () => _error = left != null
          ? labels.codeInvalid(left)
          : switch (error.code) {
              AccountErrorCodes.codeExpired => labels.codeExpired,
              AccountErrorCodes.reauthRequired ||
              AccountErrorCodes.reauthFailed => labels.reauthFailed,
              'ACCOUNT.RATE_LIMITED' => labels.tooManyRequests,
              'ACCOUNT.REGISTRATION_BLOCKED' => labels.blocked,
              ClientErrorCodes.networkError => labels.networkError,
              _ => labels.genericError,
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final waiting = _issued != null;
    final wait = _secondsToResend;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: EmailRegisterForm.emailKey,
            controller: _email,
            enabled: !waiting,
            decoration: InputDecoration(
              labelText: labels.email,
              errorText: _emailError,
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => waiting ? null : _send(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return labels.required;
              return value.contains('@') ? null : labels.invalidEmail;
            },
          ),
          if (!waiting) ...[
            if (_error != null) ErrorText(_error!),
            const SizedBox(height: 16),
            SubmitButton(label: labels.send, busy: _busy, onPressed: _send),
          ] else ...[
            const SizedBox(height: 12),
            TextFormField(
              key: EmailRegisterForm.codeKey,
              controller: _code,
              decoration: InputDecoration(labelText: labels.code),
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onFieldSubmitted: (_) => _confirm(),
              validator: (v) =>
                  v != null && RegExp(r'^\d{6}$').hasMatch(v.trim())
                  ? null
                  : labels.codeFormat,
            ),
            const SizedBox(height: 8),
            Text(
              labels.noCodeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ErrorText(_error!),
            const SizedBox(height: 16),
            SubmitButton(
              label: labels.confirm,
              busy: _busy,
              onPressed: _confirm,
            ),
            if (_issued!.resendAvailableAt != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy || wait > 0 ? null : () => _send(resend: true),
                child: Text(wait > 0 ? labels.resendIn(wait) : labels.resend),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The way out of the address gate for someone who already has an account
/// with another sign-in method (a returning user whose provider sign-in made
/// an empty second account): drops this account at once (`POST
/// /account/discard`), after a confirmation, and signs out on this device.
/// [onDiscarded] runs after that. [socialReauth] is as for
/// [EmailRegisterForm].
class DiscardAccountButton extends ConsumerStatefulWidget {
  const DiscardAccountButton({
    super.key,
    this.onDiscarded,
    this.socialReauth,
    this.labels = const EmailRegisterLabels(),
  });

  final VoidCallback? onDiscarded;
  final Future<Map<String, Object?>?> Function()? socialReauth;
  final EmailRegisterLabels labels;

  @override
  ConsumerState<DiscardAccountButton> createState() =>
      _DiscardAccountButtonState();
}

class _DiscardAccountButtonState extends ConsumerState<DiscardAccountButton> {
  /// Made on the first press, kept until it worked: a retry is the same call.
  String? _key;
  var _busy = false;
  String? _error;

  Future<void> _ask() async {
    final labels = widget.labels;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labels.discardTitle),
        content: Text(labels.discardBody),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(labels.discardCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(labels.discard),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _discard();
  }

  Future<void> _discard() async {
    final api = ref.read(accountApiProvider);
    final session = ref.read(authSessionProvider.notifier);
    final key = _key ??= newIdempotencyKey();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      try {
        await api.discard(idempotencyKey: key);
      } on ApiRequestError catch (e) {
        final reauth = widget.socialReauth;
        if (e.code != AccountErrorCodes.reauthRequired || reauth == null) {
          rethrow;
        }
        final proof = await reauth();
        if (proof == null) return;
        await api.discard(socialReauth: proof, idempotencyKey: key);
      }
      await session.signOutLocally();
      widget.onDiscarded?.call();
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
      AccountErrorCodes.discardNotAllowed => labels.discardNotAllowed,
      AccountErrorCodes.reauthRequired ||
      AccountErrorCodes.reauthFailed => labels.reauthFailed,
      ClientErrorCodes.networkError => labels.networkError,
      _ => labels.genericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _busy ? null : _ask,
          child: Text(widget.labels.discardOpen),
        ),
        if (_error != null) ErrorText(_error!),
      ],
    );
  }
}
