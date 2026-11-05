import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

import 'support/backend_fake.dart';

const _secret = 'link-secret-123';

Widget _app(
  FakeAdapter adapter,
  Widget child, {
  void Function(ProviderContainer)? onContainer,
}) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    httpAdapterProvider.overrideWithValue(adapter),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, _) {
          onContainer?.call(ProviderScope.containerOf(context));
          return child;
        },
      ),
    ),
  ),
);

void main() {
  testWidgets('a valid link signs in, sending the token once', (tester) async {
    final bodies = <Object?>[];
    final adapter = FakeAdapter((options) {
      if (options.path == '/auth/magic-link/redeem') {
        bodies.add(options.data);
        return FakeAdapter.json(200, tokenResponse('access-1', 'refresh-1'));
      }
      return apiError(404, 'COMMON.NOT_FOUND');
    });
    ProviderContainer? container;
    var done = 0;
    await tester.pumpWidget(
      _app(
        adapter,
        MagicLinkLanding(token: _secret, onDone: () => done++),
        onContainer: (c) => container = c,
      ),
    );
    // The spinner never settles while the call runs.
    for (var i = 0; i < 20 && done == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(bodies, [
      {'token': _secret},
    ]);
    expect(container!.read(authSessionProvider), isA<SignedIn>());
    expect(done, 1);
  });

  testWidgets('a dead link says so and never shows the token', (tester) async {
    final adapter = FakeAdapter((options) {
      return apiError(410, AccountErrorCodes.tokenInvalid);
    });
    var invalid = 0;
    await tester.pumpWidget(
      _app(
        adapter,
        MagicLinkLanding(
          token: _secret,
          onInvalid: () => invalid++,
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(const MagicLinkLabels().invalid), findsOneWidget);
    expect(find.textContaining(_secret), findsNothing);
    expect(invalid, 0);
    await tester.tap(find.text(const MagicLinkLabels().requestNew));
    expect(invalid, 1);
  });
}
