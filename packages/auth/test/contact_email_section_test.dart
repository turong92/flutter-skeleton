import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

void main() {
  testWidgets('adds a contact address by code, then removes it', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final adapter = FakeAdapter((options) {
      requests.add(options);
      switch ((options.method, options.path)) {
        case ('POST', '/account/contact-email'):
          return FakeAdapter.json(202, {
            'value': {
              'status': 'VERIFICATION_SENT',
              'expiresAt': '2026-01-01T00:10:00Z',
              'resendAvailableAt': '2026-01-01T00:01:00Z',
            },
            'meta': {'timestamp': '2026-01-01T00:00:00Z'},
          });
        case ('POST', '/account/contact-email/confirm'):
        case ('DELETE', '/account/contact-email'):
          return FakeAdapter.empty(204);
      }
      return apiError(404, 'COMMON.NOT_FOUND');
    });
    var changed = 0;
    String? shown;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authConfigProvider.overrideWithValue(
            const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          httpAdapterProvider.overrideWithValue(adapter),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ContactEmailSection(
                contactEmail: shown,
                onChanged: () => setState(() {
                  changed++;
                  shown = shown == null ? 'news@example.com' : null;
                }),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pump();
    await tester.enterText(
      find.byKey(ContactEmailSection.emailKey),
      'news@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ContactEmailSection.codeKey), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'POST /account/contact-email',
      'POST /account/contact-email/confirm',
    ]);
    expect(requests.first.data, {'email': 'news@example.com'});
    expect(changed, 1);
    expect(find.text('news@example.com'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(requests.last.method, 'DELETE');
    expect(changed, 2);
  });
}
