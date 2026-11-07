import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
// #if iap
import 'package:skeleton_iap/skeleton_iap.dart';
// #endif
import 'package:skeleton_legal/skeleton_legal.dart';
// #if social-login
import 'package:skeleton_social_login/skeleton_social_login.dart';
// #endif
// #if notifications realtime
import 'package:starter/inbox_realtime.dart';
// #endif
import 'package:starter/main.dart';
import 'package:starter/router.dart';
import 'package:starter/wiring.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};
const _principal = {
  'accountId': 'acc_user',
  'email': 'user@example.com',
  'roles': ['USER'],
  'permissions': <String>[],
};
const _goodPassword = 'Str0ngPassw0rd';

ResponseBody _error(int status, String code, {Object? data}) =>
    FakeAdapter.json(status, {
      'code': code,
      'title': code,
      'status': status,
      'timestamp': '2026-01-01T00:00:00Z',
      'data': ?data,
    });

Map<String, Object?> _doc(String type, String version) => {
  'type': type,
  'locale': 'en',
  'version': version,
  'title': '$type title',
  'required': true,
  'requiredAtSignUp': true,
};

/// The part of the backend the starter's account screens talk to.
class _Backend {
  String documentsVersion = '1';
  bool reconsentRequired = false;
  int documentReads = 0;
  final bodies = <String, Object?>{};
  late final adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    final path = options.path;
    bodies[path] = options.data;
    switch ((options.method, path)) {
      case ('GET', '/account/me'):
        // what the delete form (and the Apple revoke) read about the account
        return FakeAdapter.json(200, {
          'value': {
            'hasPassword': true,
            'email': 'user@example.com',
            'methods': [
              {'method': 'password'},
            ],
          },
          'meta': {'timestamp': '2026-01-01T00:00:00Z'},
        });
      case ('GET', '/account/password/policy'):
        return FakeAdapter.json(200, {
          'value': {
            'minLength': 10,
            'maxBytes': 72,
            'requireLetter': true,
            'requireDigit': true,
            'requireSymbol': false,
            'forbidEmailLocalPart': true,
          },
          'meta': _meta,
        });
      case ('GET', '/legal/documents'):
        documentReads++;
        return FakeAdapter.json(200, {
          'values': [
            _doc('terms', documentsVersion),
            _doc('privacy', documentsVersion),
          ],
          'meta': _meta,
        });
      case ('POST', '/account/sign-up'):
        final body = options.data as Map<String, Object?>;
        final consents = (body['consents'] as List?) ?? const [];
        if (consents.any((c) => (c as Map)['version'] != documentsVersion) ||
            consents.length < 2) {
          return _error(400, 'LEGAL.CONSENT_REQUIRED');
        }
        return FakeAdapter.json(202, {
          'value': {
            'status': 'VERIFICATION_SENT',
            'signUpId': 'su_1',
            'expiresAt': '2999-01-01T00:10:00Z',
            'resendAvailableAt': '2999-01-01T00:01:00Z',
          },
          'meta': _meta,
        });
      case ('POST', '/auth/verify-email'):
        final body = options.data as Map<String, Object?>;
        return body['code'] == '123456'
            ? _signedIn()
            : _error(400, 'ACCOUNT.CODE_INVALID', data: {'attemptsLeft': 4});
      case ('POST', '/auth/login'):
        return _signedIn();
      case ('GET', '/auth/me'):
        return reconsentRequired
            ? _error(
                403,
                'LEGAL.RECONSENT_REQUIRED',
                data: {
                  'missing': [
                    {'type': 'terms', 'version': '2', 'reason': 'OUTDATED'},
                  ],
                },
              )
            : FakeAdapter.json(200, {'value': _principal, 'meta': _meta});
      case ('POST', '/auth/logout'):
        return FakeAdapter.empty(204);
      case ('POST', '/account/password/reset'):
        return FakeAdapter.empty(204);
      case ('POST', '/account/delete'):
        return FakeAdapter.json(202, {
          'value': {'purgeAfter': '2999-01-01T00:00:00Z'},
          'meta': _meta,
        });
      case ('GET', final p) when p.startsWith('/legal/documents/'):
        return FakeAdapter.json(200, {
          'value': {
            ..._doc(
              p.split('/').last,
              options.queryParameters['version'] as String? ?? '1',
            ),
            'markdown': 'text',
          },
          'meta': _meta,
        });
      case ('POST', '/legal/consents'):
        reconsentRequired = false;
        return FakeAdapter.json(200, {
          'value': {'blocked': false, 'items': [], 'missing': []},
          'meta': _meta,
        });
    }
    return _error(404, 'COMMON.NOT_FOUND');
  }

  ResponseBody _signedIn() => FakeAdapter.json(200, {
    'value': {
      'accessToken': 'access-1',
      'tokenType': 'Bearer',
      'expiresAt': '2026-01-01T00:15:00Z',
      'principal': _principal,
      'refreshToken': 'refresh-1',
    },
    'meta': _meta,
  });
}

class _Harness {
  _Harness(this.backend, this.tokens, this.attempts);
  final _Backend backend;
  final MemoryTokenStore tokens;
  final MemorySignUpAttemptStore attempts;
}

Future<(_Harness, ProviderContainer)> _start(
  WidgetTester tester, {
  MemoryTokenStore? tokens,
}) async {
  final harness = _Harness(
    _Backend(),
    tokens ?? MemoryTokenStore(),
    MemorySignUpAttemptStore(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authConfigProvider.overrideWithValue(
          const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
        ),
        tokenStoreProvider.overrideWithValue(harness.tokens),
        signUpAttemptStoreProvider.overrideWithValue(harness.attempts),
        httpAdapterProvider.overrideWithValue(harness.backend.adapter),
        ...starterWiring,
        // #if social-login
        // a provider's SDK cannot run in a widget test
        socialProvidersProvider.overrideWithValue(const []),
        // #endif
        // #if iap
        // no store on the test host
        iapPlatformProvider.overrideWithValue(null),
        // #endif
        // #if notifications realtime
        // no event stream in a test
        inboxRealtimeProvider.overrideWithValue(null),
        // #endif
      ],
      child: const StarterApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(StarterApp)),
  );
  return (harness, container);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(LoginForm.emailKey), 'user@example.com');
  await tester.enterText(find.byKey(LoginForm.passwordKey), 'password');
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

/// Calls a route the backend refuses with 403 RECONSENT_REQUIRED. The call is
/// not awaited before pumping: fake async only runs the HTTP fake while pumping.
Future<void> _callGatedApi(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final refused = expectLater(
    container.read(authApiProvider).me(),
    throwsA(anything),
  );
  await tester.pumpAndSettle();
  await refused;
}

void main() {
  testWidgets('sign up with the consents, enter the code, land signed in', (
    tester,
  ) async {
    final (h, _) = await _start(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(SignUpForm.emailKey), 'new@example.com');
    await tester.enterText(find.byKey(SignUpForm.passwordKey), _goodPassword);
    await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
    await tester.tap(find.byKey(SignUpConsents.checkKey('privacy')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.byKey(VerifyCodeForm.codeKey), findsOneWidget);
    final sent = h.backend.bodies['/account/sign-up']! as Map;
    expect(sent['consents'], [
      {'type': 'terms', 'version': '1', 'locale': 'en'},
      {'type': 'privacy', 'version': '1', 'locale': 'en'},
    ]);

    await tester.enterText(find.byKey(VerifyCodeForm.codeKey), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(await h.tokens.read(), isNotNull);
    expect(await h.attempts.read(), isNull);
  });

  testWidgets('the submit stays off until the required boxes are checked', (
    tester,
  ) async {
    await _start(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets(
    'a 400 CONSENT_REQUIRED reads the documents again and unchecks a changed one',
    (tester) async {
      final (h, _) = await _start(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SignUpForm.emailKey),
        'new@example.com',
      );
      await tester.enterText(find.byKey(SignUpForm.passwordKey), _goodPassword);
      await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
      await tester.tap(find.byKey(SignUpConsents.checkKey('privacy')));
      await tester.pumpAndSettle();
      final readsBefore = h.backend.documentReads;

      h.backend.documentsVersion = '2'; // new version came out meanwhile
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(h.backend.documentReads, greaterThan(readsBefore));
      expect(find.byKey(VerifyCodeForm.codeKey), findsNothing);
      expect(
        tester
            .widget<Checkbox>(find.byKey(SignUpConsents.checkKey('terms')))
            .value,
        isFalse,
      );
    },
  );

  testWidgets('forgot password is reachable from the sign-in screen', (
    tester,
  ) async {
    await _start(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byKey(ForgotPasswordForm.emailKey), findsOneWidget);
  });

  testWidgets('a reset link sets the new password and returns to sign-in', (
    tester,
  ) async {
    final (h, container) = await _start(tester);

    container.read(routerProvider).go('/reset-password?token=tok-1');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ResetPasswordForm.passwordKey),
      _goodPassword,
    );
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(h.backend.bodies['/account/password/reset'], {
      'token': 'tok-1',
      'newPassword': _goodPassword,
    });
    expect(find.byKey(LoginForm.emailKey), findsOneWidget);
  });

  testWidgets('a reset link without a token offers a new one', (tester) async {
    final (_, container) = await _start(tester);

    container.read(routerProvider).go('/reset-password');
    await tester.pumpAndSettle();

    expect(find.byKey(ResetPasswordForm.passwordKey), findsNothing);
    await tester.tap(find.text('Send a new link'));
    await tester.pumpAndSettle();
    expect(find.byKey(ForgotPasswordForm.emailKey), findsOneWidget);
  });

  testWidgets('delete my account asks for the password and ends at sign-in', (
    tester,
  ) async {
    final (h, _) = await _start(tester);
    await _signIn(tester);

    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(DeleteAccountForm.passwordKey),
      'password',
    );
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(h.backend.bodies['/account/delete'], {
      'currentPassword': 'password',
    });
    expect(find.byKey(LoginForm.emailKey), findsOneWidget);
    expect(await h.tokens.read(), isNull);
  });

  testWidgets(
    'a 403 RECONSENT_REQUIRED opens the consent screen and keeps the session',
    (tester) async {
      final (h, container) = await _start(tester);
      await _signIn(tester);
      h.backend.reconsentRequired = true;

      await _callGatedApi(tester, container);

      expect(find.byKey(ReconsentScreen.agreeKey), findsOneWidget);
      expect(find.byKey(LoginForm.emailKey), findsNothing);
      expect(await h.tokens.read(), isNotNull);
      expect(container.read(authSessionProvider), isA<SignedIn>());

      await tester.tap(find.byKey(ReconsentScreen.checkKey('terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReconsentScreen.agreeKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ReconsentScreen.agreeKey), findsNothing);
      expect(find.text('user@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'signing out forgets a pending consent, so the next sign-in is not blocked',
    (tester) async {
      final (h, container) = await _start(tester);
      await _signIn(tester);
      h.backend.reconsentRequired = true;
      await _callGatedApi(tester, container);
      expect(container.read(reconsentProvider), isNotEmpty);

      unawaited(container.read(authSessionProvider.notifier).logout());
      await tester.pumpAndSettle();
      expect(container.read(reconsentProvider), isEmpty);

      h.backend.reconsentRequired = false;
      await _signIn(tester);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.byKey(ReconsentScreen.agreeKey), findsNothing);
    },
  );
}
