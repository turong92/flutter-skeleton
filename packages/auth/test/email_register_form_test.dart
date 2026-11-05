import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

class _Server {
  final requests = <RequestOptions>[];

  late final adapter = FakeAdapter((options) {
    requests.add(options);
    final body = options.data;
    switch (options.path) {
      case '/account/email/change':
        // An old session has to prove itself once (FINAL-6 E3).
        if (body is Map && body['socialReauth'] == null) {
          return apiError(403, 'ACCOUNT.REAUTH_REQUIRED');
        }
        return FakeAdapter.json(202, {
          'value': {
            'expiresAt': '2026-01-01T00:10:00Z',
            'resendAvailableAt': '2026-01-01T00:01:00Z',
          },
          'meta': {'timestamp': '2026-01-01T00:00:00Z'},
        });
      case '/account/email/change/confirm':
        return FakeAdapter.empty(204);
      case '/account/discard':
        return FakeAdapter.empty(204);
    }
    return apiError(404, 'COMMON.NOT_FOUND');
  });
}

Widget _app(_Server server, Widget child) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    httpAdapterProvider.overrideWithValue(server.adapter),
  ],
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'registers the first address: an old session proves itself once, the '
    'code step warns that the address may already have an account',
    (tester) async {
      final server = _Server();
      var reauths = 0;
      var registered = 0;
      await tester.pumpWidget(
        _app(
          server,
          EmailRegisterForm(
            onRegistered: () => registered++,
            socialReauth: () async {
              reauths++;
              return {'provider': 'google', 'idToken': 'token'};
            },
          ),
        ),
      );

      await tester.enterText(
        find.byKey(EmailRegisterForm.emailKey),
        'ann@example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(reauths, 1);
      expect(find.byKey(EmailRegisterForm.codeKey), findsOneWidget);
      expect(
        find.textContaining('may already have an account'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(EmailRegisterForm.codeKey), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(registered, 1);
      final change = server.requests.where(
        (r) => r.path == '/account/email/change',
      );
      expect((change.last.data as Map)['newEmail'], 'ann@example.com');
      expect((change.last.data as Map)['socialReauth'], isNotNull);
      final confirm = server.requests.singleWhere(
        (r) => r.path == '/account/email/change/confirm',
      );
      expect((confirm.data as Map)['code'], '123456');
    },
  );

  testWidgets('discarding asks first, then drops the session', (tester) async {
    final server = _Server();
    var discarded = 0;
    await tester.pumpWidget(
      _app(server, DiscardAccountButton(onDiscarded: () => discarded++)),
    );

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(server.requests, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(server.requests.single.path, '/account/discard');
    expect(discarded, 1);
  });
}
