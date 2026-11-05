import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// Chooses the login ID of an account that has none (`GET /account/me` says
/// `loginId: null` or any call answers `403 ACCOUNT.LOGIN_ID_REQUIRED`): the
/// ID is chosen once, there is no change. The form does not navigate:
/// [onSaved] gets the account as the server now has it.
///
/// While the person types, the server is asked whether the ID is free (after
/// 400 ms without typing, only for an ID that passes the length rules). That is
/// advice, not a reservation: the claim decides again, and a `409
/// LOGIN_ID_TAKEN` shows under the field. `409 LOGIN_ID_ALREADY_SET` (chosen on
/// another device meanwhile) calls [onAlreadySet].
class LoginIdForm extends ConsumerStatefulWidget {
  const LoginIdForm({
    super.key,
    required this.onSaved,
    this.onAlreadySet,
    this.submit = 'Save',
    this.labels = const LoginIdLabels(),
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  static const fieldKey = Key('skeleton_auth.login_id.field');

  final void Function(AccountMe account) onSaved;
  final VoidCallback? onAlreadySet;
  final String submit;
  final LoginIdLabels labels;
  final String networkError;
  final String genericError;

  @override
  ConsumerState<LoginIdForm> createState() => _LoginIdFormState();
}

class _LoginIdFormState extends ConsumerState<LoginIdForm> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  Timer? _timer;

  /// Bumped on every edit: an answer for an older value is dropped.
  var _generation = 0;
  var _busy = false;
  String? _fieldError;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _id.dispose();
    super.dispose();
  }

  LoginIdRules? get _rules => ref.read(authMethodsProvider).value?.loginId;

  void _edited(String value) {
    _timer?.cancel();
    final mine = ++_generation;
    final fine = loginIdLocalProblem(value, widget.labels, _rules) == null;
    setState(() {
      _fieldError = null;
      _status = fine ? widget.labels.checking : null;
    });
    if (!fine) return;
    _timer = Timer(
      const Duration(milliseconds: 400),
      () => _check(value, mine),
    );
  }

  Future<void> _check(String value, int mine) async {
    final labels = widget.labels;
    String? status;
    String? fieldError;
    try {
      final answer = await ref
          .read(accountApiProvider)
          .checkLoginId(value.trim());
      if (answer.available) {
        status = labels.available;
      } else if (answer.reason == 'TAKEN') {
        fieldError = labels.taken;
      } else {
        fieldError =
            labels.forCode(answer.code ?? '', _rules) ?? labels.invalid;
      }
    } catch (_) {
      // Rate limit, offline, anything: not a refusal. The claim decides.
      status = labels.checkUnknown;
    }
    if (!mounted || mine != _generation) return;
    setState(() {
      _status = status;
      _fieldError = fieldError;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    _timer?.cancel();
    _generation++;
    setState(() {
      _busy = true;
      _fieldError = null;
      _status = null;
      _error = null;
    });
    try {
      widget.onSaved(await api.setLoginId(_id.text.trim()));
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (error is ApiRequestError) {
      if (error.code == AccountErrorCodes.loginIdAlreadySet &&
          widget.onAlreadySet != null) {
        widget.onAlreadySet!();
        return;
      }
      final text = loginIdErrorText(error, widget.labels, _rules);
      if (text != null) {
        setState(() => _fieldError = text);
        return;
      }
      if (error.code == ClientErrorCodes.networkError) {
        setState(() => _error = widget.networkError);
        return;
      }
    }
    setState(() => _error = widget.genericError);
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(authMethodsProvider).value?.loginId;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginIdField(
            fieldKey: LoginIdForm.fieldKey,
            controller: _id,
            labels: widget.labels,
            rules: rules,
            errorText: _fieldError,
            helperText: _status,
            textInputAction: TextInputAction.done,
            onChanged: _edited,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SubmitButton(label: widget.submit, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
