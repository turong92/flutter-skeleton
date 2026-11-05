import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample/main.dart';
import 'package:sample/screens/email_screen.dart';
import 'package:sample/wiring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_push/testing.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

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
  _Backend({
    this.fcm = false,
    this.accountMe,
    this.boardLoginIdRequired = false,
  });

  final bool fcm;

  /// `GET /account/me`; null = the endpoint is not there (404).
  Map<String, Object?>? accountMe;

  /// The board answers `403 ACCOUNT.LOGIN_ID_REQUIRED`.
  final bool boardLoginIdRequired;
  late final adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    final me = accountMe;
    if (me != null && options.path == '/account/me') {
      return FakeAdapter.json(200, {'value': me, 'meta': _meta});
    }
    if (me != null && options.path == '/account/login-id') {
      me['loginId'] = 'ann';
      return FakeAdapter.json(200, {'value': me, 'meta': _meta});
    }
    if (boardLoginIdRequired && options.path.startsWith('/boards/')) {
      return FakeAdapter.json(403, {
        'code': 'ACCOUNT.LOGIN_ID_REQUIRED',
        'title': 'x',
        'status': 403,
      });
    }
    // The address gate refuses writes only (`emailRequiredToWrite`).
    if (options.method == 'POST' && options.path.startsWith('/boards/')) {
      return FakeAdapter.json(403, {
        'code': 'ACCOUNT.EMAIL_REQUIRED',
        'title': 'x',
        'status': 403,
      });
    }
    switch ((options.method, options.path)) {
      case ('POST', '/account/email/change'):
        return FakeAdapter.json(202, {
          'value': {
            'expiresAt': '2026-01-01T00:10:00Z',
            'resendAvailableAt': '2026-01-01T00:01:00Z',
          },
          'meta': _meta,
        });
      case ('POST', '/account/email/change/confirm'):
      case ('POST', '/account/discard'):
        return FakeAdapter.empty(204);
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
    // no provider SDK in a widget test (their sign-out would reach a missing plugin)
    socialProvidersProvider.overrideWithValue(const []),
    // no store in a widget test: the real one would try to reach billing
    iapPlatformProvider.overrideWithValue(null),
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
        socialProvidersProvider.overrideWithValue(const []),
        iapPlatformProvider.overrideWithValue(null),
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

  testWidgets('the gates come one after another: ID, consent, nickname', (
    tester,
  ) async {
    final backend = _Backend(
      accountMe: {'hasPassword': true, 'loginId': null, 'displayName': null},
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    expect(find.byType(LoginIdForm), findsOneWidget);

    // A document waits as well: the ID comes first, the consent does not cut in.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginIdForm)),
    );
    container.read(reconsentProvider.notifier).require(const [
      MissingConsent(type: 'terms', version: 'v2', reason: 'NEW_VERSION'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(LoginIdForm), findsOneWidget);
    expect(find.byType(ReconsentScreen), findsNothing);

    await tester.enterText(find.byKey(LoginIdForm.fieldKey), 'ann.lee');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(ReconsentScreen), findsOneWidget);

    container.read(reconsentProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(find.byType(DisplayNameForm), findsOneWidget);
  });

  testWidgets('403 LOGIN_ID_REQUIRED on any call opens the ID form, which has '
      'a way out', (tester) async {
    final backend = _Backend(boardLoginIdRequired: true);
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    expect(find.byType(LoginIdForm), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginIdForm), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  Future<void> registerEmail(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(EmailRegisterForm.emailKey),
      'ann@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(EmailRegisterForm.codeKey), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
  }

  testWidgets('the email gate sits between the ID and the consent', (
    tester,
  ) async {
    final backend = _Backend(
      accountMe: {
        'hasPassword': true,
        'loginId': null,
        'email': null,
        'emailRequired': true,
        'displayName': 'Ann',
      },
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginIdForm)),
    );
    container.read(reconsentProvider.notifier).require(const [
      MissingConsent(type: 'terms', version: 'v2', reason: 'NEW_VERSION'),
    ]);

    await tester.enterText(find.byKey(LoginIdForm.fieldKey), 'ann.lee');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);
    expect(find.byType(ReconsentScreen), findsNothing);
    // right after sign-in nothing is optional: only the way out
    expect(find.text('Later'), findsNothing);

    await registerEmail(tester);
    expect(find.byType(ReconsentScreen), findsOneWidget);
  });

  testWidgets('an address asked for at write time blocks no read, warns '
      'before the write and opens on the refused write', (tester) async {
    final backend = _Backend(
      accountMe: {
        'hasPassword': true,
        'email': null,
        'emailRequiredToWrite': true,
        'displayName': 'Ann',
      },
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    expect(find.text('First post'), findsOneWidget);
    expect(find.byType(EmailRegisterForm), findsNothing);
    expect(find.byType(EmailWriteNotice), findsOneWidget);

    // A write that slipped past the warning is refused: the form opens.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmailWriteNotice)),
    );
    unawaited(
      container
          .read(apiClientProvider)
          .noContent('/boards/general/posts', method: 'POST')
          .then((_) {}, onError: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('First post'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add email'));
    await tester.pumpAndSettle();
    await registerEmail(tester);

    expect(find.text('First post'), findsOneWidget);
    expect(find.byType(EmailWriteNotice), findsOneWidget);
    expect(find.text('Add email'), findsNothing);
    // the refused write is not sent again behind the person's back
    expect(
      backend.adapter.requests.where(
        (r) => r.method == 'POST' && r.path == '/boards/general/posts',
      ),
      hasLength(1),
    );
  });

  testWidgets('an account without an address can be discarded and the device '
      'is signed out', (tester) async {
    final backend = _Backend(
      accountMe: {'hasPassword': true, 'email': null, 'emailRequired': true},
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(
      backend.adapter.requests.where((r) => r.path == '/account/discard'),
      hasLength(1),
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('the email gate has a way out: sign out', (tester) async {
    final backend = _Backend(
      accountMe: {'hasPassword': true, 'email': null, 'emailRequired': true},
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    expect(find.byType(EmailRegisterForm), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(EmailRegisterForm), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
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
      initial: PushMessage(title: 'x', link: '/settings'),
    );
    final store = MemoryTokenStore();
    await store.save(
      const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    await tester.pumpWidget(
      _app(_Backend(fcm: true), store: store, pushSource: source),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
  });
}
