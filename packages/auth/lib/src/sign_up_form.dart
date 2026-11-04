import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [SignUpForm] (defaults are English).
class SignUpLabels {
  const SignUpLabels({
    this.email = 'Email',
    this.password = 'Password',
    this.submit = 'Create account',
    this.required = 'Required',
    this.consentRequired = 'Please accept the required terms to continue.',
    this.emailTaken = 'This email is already in use.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
    this.passwordPolicy = const PasswordPolicyLabels(),
  });

  final String email;
  final String password;
  final String submit;
  final String required;
  final String consentRequired;
  final String emailTaken;
  final String networkError;
  final String genericError;
  final PasswordPolicyLabels passwordPolicy;
}

/// What a consent widget (the `legal` package's checklist, or the app's own)
/// tells the sign-up form. The form never learns what a consent is.
class ConsentSlotController extends ChangeNotifier {
  var _ready = false;
  var _claims = const <ConsentClaim>[];

  /// False blocks the submit button (a required document is not ticked).
  bool get ready => _ready;

  /// What is sent with the sign-up.
  List<ConsentClaim> get claims => _claims;

  void update({required bool ready, List<ConsentClaim> claims = const []}) {
    _ready = ready;
    _claims = claims;
    notifyListeners();
  }
}

/// Email + password sign-up. A 202 keeps the attempt in
/// [signUpAttemptStoreProvider] and calls [onSignedUp]; the app then shows the
/// code screen ([VerifyCodeForm]). The form does not navigate.
///
/// [consentBuilder] is the place for the consent checkboxes. The slot calls
/// `controller.update(ready:, claims:)`; until it says `ready: true` the submit
/// button stays disabled. Without a builder there is no consent step.
class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({
    super.key,
    required this.onSignedUp,
    this.consentBuilder,
    this.onConsentRejected,
    this.labels = const SignUpLabels(),
  });

  static const emailKey = Key('skeleton_auth.sign_up.email');
  static const passwordKey = Key('skeleton_auth.sign_up.password');

  final void Function(SignUpOutcome outcome) onSignedUp;
  final Widget Function(BuildContext context, ConsentSlotController controller)?
  consentBuilder;

  /// The server said `LEGAL.CONSENT_REQUIRED` (a document changed meanwhile):
  /// read the documents again.
  final VoidCallback? onConsentRejected;
  final SignUpLabels labels;

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _consents = ConsentSlotController();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.consentBuilder == null) _consents.update(ready: true);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _consents.dispose();
    super.dispose();
  }

  String? _passwordProblem(String? value) {
    final labels = widget.labels;
    if (value == null || value.isEmpty) return labels.required;
    final found = ref
        .read(passwordPolicyProvider)
        .value
        ?.violations(value, email: _email.text.trim());
    return found == null || found.isEmpty
        ? null
        : labels.passwordPolicy.violation(found.first);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final api = ref.read(accountApiProvider);
    final store = ref.read(signUpAttemptStoreProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await api.signUp(
        email: _email.text.trim(),
        password: _password.text,
        consents: _consents.claims,
      );
      final attempt = outcome.attempt;
      if (attempt != null) await store.save(attempt);
      widget.onSignedUp(outcome);
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
      if (e is ApiRequestError &&
          e.code == AccountErrorCodes.legalConsentRequired) {
        widget.onConsentRejected?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final labels = widget.labels;
    if (error is! ApiRequestError) return labels.genericError;
    final violations = violationsOf(error);
    if (violations.isNotEmpty) {
      return labels.passwordPolicy.violation(violations.first);
    }
    return switch (error.code) {
      AccountErrorCodes.legalConsentRequired => labels.consentRequired,
      AccountErrorCodes.emailTaken => labels.emailTaken,
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
            key: SignUpForm.emailKey,
            controller: _email,
            decoration: InputDecoration(labelText: labels.email),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: requiredValue,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: SignUpForm.passwordKey,
            controller: _password,
            decoration: InputDecoration(labelText: labels.password),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: _passwordProblem,
          ),
          const SizedBox(height: 4),
          PasswordPolicyHint(labels: labels.passwordPolicy),
          if (widget.consentBuilder != null) ...[
            const SizedBox(height: 12),
            widget.consentBuilder!(context, _consents),
          ],
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _consents,
            builder: (context, _) => SubmitButton(
              label: labels.submit,
              busy: _busy,
              onPressed: _consents.ready ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
