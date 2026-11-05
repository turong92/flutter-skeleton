import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

const _policyJson = {
  'minLength': 8,
  'maxBytes': 72,
  'requireLetter': true,
  'requireDigit': false,
  'requireSymbol': false,
  'forbidEmailLocalPart': false,
};

ResponseBody _accepted(Object? value) => FakeAdapter.json(202, {
  'value': value,
  'meta': {'timestamp': '2026-01-01T00:00:00Z'},
});

ResponseBody _error(
  int status,
  String code, {
  Object? data,
  List<Map<String, String>>? errors,
}) => FakeAdapter.json(status, {
  'code': code,
  'title': code,
  'status': status,
  'data': ?data,
  'errors': ?errors,
});

ResponseBody _invalid(String field, String code) => _error(
  400,
  'COMMON.VALIDATION_FAILED',
  errors: [
    {'field': field, 'code': code, 'message': 'log only'},
  ],
);

class _Harness {
  _Harness(FutureOr<ResponseBody> Function(RequestOptions) handler)
    : adapter = FakeAdapter(handler);

  final FakeAdapter adapter;
  final store = MemoryTokenStore();
  final attempts = MemorySignUpAttemptStore();
  late final ProviderContainer container;

  Widget app(Widget child) {
    final scope = ProviderScope(
      overrides: [
        authConfigProvider.overrideWithValue(
          const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        signUpAttemptStoreProvider.overrideWithValue(attempts),
        httpAdapterProvider.overrideWithValue(adapter),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    return scope;
  }

  Iterable<RequestOptions> calls(String path) =>
      adapter.requests.where((r) => r.path == path);
}

Future<void> _type(WidgetTester t, Key key, String text) async {
  await t.enterText(find.byKey(key), text);
}

void main() {
  group('SignUpForm', () {
    testWidgets('a 202 keeps the attempt in the store and hands it on', (
      t,
    ) async {
      final h = _Harness((o) {
        if (o.path == '/account/password/policy') return ok(_policyJson);
        return _accepted({
          'status': 'VERIFICATION_SENT',
          'signUpId': 'su_1',
          'expiresAt': '2099-01-01T00:10:00Z',
          'resendAvailableAt': null,
        });
      });
      SignUpOutcome? seen;
      await t.pumpWidget(h.app(SignUpForm(onSignedUp: (o) => seen = o)));
      await t.pumpAndSettle();

      await _type(t, SignUpForm.emailKey, 'new@example.com');
      await _type(t, SignUpForm.passwordKey, 'secret-pass');
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();

      expect(seen!.attempt!.signUpId, 'su_1');
      expect((await h.attempts.read())!.signUpId, 'su_1');
    });

    testWidgets(
      'the consent slot decides the claims that are sent and when submit is allowed',
      (t) async {
        final h = _Harness((o) {
          if (o.path == '/account/password/policy') return ok(_policyJson);
          return _accepted({
            'status': 'VERIFICATION_SENT',
            'signUpId': 'su_1',
            'expiresAt': '2099-01-01T00:10:00Z',
          });
        });
        await t.pumpWidget(
          h.app(
            SignUpForm(
              onSignedUp: (_) {},
              consentBuilder: (context, slot) => TextButton(
                key: const Key('tick'),
                onPressed: () => slot.update(
                  ready: true,
                  claims: const [ConsentClaim(type: 'terms', version: 'v7')],
                ),
                child: const Text('agree'),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await _type(t, SignUpForm.emailKey, 'new@example.com');
        await _type(t, SignUpForm.passwordKey, 'secret-pass');

        // Not ready yet: the button is disabled and nothing is sent.
        final button = find.widgetWithText(FilledButton, 'Create account');
        expect(t.widget<FilledButton>(button).onPressed, isNull);

        await t.tap(find.byKey(const Key('tick')));
        await t.pumpAndSettle();
        await t.tap(button);
        await t.pumpAndSettle();

        expect((h.calls('/account/sign-up').single.data as Map)['consents'], [
          {'type': 'terms', 'version': 'v7'},
        ]);
      },
    );

    testWidgets(
      'LEGAL.CONSENT_REQUIRED tells the app so it can read the documents again',
      (t) async {
        final h = _Harness((o) {
          if (o.path == '/account/password/policy') return ok(_policyJson);
          return _error(400, 'LEGAL.CONSENT_REQUIRED');
        });
        var rejected = 0;
        await t.pumpWidget(
          h.app(
            SignUpForm(onSignedUp: (_) {}, onConsentRejected: () => rejected++),
          ),
        );
        await t.pumpAndSettle();
        await _type(t, SignUpForm.emailKey, 'new@example.com');
        await _type(t, SignUpForm.passwordKey, 'secret-pass');

        await t.tap(find.widgetWithText(FilledButton, 'Create account'));
        await t.pumpAndSettle();

        expect(rejected, 1);
        expect(find.text(const SignUpLabels().consentRequired), findsOneWidget);
      },
    );

    testWidgets('a password the policy refuses is not sent', (t) async {
      final h = _Harness(
        (o) => o.path == '/account/password/policy'
            ? ok(_policyJson)
            : _accepted({}),
      );
      await t.pumpWidget(h.app(SignUpForm(onSignedUp: (_) {})));
      await t.pumpAndSettle();
      await _type(t, SignUpForm.emailKey, 'new@example.com');
      await _type(t, SignUpForm.passwordKey, 'short');

      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();

      expect(h.calls('/account/sign-up'), isEmpty);
    });

    testWidgets(
      'the policy hint reads the server rules; maxBytes is shown as bytes',
      (t) async {
        final h = _Harness((_) => ok(_policyJson));
        await t.pumpWidget(h.app(SignUpForm(onSignedUp: (_) {})));
        await t.pumpAndSettle();

        expect(find.textContaining('72 bytes'), findsOneWidget);
      },
    );
  });

  group('SignUpForm nickname', () {
    ResponseBody sent() => _accepted({
      'status': 'VERIFICATION_SENT',
      'signUpId': 'su_1',
      'expiresAt': '2099-01-01T00:10:00Z',
    });

    Future<_Harness> open(
      WidgetTester t,
      FutureOr<ResponseBody> Function(RequestOptions) onSignUp, {
      DisplayNameMode mode = DisplayNameMode.required,
    }) async {
      final h = _Harness(
        (o) => o.path == '/account/password/policy'
            ? ok(_policyJson)
            : onSignUp(o),
      );
      await t.pumpWidget(
        h.app(SignUpForm(onSignedUp: (_) {}, displayName: mode)),
      );
      await t.pumpAndSettle();
      return h;
    }

    Future<void> fillAndSubmit(WidgetTester t, {String? nickname}) async {
      await _type(t, SignUpForm.emailKey, 'new@example.com');
      await _type(t, SignUpForm.passwordKey, 'secret-pass');
      if (nickname != null) {
        await _type(t, SignUpForm.displayNameKey, nickname);
      }
      await t.tap(find.widgetWithText(FilledButton, 'Create account'));
      await t.pumpAndSettle();
    }

    testWidgets('required: a blank nickname is not sent', (t) async {
      final h = await open(t, (_) => sent());

      await fillAndSubmit(t, nickname: '   ');

      expect(h.calls('/account/sign-up'), isEmpty);
    });

    testWidgets('a typed nickname is sent without the spaces around it', (
      t,
    ) async {
      final h = await open(t, (_) => sent());

      await fillAndSubmit(t, nickname: '  Ann ');

      expect(
        (h.calls('/account/sign-up').single.data as Map)['displayName'],
        'Ann',
      );
    });

    testWidgets('none (the default): no nickname field and none is sent', (
      t,
    ) async {
      final h = await open(t, (_) => sent(), mode: DisplayNameMode.none);

      expect(find.byKey(SignUpForm.displayNameKey), findsNothing);
      await fillAndSubmit(t);

      expect(
        (h.calls('/account/sign-up').single.data as Map).containsKey(
          'displayName',
        ),
        isFalse,
      );
    });

    testWidgets('a field error of the server sits under that field', (t) async {
      await open(t, (_) => _invalid('displayName', 'Reserved'));

      await fillAndSubmit(t, nickname: 'admin');

      expect(
        find.text(const SignUpLabels().displayName.reserved),
        findsOneWidget,
      );
      expect(find.text(const SignUpLabels().genericError), findsNothing);
    });

    testWidgets(
      'a field error the form has no field for gets the common text',
      (t) async {
        await open(t, (_) => _invalid('loginId', 'Required'));

        await fillAndSubmit(t, nickname: 'Ann');

        expect(find.text(const SignUpLabels().genericError), findsOneWidget);
      },
    );
  });

  group('VerifyCodeForm nickname', () {
    final attempt = SignUpAttempt(
      signUpId: 'su_1',
      expiresAt: DateTime.utc(2099),
      resendAvailableAt: null,
    );

    testWidgets(
      '409 DISPLAY_NAME_TAKEN asks for another nickname and repeats the same signUpId and code',
      (t) async {
        var calls = 0;
        final h = _Harness((o) {
          calls++;
          return calls == 1
              ? _error(409, 'ACCOUNT.DISPLAY_NAME_TAKEN')
              : FakeAdapter.json(200, tokenResponse('access-9', 'refresh-9'));
        });
        await h.attempts.save(attempt);
        var verified = 0;
        await t.pumpWidget(
          h.app(VerifyCodeForm(attempt: attempt, onVerified: () => verified++)),
        );
        expect(find.byKey(VerifyCodeForm.displayNameKey), findsNothing);

        await _type(t, VerifyCodeForm.codeKey, '123456');
        await t.tap(find.widgetWithText(FilledButton, 'Verify'));
        await t.pumpAndSettle();

        expect(find.byKey(VerifyCodeForm.displayNameKey), findsOneWidget);
        expect(
          find.text(const VerifyCodeLabels().displayName.taken),
          findsOneWidget,
        );
        expect(verified, 0);

        await _type(t, VerifyCodeForm.displayNameKey, ' Bob ');
        await t.tap(find.widgetWithText(FilledButton, 'Verify'));
        await t.pumpAndSettle();

        final sent = h.calls('/auth/verify-email').map((r) => r.data).toList();
        expect(sent, [
          {'signUpId': 'su_1', 'code': '123456'},
          {'signUpId': 'su_1', 'code': '123456', 'displayName': 'Bob'},
        ]);
        expect(verified, 1);
      },
    );
  });

  group('DisplayNameForm', () {
    testWidgets('saves the trimmed nickname with PATCH /account/me', (t) async {
      final h = _Harness(
        (_) => ok({
          'hasPassword': true,
          'displayName': 'Ann',
          'displayTag': '0417',
        }),
      );
      AccountMe? saved;
      await t.pumpWidget(h.app(DisplayNameForm(onSaved: (me) => saved = me)));

      await _type(t, DisplayNameForm.fieldKey, ' Ann ');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();

      final call = h.calls('/account/me').single;
      expect(call.method, 'PATCH');
      expect(call.data, {'displayName': 'Ann'});
      expect(saved!.displayLabel, 'Ann#0417');
    });

    testWidgets('409 DISPLAY_NAME_TAKEN is a field error', (t) async {
      final h = _Harness((_) => _error(409, 'ACCOUNT.DISPLAY_NAME_TAKEN'));
      await t.pumpWidget(h.app(DisplayNameForm(onSaved: (_) {})));

      await _type(t, DisplayNameForm.fieldKey, 'Ann');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();

      expect(find.text(const DisplayNameLabels().taken), findsOneWidget);
      expect(h.calls('/account/me'), hasLength(1));
    });
  });

  group('VerifyCodeForm', () {
    final attempt = SignUpAttempt(
      signUpId: 'su_1',
      expiresAt: DateTime.utc(2099),
      resendAvailableAt: null,
    );

    testWidgets('a wrong code shows the attempts that are left', (t) async {
      final h = _Harness(
        (_) => _error(400, 'ACCOUNT.CODE_INVALID', data: {'attemptsLeft': 2}),
      );
      await t.pumpWidget(h.app(VerifyCodeForm(attempt: attempt)));

      await _type(t, VerifyCodeForm.codeKey, '000000');
      await t.tap(find.widgetWithText(FilledButton, 'Verify'));
      await t.pumpAndSettle();

      expect(
        find.text(const VerifyCodeLabels().codeInvalid(2)),
        findsOneWidget,
      );
    });

    testWidgets('resendAvailableAt null: there is no resend button', (t) async {
      final h = _Harness((_) => FakeAdapter.empty(204));
      await t.pumpWidget(h.app(VerifyCodeForm(attempt: attempt)));

      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets(
      'resend counts down on the device clock and asks for a new code when it is over',
      (t) async {
        final h = _Harness(
          (o) => _accepted({
            'status': 'ACCEPTED',
            'expiresAt': '2099-01-01T00:20:00Z',
            'resendAvailableAt': null,
          }),
        );
        var now = DateTime.utc(2026, 1, 1, 12);
        final waiting = SignUpAttempt(
          signUpId: 'su_1',
          expiresAt: DateTime.utc(2099),
          resendAvailableAt: now.add(const Duration(seconds: 30)),
        );
        await h.attempts.save(waiting);
        await t.pumpWidget(
          h.app(VerifyCodeForm(attempt: waiting, now: () => now)),
        );

        final resend = find.byType(OutlinedButton);
        expect(t.widget<OutlinedButton>(resend).onPressed, isNull);
        expect(find.textContaining('30'), findsWidgets);

        now = now.add(const Duration(seconds: 31));
        await t.pump(const Duration(seconds: 1));
        expect(t.widget<OutlinedButton>(resend).onPressed, isNotNull);

        await t.tap(resend);
        await t.pumpAndSettle();

        expect(h.calls('/account/verification/resend').single.data, {
          'signUpId': 'su_1',
        });
        expect(
          (await h.attempts.read())!.expiresAt,
          DateTime.utc(2099, 1, 1, 0, 20),
        );
      },
    );

    testWidgets(
      '410 CODE_EXPIRED removes the attempt and sends the user back',
      (t) async {
        final h = _Harness((_) => _error(410, 'ACCOUNT.CODE_EXPIRED'));
        await h.attempts.save(attempt);
        var expired = 0;
        await t.pumpWidget(
          h.app(VerifyCodeForm(attempt: attempt, onExpired: () => expired++)),
        );

        await _type(t, VerifyCodeForm.codeKey, '123456');
        await t.tap(find.widgetWithText(FilledButton, 'Verify'));
        await t.pumpAndSettle();

        expect(expired, 1);
        expect(await h.attempts.read(), isNull);
        expect(find.text(const VerifyCodeLabels().codeExpired), findsOneWidget);
      },
    );

    testWidgets(
      'a good code signs in, stores the tokens and removes the attempt',
      (t) async {
        final h = _Harness(
          (_) => FakeAdapter.json(200, tokenResponse('access-9', 'refresh-9')),
        );
        await h.attempts.save(attempt);
        var verified = 0;
        await t.pumpWidget(
          h.app(VerifyCodeForm(attempt: attempt, onVerified: () => verified++)),
        );
        h.container = ProviderScope.containerOf(
          t.element(find.byType(VerifyCodeForm)),
        );

        await _type(t, VerifyCodeForm.codeKey, '123456');
        await t.tap(find.widgetWithText(FilledButton, 'Verify'));
        await t.pumpAndSettle();

        expect(h.container.read(authSessionProvider), isA<SignedIn>());
        expect((await h.store.read())!.refreshToken, 'refresh-9');
        expect(await h.attempts.read(), isNull);
        expect(verified, 1);
      },
    );
  });

  group('ForgotPasswordForm', () {
    testWidgets('always shows the same answer after asking for a mail', (
      t,
    ) async {
      final h = _Harness((_) => _accepted({'status': 'ACCEPTED'}));
      await t.pumpWidget(h.app(const ForgotPasswordForm()));

      await _type(t, ForgotPasswordForm.emailKey, 'a@example.com');
      await t.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await t.pumpAndSettle();

      expect(h.calls('/account/password/forgot').single.data, {
        'email': 'a@example.com',
      });
      expect(find.text(const ForgotPasswordLabels().sent), findsOneWidget);
    });
  });

  group('ResetPasswordForm', () {
    testWidgets('success signs out on this device and never shows the token', (
      t,
    ) async {
      final h = _Harness((o) {
        if (o.path == '/account/password/policy') return ok(_policyJson);
        return FakeAdapter.empty(204);
      });
      await h.store.save(const TokenPair(accessToken: 'a', refreshToken: 'r'));
      var done = 0;
      await t.pumpWidget(
        h.app(
          ResetPasswordForm(token: 'secret-reset-token', onReset: () => done++),
        ),
      );
      await t.pumpAndSettle();
      h.container = ProviderScope.containerOf(
        t.element(find.byType(ResetPasswordForm)),
      );

      await _type(t, ResetPasswordForm.passwordKey, 'brand-new-pass');
      await t.tap(find.widgetWithText(FilledButton, 'Set new password'));
      await t.pumpAndSettle();

      expect(h.calls('/account/password/reset').single.data, {
        'token': 'secret-reset-token',
        'newPassword': 'brand-new-pass',
      });
      expect(await h.store.read(), isNull);
      expect(h.container.read(authSessionProvider), isA<SignedOut>());
      expect(done, 1);
      expect(find.textContaining('secret-reset-token'), findsNothing);
    });

    testWidgets(
      'an unusable link is said so, a policy violation names the rule',
      (t) async {
        var answer = 0;
        final h = _Harness((o) {
          if (o.path == '/account/password/policy') return ok(_policyJson);
          return answer++ == 0
              ? _error(410, 'ACCOUNT.TOKEN_INVALID')
              : _error(
                  400,
                  'ACCOUNT.PASSWORD_POLICY',
                  data: {
                    'violations': ['BREACHED'],
                  },
                );
        });
        await t.pumpWidget(
          h.app(ResetPasswordForm(token: 'tok', onReset: () {})),
        );
        await t.pumpAndSettle();
        await _type(t, ResetPasswordForm.passwordKey, 'brand-new-pass');

        await t.tap(find.widgetWithText(FilledButton, 'Set new password'));
        await t.pumpAndSettle();
        expect(
          find.text(const ResetPasswordLabels().tokenInvalid),
          findsOneWidget,
        );

        await t.tap(find.widgetWithText(FilledButton, 'Set new password'));
        await t.pumpAndSettle();
        expect(
          find.text(
            const PasswordPolicyLabels().violation(PasswordViolation.breached),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('DeleteAccountForm', () {
    testWidgets(
      'a retry after a failure reuses the key; the key is new per submit once it worked',
      (t) async {
        var call = 0;
        final h = _Harness((o) {
          if (o.path == '/auth/me') return ok(principalJson());
          if (o.path == '/account/me') return ok({'hasPassword': true});
          if (call++ == 0) {
            throw DioException.connectionError(
              requestOptions: o,
              reason: 'down',
            );
          }
          return _accepted({
            'status': 'DELETION_SCHEDULED',
            'purgeAfter': '2026-02-01T00:00:00Z',
          });
        });
        await h.store.save(
          const TokenPair(accessToken: 'a', refreshToken: 'r'),
        );
        await t.pumpWidget(h.app(const DeleteAccountForm()));
        h.container = ProviderScope.containerOf(
          t.element(find.byType(DeleteAccountForm)),
        );

        await _type(t, DeleteAccountForm.passwordKey, 'pw');
        await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
        await t.pumpAndSettle();

        final keys = h
            .calls('/account/delete')
            .map((r) => r.headers['Idempotency-Key'])
            .toList();
        expect(keys, hasLength(2));
        expect(keys[0], isNotNull);
        expect(keys[0], keys[1]);
        expect(await h.store.read(), isNull);
        expect(h.container.read(authSessionProvider), isA<SignedOut>());
      },
    );

    ResponseBody scheduled() => _accepted({
      'status': 'DELETION_SCHEDULED',
      'purgeAfter': '2026-02-01T00:00:00Z',
    });

    testWidgets('an account without a password but with an address mails a '
        'code and deletes with it', (t) async {
      final h = _Harness((o) {
        if (o.path == '/auth/me') return ok(principalJson());
        if (o.path == '/account/me') {
          return ok({'hasPassword': false, 'email': 'user@example.com'});
        }
        if (o.path == '/account/delete/confirmation') {
          return _accepted({
            'status': 'ACCEPTED',
            'expiresAt': '2099-01-01T00:10:00Z',
            'resendAvailableAt': null,
          });
        }
        return scheduled();
      });
      await h.store.save(const TokenPair(accessToken: 'a', refreshToken: 'r'));
      await t.pumpWidget(h.app(const DeleteAccountForm()));
      await t.pumpAndSettle();

      expect(find.byKey(DeleteAccountForm.passwordKey), findsNothing);
      await t.tap(find.widgetWithText(OutlinedButton, 'Send me a code'));
      await t.pumpAndSettle();
      await _type(t, DeleteAccountForm.codeKey, '123456');
      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();

      expect(h.calls('/account/delete/confirmation'), hasLength(1));
      expect(h.calls('/account/delete').single.data, {
        'confirmationCode': '123456',
      });
      expect(await h.store.read(), isNull);
    });

    testWidgets('an account without a password or address deletes with the '
        'social proof the app hands over', (t) async {
      final h = _Harness((o) {
        if (o.path == '/auth/me') return ok(principalJson());
        if (o.path == '/account/me') {
          return ok({'hasPassword': false, 'email': null});
        }
        return scheduled();
      });
      await h.store.save(const TokenPair(accessToken: 'a', refreshToken: 'r'));
      await t.pumpWidget(
        h.app(
          DeleteAccountForm(
            socialReauth: () async => {
              'provider': 'naver',
              'accessToken': 'fake-access-token',
            },
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();

      expect(h.calls('/account/delete').single.data, {
        'socialReauth': {
          'provider': 'naver',
          'accessToken': 'fake-access-token',
        },
      });
      expect(h.calls('/account/delete/confirmation'), isEmpty);
      expect(await h.store.read(), isNull);
    });

    testWidgets('a beforeDelete hook that says no keeps the delete call from '
        'being sent', (t) async {
      final h = _Harness((o) {
        if (o.path == '/auth/me') return ok(principalJson());
        if (o.path == '/account/me') {
          return ok({'hasPassword': true, 'email': 'a@example.com'});
        }
        return scheduled();
      });
      await h.store.save(const TokenPair(accessToken: 'a', refreshToken: 'r'));
      var asked = 0;
      await t.pumpWidget(
        h.app(
          DeleteAccountForm(
            beforeDelete: () async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await t.pumpAndSettle();

      await _type(t, DeleteAccountForm.passwordKey, 'pw');
      await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await t.pumpAndSettle();

      expect(asked, 1);
      expect(h.calls('/account/delete'), isEmpty);
      expect(await h.store.read(), isNotNull);
    });

    testWidgets(
      '409 DELETION_BLOCKED shows the sentence and keeps the user signed in',
      (t) async {
        final h = _Harness(
          (o) => o.path == '/auth/me'
              ? ok(principalJson())
              : _error(
                  409,
                  'ACCOUNT.DELETION_BLOCKED',
                  data: {
                    'blockers': ['x'],
                  },
                ),
        );
        await h.store.save(
          const TokenPair(accessToken: 'a', refreshToken: 'r'),
        );
        await t.pumpWidget(h.app(const DeleteAccountForm()));

        await _type(t, DeleteAccountForm.passwordKey, 'pw');
        await t.tap(find.widgetWithText(FilledButton, 'Delete my account'));
        await t.pumpAndSettle();

        expect(find.text(const DeleteAccountLabels().blocked), findsOneWidget);
        expect(await h.store.read(), isNotNull);
      },
    );
  });
}
