import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [ContactEmailSection] (defaults are English).
class ContactEmailLabels {
  const ContactEmailLabels({
    this.title = 'Contact email',
    this.role =
        'An optional address for announcements and service messages. It is '
        'not used to sign in or to recover the account.',
    this.none = 'No contact email yet.',
    this.add = 'Add',
    this.change = 'Change',
    this.remove = 'Remove',
    this.email = 'Email',
    this.send = 'Send code',
    this.code = 'Code from the email',
    this.confirm = 'Confirm',
    this.cancel = 'Cancel',
    this.required = 'Required',
    this.invalidEmail = 'That does not look like an email address.',
    this.codeFormat = 'Enter the 6 digits.',
    this.codeExpired = 'The code expired. Enter the address again.',
    this.reauthFailed = 'We could not confirm it is you. Please try again.',
    this.tooManyRequests = 'Too many tries. Please wait a while.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String title;
  final String role;
  final String none;
  final String add;
  final String change;
  final String remove;
  final String email;
  final String send;
  final String code;
  final String confirm;
  final String cancel;
  final String required;
  final String invalidEmail;
  final String codeFormat;
  final String codeExpired;
  final String reauthFailed;
  final String tooManyRequests;
  final String networkError;
  final String genericError;

  String codeInvalid(int attemptsLeft) =>
      'That code is wrong. $attemptsLeft tries left.';
}

/// The optional contact address of an account (announcements, service
/// messages; never sign-in or recovery). Draw it only when the server has the
/// feature on: `AccountMe.contactEmailEnabled` (the key is absent from `me`
/// otherwise). Add or change = the address, then the 6-digit code mailed to
/// it; remove is at once. [onChanged] runs after a change so the caller can
/// read `me` again.
///
/// An account with no address of its own must prove itself with the provider
/// ([socialReauth] returns the `socialReauth` object, null = backed out).
class ContactEmailSection extends ConsumerStatefulWidget {
  const ContactEmailSection({
    super.key,
    required this.contactEmail,
    this.onChanged,
    this.socialReauth,
    this.labels = const ContactEmailLabels(),
  });

  static const emailKey = Key('skeleton_auth.contact_email.email');
  static const codeKey = Key('skeleton_auth.contact_email.code');

  final String? contactEmail;
  final VoidCallback? onChanged;
  final Future<Map<String, Object?>?> Function()? socialReauth;
  final ContactEmailLabels labels;

  @override
  ConsumerState<ContactEmailSection> createState() =>
      _ContactEmailSectionState();
}

class _ContactEmailSectionState extends ConsumerState<ContactEmailSection> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _editing = false;
  var _codeSent = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    _editing = true;
    _codeSent = false;
    _error = null;
    _email.clear();
    _code.clear();
  });

  void _close() => setState(() {
    _editing = false;
    _error = null;
  });

  Future<void> _send() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    final address = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      try {
        await api.requestContactEmail(address);
      } on ApiRequestError catch (e) {
        final reauth = widget.socialReauth;
        if (e.code != AccountErrorCodes.reauthRequired || reauth == null) {
          rethrow;
        }
        final proof = await reauth();
        // The person backed out of the provider's sheet: nothing to send.
        if (proof == null) return;
        await api.requestContactEmail(address, socialReauth: proof);
      }
      if (mounted) setState(() => _codeSent = true);
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
      await ref.read(accountApiProvider).confirmContactEmail(_code.text.trim());
      if (mounted) setState(() => _editing = false);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        if (e is ApiRequestError && e.code == AccountErrorCodes.codeExpired) {
          // A new code needs the address again.
          setState(() {
            _codeSent = false;
            _code.clear();
          });
        }
        _showError(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).removeContactEmail();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) _showError(e);
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
    final left = attemptsLeftOf(error);
    setState(
      () => _error = left != null
          ? labels.codeInvalid(left)
          : switch (error.code) {
              AccountErrorCodes.codeExpired => labels.codeExpired,
              AccountErrorCodes.reauthRequired ||
              AccountErrorCodes.reauthFailed => labels.reauthFailed,
              'ACCOUNT.RATE_LIMITED' => labels.tooManyRequests,
              ClientErrorCodes.networkError => labels.networkError,
              _ => labels.genericError,
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final current = widget.contactEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(labels.role, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (!_editing) ...[
          Text(current ?? labels.none),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _open,
                child: Text(current == null ? labels.add : labels.change),
              ),
              if (current != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _remove,
                  child: Text(labels.remove),
                ),
              ],
            ],
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: ContactEmailSection.emailKey,
                  controller: _email,
                  enabled: !_codeSent,
                  decoration: InputDecoration(labelText: labels.email),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _codeSent ? null : _send(),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return labels.required;
                    return value.contains('@') ? null : labels.invalidEmail;
                  },
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ContactEmailSection.codeKey,
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
                ],
                if (_error != null) ErrorText(_error!),
                const SizedBox(height: 16),
                SubmitButton(
                  label: _codeSent ? labels.confirm : labels.send,
                  busy: _busy,
                  onPressed: _codeSent ? _confirm : _send,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _close,
                  child: Text(labels.cancel),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
