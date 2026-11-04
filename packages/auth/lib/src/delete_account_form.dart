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
    this.blocked = 'Your account cannot be deleted right now. Finish or cancel what is still open, then try again.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String password;
  final String submit;
  final String required;
  final String wrongPassword;

  /// `409 ACCOUNT.DELETION_BLOCKED`: another part of the service holds the
  /// account.
  final String blocked;
  final String networkError;
  final String genericError;
}

/// Account deletion with the password typed again (Apple 5.1.1(v) wants it
/// inside the app). One submit uses one `Idempotency-Key`; pressing the button
/// again after a failure sends the same key, so a lost answer cannot schedule
/// two deletions. On `202` this device signs out locally (the server has ended
/// the sessions) and [onDeleted] runs.
class DeleteAccountForm extends ConsumerStatefulWidget {
  const DeleteAccountForm({
    super.key,
    this.onDeleted,
    this.labels = const DeleteAccountLabels(),
  });

  static const passwordKey = Key('skeleton_auth.delete.password');

  final void Function(DeletionScheduled scheduled)? onDeleted;
  final DeleteAccountLabels labels;

  @override
  ConsumerState<DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends ConsumerState<DeleteAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  String? _key;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
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
      final scheduled = await api.deleteAccount(
        currentPassword: _password.text,
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
      AccountErrorCodes.reauthFailed ||
      AccountErrorCodes.currentPasswordInvalid => labels.wrongPassword,
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
            key: DeleteAccountForm.passwordKey,
            controller: _password,
            decoration: InputDecoration(labelText: labels.password),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => v == null || v.isEmpty ? labels.required : null,
          ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: labels.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
