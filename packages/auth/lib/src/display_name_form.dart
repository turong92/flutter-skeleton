import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// Picks a nickname for an account that has none (`GET /account/me` says
/// `displayName: null`: a social sign-up, or a server that generates none) or
/// changes it (`PATCH /account/me`). The form does not navigate: [onSaved]
/// gets the account as the server now has it.
class DisplayNameForm extends ConsumerStatefulWidget {
  const DisplayNameForm({
    super.key,
    required this.onSaved,
    this.initial,
    this.submit = 'Save',
    this.labels = const DisplayNameLabels(),
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  static const fieldKey = Key('skeleton_auth.display_name.field');

  final void Function(AccountMe account) onSaved;

  /// The current nickname, when changing one.
  final String? initial;
  final String submit;
  final DisplayNameLabels labels;
  final String networkError;
  final String genericError;

  @override
  ConsumerState<DisplayNameForm> createState() => _DisplayNameFormState();
}

class _DisplayNameFormState extends ConsumerState<DisplayNameForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  var _busy = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    setState(() {
      _busy = true;
      _fieldError = null;
      _error = null;
    });
    try {
      final me = await api.updateDisplayName(_name.text.trim());
      widget.onSaved(me);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) {
      setState(() => _error = widget.genericError);
      return;
    }
    if (error.code == AccountErrorCodes.displayNameTaken) {
      setState(() => _fieldError = labels.taken);
      return;
    }
    final code = fieldErrorCodesOf(error, {'displayName'})['displayName'];
    final text = code == null ? null : labels.forCode(code);
    setState(() {
      if (text != null) {
        _fieldError = text;
      } else {
        _error = error.code == ClientErrorCodes.networkError
            ? widget.networkError
            : widget.genericError;
      }
    });
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
            key: DisplayNameForm.fieldKey,
            controller: _name,
            decoration: InputDecoration(
              labelText: labels.label,
              errorText: _fieldError,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                v == null || v.trim().isEmpty ? labels.required : null,
          ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: widget.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
