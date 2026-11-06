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
    this.invalidValue = 'Check this value.',
    this.emailTaken = 'This email is already in use.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
    this.passwordPolicy = const PasswordPolicyLabels(),
    this.displayName = const DisplayNameLabels(),
    this.loginId = const LoginIdLabels(),
  });

  /// Korean texts, in the polite 해요 style.
  const SignUpLabels.ko()
    : this(
        email: '이메일',
        password: '비밀번호',
        submit: '가입하기',
        required: '입력해 주세요',
        consentRequired: '필수 약관에 동의해 주세요.',
        invalidValue: '값을 확인해 주세요.',
        emailTaken: '이미 쓰는 이메일이에요.',
        networkError: '연결할 수 없어요. 인터넷 연결을 확인해 주세요.',
        genericError: '문제가 생겼어요. 다시 시도해 주세요.',
        passwordPolicy: const PasswordPolicyLabels.ko(),
        displayName: const DisplayNameLabels.ko(),
        loginId: const LoginIdLabels.ko(),
      );

  final String email;
  final String password;
  final String submit;
  final String required;

  /// A server field error on the email or password with a code other than
  /// `Required`.
  final String invalidValue;
  final DisplayNameLabels displayName;
  final LoginIdLabels loginId;
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
/// A login ID field shows when `GET /auth/methods` has a `loginId` key (the
/// server tells; there is no app setting) and not otherwise.
///
/// [consentBuilder] is the place for the consent checkboxes. The slot calls
/// `controller.update(ready:, claims:)`; until it says `ready: true` the submit
/// button stays disabled. Without a builder there is no consent step.
class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({
    super.key,
    required this.onSignedUp,
    this.displayName = DisplayNameMode.none,
    this.consentBuilder,
    this.onConsentRejected,
    this.labels = const SignUpLabels(),
  });

  static const emailKey = Key('skeleton_auth.sign_up.email');
  static const passwordKey = Key('skeleton_auth.sign_up.password');
  static const displayNameKey = Key('skeleton_auth.sign_up.display_name');
  static const loginIdKey = Key('skeleton_auth.sign_up.login_id');

  final void Function(SignUpOutcome outcome) onSignedUp;

  /// Whether to ask for a nickname. Match the server's
  /// `required-on-sign-up`: [DisplayNameMode.required] against a server that
  /// requires one, otherwise the sign-up is refused with a field error.
  final DisplayNameMode displayName;
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
  final _displayName = TextEditingController();
  final _loginId = TextEditingController();
  late final _consents = ConsentSlotController();
  var _busy = false;
  String? _error;

  /// What the server said about a field (`email`, `password`, `displayName`),
  /// already worded. A field's entry goes away when the person edits it.
  var _fieldErrors = const <String, String>{};

  @override
  void initState() {
    super.initState();
    if (widget.consentBuilder == null) _consents.update(ready: true);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    _loginId.dispose();
    _consents.dispose();
    super.dispose();
  }

  /// Null = the server has no login IDs (or has not answered yet).
  LoginIdRules? get _idRules => ref.read(authMethodsProvider).value?.loginId;

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
      _fieldErrors = const {};
    });
    try {
      final nickname = _displayName.text.trim();
      final outcome = await api.signUp(
        email: _email.text.trim(),
        password: _password.text,
        displayName:
            widget.displayName == DisplayNameMode.none || nickname.isEmpty
            ? null
            : nickname,
        loginId: _idRules == null ? null : _loginId.text.trim(),
        consents: _consents.claims,
      );
      final attempt = outcome.attempt;
      if (attempt != null) await store.save(attempt);
      widget.onSignedUp(outcome);
    } catch (e) {
      if (mounted) _showError(e);
      if (e is ApiRequestError &&
          e.code == AccountErrorCodes.legalConsentRequired) {
        widget.onConsentRejected?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A `400` field error goes under its field; only what no field of this form
  /// can show gets the common text.
  void _showError(Object error) {
    final labels = widget.labels;
    final idRules = _idRules;
    if (idRules != null &&
        error is ApiRequestError &&
        error.code == AccountErrorCodes.loginIdTaken) {
      setState(() => _fieldErrors = {'loginId': labels.loginId.taken});
      return;
    }
    final fields = error is ApiRequestError
        ? fieldErrorCodesOf(error, {
            'email',
            'password',
            if (widget.displayName != DisplayNameMode.none) 'displayName',
            if (idRules != null) 'loginId',
          })
        : const <String, String>{};
    if (fields.isEmpty) {
      setState(() => _error = _messageFor(error));
      return;
    }
    final unmatched = (error as ApiRequestError).fieldErrors.any(
      (f) => !fields.containsKey(f.field),
    );
    setState(() {
      _fieldErrors = {
        for (final f in fields.entries)
          f.key: f.key == 'displayName'
              ? labels.displayName.forCode(f.value) ?? labels.invalidValue
              : f.key == 'loginId'
              ? labels.loginId.forCode(f.value, idRules) ?? labels.invalidValue
              : f.value == 'Required'
              ? labels.required
              : labels.invalidValue,
      };
      _error = unmatched ? labels.genericError : null;
    });
  }

  void _edited(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
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
    final idRules = ref.watch(authMethodsProvider).value?.loginId;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: SignUpForm.emailKey,
            controller: _email,
            decoration: InputDecoration(
              labelText: labels.email,
              errorText: _fieldErrors['email'],
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: requiredValue,
            onChanged: (_) => _edited('email'),
          ),
          if (idRules != null) ...[
            const SizedBox(height: 12),
            LoginIdField(
              fieldKey: SignUpForm.loginIdKey,
              controller: _loginId,
              labels: labels.loginId,
              rules: idRules,
              errorText: _fieldErrors['loginId'],
              textInputAction: TextInputAction.next,
              onChanged: (_) => _edited('loginId'),
            ),
          ],
          if (widget.displayName != DisplayNameMode.none) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: SignUpForm.displayNameKey,
              controller: _displayName,
              decoration: InputDecoration(
                labelText: widget.displayName == DisplayNameMode.required
                    ? labels.displayName.label
                    : labels.displayName.optionalLabel,
                errorText: _fieldErrors['displayName'],
              ),
              textInputAction: TextInputAction.next,
              validator: widget.displayName == DisplayNameMode.required
                  ? (v) => v == null || v.trim().isEmpty
                        ? labels.displayName.required
                        : null
                  : null,
              onChanged: (_) => _edited('displayName'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: SignUpForm.passwordKey,
            controller: _password,
            decoration: InputDecoration(
              labelText: labels.password,
              errorText: _fieldErrors['password'],
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: _passwordProblem,
            onChanged: (_) => _edited('password'),
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
