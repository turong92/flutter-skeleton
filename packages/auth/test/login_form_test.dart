import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

Widget _app(FakeAuthBackend backend, LoginLabels labels) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    httpAdapterProvider.overrideWithValue(backend.adapter),
  ],
  child: MaterialApp(
    home: Scaffold(body: LoginForm(labels: labels)),
  ),
);

void main() {
  testWidgets(
    'shows the labels it is given and the invalid-credentials text for a wrong password',
    (tester) async {
      const labels = LoginLabels(
        email: 'Courriel',
        password: 'Mot de passe',
        submit: 'Entrer',
        invalidCredentials: 'Identifiants incorrects.',
      );
      await tester.pumpWidget(_app(FakeAuthBackend(), labels));

      expect(find.text('Courriel'), findsOneWidget);
      await tester.enterText(
        find.byKey(LoginForm.emailKey),
        'user@example.com',
      );
      await tester.enterText(find.byKey(LoginForm.passwordKey), 'nope');
      await tester.tap(find.text('Entrer'));
      await tester.pumpAndSettle();

      expect(find.text('Identifiants incorrects.'), findsOneWidget);
    },
  );
}
