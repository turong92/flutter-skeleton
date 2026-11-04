import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample/main.dart';
import 'package:sample/wiring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};
const _pagination = {
  'page': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'hasNext': false,
  'hasPrevious': false,
};

/// The inbox and the realtime stream of the sample server, for whoever signed
/// in last (`who`). The stream stays open until the app drops it.
class _Backend {
  String who = 'acc_user';
  int sseRequests = 0;
  int sseDropped = 0;
  final paths = <String>[];

  late final adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    paths.add('${options.method} ${options.path}');
    switch ((options.method, options.path)) {
      case ('POST', '/auth/login'):
        return FakeAdapter.json(200, {
          'value': {
            'accessToken': 'access-1',
            'tokenType': 'Bearer',
            'expiresAt': '2026-01-01T00:15:00Z',
            'principal': {
              'accountId': who,
              'email': '$who@example.com',
              'roles': ['USER'],
              'permissions': <String>[],
            },
            'refreshToken': 'refresh-1',
          },
          'meta': _meta,
        });
      case ('POST', '/auth/logout'):
        return FakeAdapter.empty(204);
      case ('GET', '/notifications/sse'):
        sseRequests++;
        final controller = StreamController<Uint8List>(
          onCancel: () => sseDropped++,
        );
        return ResponseBody(
          controller.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['text/event-stream'],
          },
        );
      case ('GET', '/notifications/unread-count'):
        return FakeAdapter.json(200, {
          'value': {'count': 1},
          'meta': _meta,
        });
      case ('GET', '/notifications'):
        return FakeAdapter.json(200, {
          'values': [
            {
              'id': '$who:e1',
              'eventId': 'e1',
              'topic': 'board',
              'type': 'COMMENT',
              'severity': 'INFO',
              'title': 'row of $who',
              'message': 'someone commented',
              // the board's comment rows carry the post id, not a link
              'payload': {'postId': 7},
              'createdAt': '2026-01-01T00:00:00Z',
              'readAt': null,
              'link': null,
              'collapsedCount': 1,
            },
          ],
          'pagination': _pagination,
          'meta': _meta,
        });
      case ('PATCH', '/notifications/e1/read'):
        return FakeAdapter.empty(204);
    }
    return FakeAdapter.json(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'Not found',
      'status': 404,
    });
  }
}

Widget _app(_Backend backend) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    signUpAttemptStoreProvider.overrideWithValue(MemorySignUpAttemptStore()),
    httpAdapterProvider.overrideWithValue(backend.adapter),
    ...sampleWiring,
    socialProvidersProvider.overrideWithValue(const []),
    iapPlatformProvider.overrideWithValue(null),
  ],
  child: const SampleApp(),
);

Future<void> _signIn(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(LoginForm.emailKey), 'user@example.com');
  await tester.enterText(find.byKey(LoginForm.passwordKey), 'password');
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  // drops the scope, which closes the stream's timers
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'sign-out closes the realtime stream and nothing opens it again',
    (tester) async {
      final backend = _Backend();
      await tester.pumpWidget(_app(backend));
      await _signIn(tester);
      expect(backend.sseRequests, 1);

      await _openTab(tester, 'Settings');
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 2));

      expect(backend.sseDropped, 1);
      expect(backend.sseRequests, 1);
      await _end(tester);
    },
  );

  testWidgets('the next account does not see the previous one\'s rows', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    await _openTab(tester, 'Notifications');
    expect(find.text('row of acc_user'), findsOneWidget);

    await _openTab(tester, 'Settings');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    backend.who = 'acc_other';
    await _signIn(tester);
    await _openTab(tester, 'Notifications');

    expect(find.text('row of acc_other'), findsOneWidget);
    expect(find.text('row of acc_user'), findsNothing);
    await _end(tester);
  });

  testWidgets('a comment row without a link opens its post', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    await _openTab(tester, 'Notifications');

    await tester.tap(find.text('row of acc_user'));
    await tester.pumpAndSettle();

    // the row is marked by its event id, and the post of the payload opens
    expect(backend.paths, contains('PATCH /notifications/e1/read'));
    expect(backend.paths, contains('GET /boards/general/posts/7'));
    await _end(tester);
  });
}
