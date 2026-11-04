import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample/main.dart';
import 'package:sample/wiring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_push/testing.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};
const _principal = {
  'accountId': 'acc_user',
  'email': 'user@example.com',
  'roles': ['USER'],
  'permissions': <String>[],
};

Map<String, Object?> _post(int id, String title) => {
  'id': id,
  'boardCode': 'general',
  'authorId': 'acc_other',
  'title': title,
  'excerpt': 'excerpt $id',
  'status': 'PUBLISHED',
  'pinned': false,
  'viewCount': 3,
  'commentCount': 0,
  'reactionCounts': <String, int>{},
  'myReactions': <String>[],
  'attachmentCount': 0,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'authorDeleted': false,
  'authorName': 'Alice',
  'authorTag': '0001',
  'mine': false,
  'authorGuest': false,
};

const _pagination = {
  'page': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'hasNext': false,
  'hasPrevious': false,
};

/// The part of the sample server the app talks to.
class _Backend {
  _Backend({this.fcm = false});

  final bool fcm;
  late final adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    switch ((options.method, options.path)) {
      case ('POST', '/auth/login'):
        return FakeAdapter.json(200, {
          'value': {
            'accessToken': 'access-1',
            'tokenType': 'Bearer',
            'expiresAt': '2026-01-01T00:15:00Z',
            'principal': _principal,
            'refreshToken': 'refresh-1',
          },
          'meta': _meta,
        });
      case ('GET', '/auth/me'):
        return FakeAdapter.json(200, {'value': _principal, 'meta': _meta});
      case ('POST', '/auth/logout'):
        return FakeAdapter.empty(204);
      case ('GET', '/author-profiles'):
        return FakeAdapter.json(200, {
          'values': [
            {'id': 'ap_first'},
            {'id': 'ap_second'},
          ],
          'pagination': _pagination,
          'meta': _meta,
        });
      case ('GET', '/boards/config'):
        return FakeAdapter.json(200, {
          'value': {
            'reactionTypes': ['LIKE'],
            'reactionMode': 'SINGLE',
            'maxCommentDepth': 2,
            'titleMaxLength': 40,
            'bodyMaxLength': 200,
            'commentMaxLength': 100,
            'maxPageSize': 50,
            'canModerate': false,
            'authorRequired': true,
            'guestEnabled': false,
            'guestSecret': 'PASSWORD',
            'guestNameMaxLength': 20,
            'captchaRequired': false,
            'commentMaxAttachments': 0,
          },
          'meta': _meta,
        });
      case ('GET', '/boards/general/posts'):
        return FakeAdapter.json(200, {
          'values': [_post(7, 'First post')],
          'pagination': _pagination,
          'meta': _meta,
        });
      case ('GET', '/payments/config'):
        return FakeAdapter.json(200, {
          'value': {'available': true, 'testMode': true},
          'meta': _meta,
        });
      case ('GET', '/payments/orders'):
        return FakeAdapter.json(200, {
          'values': <Object?>[],
          'cursor': {'nextCursor': null, 'hasNext': false},
          'meta': _meta,
        });
      case ('GET', '/push/config'):
        return FakeAdapter.json(200, {
          'value': {
            'webPush': null,
            'fcm': fcm,
            'types': ['COMMENT'],
            'advertisingTypes': <String>[],
          },
          'meta': _meta,
        });
      case ('GET', '/push/preferences'):
        return FakeAdapter.json(200, {
          'value': {'items': <Object?>[]},
          'meta': _meta,
        });
    }
    if (options.path.startsWith('/push/devices/')) {
      return options.method == 'PUT'
          ? FakeAdapter.json(200, {'value': <String, Object?>{}, 'meta': _meta})
          : FakeAdapter.empty(204);
    }
    return FakeAdapter.json(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'Not found',
      'status': 404,
    });
  }
}

Widget _app(
  _Backend backend, {
  TokenStore? store,
  PushTokenSource? pushSource,
}) => ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(
      const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
    ),
    tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
    signUpAttemptStoreProvider.overrideWithValue(MemorySignUpAttemptStore()),
    httpAdapterProvider.overrideWithValue(backend.adapter),
    ...sampleWiring,
    if (pushSource != null)
      pushTokenSourceProvider.overrideWithValue(pushSource),
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the board author is the first author profile of the account', () async {
    final container = ProviderContainer(
      overrides: [
        authConfigProvider.overrideWithValue(
          const AuthConfig(apiBaseUrl: 'http://localhost:8080/api/v1'),
        ),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        httpAdapterProvider.overrideWithValue(_Backend().adapter),
        ...sampleWiring,
      ],
    );
    addTearDown(container.dispose);

    final resolve = container.read(boardAuthorResolverProvider)!;

    expect(await resolve(), 'ap_first');
  });

  testWidgets('sign in opens the board tab with the posts of the server', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);

    expect(find.text('First post'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    // the board needs an author profile on this server: the app asked for it
    // only when writing, never at start
    expect(
      backend.adapter.requests.where((r) => r.path == '/author-profiles'),
      isEmpty,
    );
  });

  testWidgets('the app runs with push unavailable (no Firebase)', (
    tester,
  ) async {
    final backend = _Backend(fcm: true);
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    // push cannot work: the settings say so and no device call was made
    expect(
      backend.adapter.requests.where((r) => r.path.startsWith('/push/')),
      isEmpty,
    );
  });

  testWidgets('the payment tab offers cheer-3000 under the test strip', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Backend()));
    await _signIn(tester);

    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Test payment: no real money moves.'), findsOneWidget);
    expect(find.text('Cheer 3,000 KRW'), findsOneWidget);
    expect(find.text('Pay 3,000 KRW'), findsOneWidget);
  });

  testWidgets('sign out removes this device from the server first', (
    tester,
  ) async {
    final backend = _Backend(fcm: true);
    final source = FakePushTokenSource(permission: PushPermission.granted);
    await tester.pumpWidget(_app(backend, pushSource: source));
    await _signIn(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    final paths = [
      for (final r in backend.adapter.requests) '${r.method} ${r.path}',
    ];
    final deleted = paths.indexWhere(
      (p) => p.startsWith('DELETE /push/devices/'),
    );
    expect(deleted, isNonNegative);
    expect(deleted, lessThan(paths.indexOf('POST /auth/logout')));
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a message while the app is in front shows a SnackBar', (
    tester,
  ) async {
    final source = FakePushTokenSource(permission: PushPermission.granted);
    await tester.pumpWidget(_app(_Backend(fcm: true), pushSource: source));
    await _signIn(tester);

    source.receive(PushMessage(title: 'New comment', body: 'Hello there'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('New comment'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a tapped notification opens its link once the session is back', (
    tester,
  ) async {
    final source = FakePushTokenSource(
      permission: PushPermission.granted,
      initial: PushMessage(title: 'x', link: '/payment'),
    );
    final store = MemoryTokenStore();
    await store.save(
      const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    await tester.pumpWidget(
      _app(_Backend(fcm: true), store: store, pushSource: source),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cheer 3,000 KRW'), findsOneWidget);
  });
}
