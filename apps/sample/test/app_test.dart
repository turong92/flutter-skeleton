import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample/main.dart';
import 'package:sample/router.dart';
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
    this.deletionGrace = false,
  });

  final bool fcm;

  /// The account is in its deletion grace: the sign-in answers `403
  /// AUTH.ACCOUNT_DELETION_PENDING` with a restore token until it is used.
  bool deletionGrace;
  static const restoreToken = 'restore-token-for-the-test';

  /// `GET /account/me`; null = the endpoint is not there (404).
  Map<String, Object?>? accountMe;

  /// The address was confirmed: writes pass from then on.
  bool addressSet = false;

  /// The board answers `403 ACCOUNT.LOGIN_ID_REQUIRED`.
  final bool boardLoginIdRequired;
  late final adapter = FakeAdapter(_handle);

  ResponseBody _loginResponse() => FakeAdapter.json(200, {
    'value': {
      'accessToken': 'access-1',
      'tokenType': 'Bearer',
      'expiresAt': '2026-01-01T00:15:00Z',
      'principal': _principal,
      'refreshToken': 'refresh-1',
    },
    'meta': _meta,
  });

  ResponseBody _handle(RequestOptions options) {
    final me = accountMe;
    // A server that wants the address for changes (a nickname too).
    if (me != null &&
        options.method == 'PATCH' &&
        options.path == '/account/me') {
      if (!addressSet) {
        return FakeAdapter.json(403, {
          'code': 'ACCOUNT.EMAIL_REQUIRED',
          'title': 'x',
          'status': 403,
        });
      }
      me['displayName'] = (options.data as Map)['displayName'];
      return FakeAdapter.json(200, {'value': me, 'meta': _meta});
    }
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
    if (!addressSet &&
        options.method == 'POST' &&
        options.path.startsWith('/boards/')) {
      return FakeAdapter.json(403, {
        'code': 'ACCOUNT.EMAIL_REQUIRED',
        'title': 'x',
        'status': 403,
      });
    }
    switch ((options.method, options.path)) {
      case ('POST', '/boards/general/posts'):
        return FakeAdapter.empty(204);
      case ('POST', '/account/email/change'):
        return FakeAdapter.json(202, {
          'value': {
            'expiresAt': '2026-01-01T00:10:00Z',
            'resendAvailableAt': '2026-01-01T00:01:00Z',
          },
          'meta': _meta,
        });
      case ('POST', '/account/email/change/confirm'):
        addressSet = true;
        return FakeAdapter.empty(204);
      case ('POST', '/account/discard'):
        return FakeAdapter.empty(204);
      case ('POST', '/auth/login') when deletionGrace:
        return FakeAdapter.json(403, {
          'code': 'AUTH.ACCOUNT_DELETION_PENDING',
          'title': 'Account deletion pending',
          'status': 403,
          'data': {
            'purgeAfter': '2026-12-05T12:00:00Z',
            'restoreToken': restoreToken,
            'restoreTokenExpiresAt': '2026-11-05T00:15:00Z',
          },
        });
      case ('POST', '/account/delete/cancel'):
        if ((options.data as Map)['restoreToken'] != restoreToken) {
          return FakeAdapter.json(410, {
            'code': 'ACCOUNT.TOKEN_INVALID',
            'title': 'x',
            'status': 410,
          });
        }
        deletionGrace = false;
        return _loginResponse();
      case ('POST', '/auth/login'):
        return _loginResponse();
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

  testWidgets('saving the nickname refused for want of an address opens the '
      'email form over the nickname gate and sends the save again', (
    tester,
  ) async {
    final backend = _Backend(
      accountMe: {'hasPassword': true, 'email': null, 'displayName': null},
    );
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);
    expect(find.byType(DisplayNameForm), findsOneWidget);

    await tester.enterText(find.byKey(DisplayNameForm.fieldKey), 'Ann');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);

    await registerEmail(tester);
    await tester.pumpAndSettle();

    expect(find.byType(EmailRegisterForm), findsNothing);
    expect(find.byType(DisplayNameForm), findsNothing);
    expect(find.text('First post'), findsOneWidget);
    expect(
      backend.adapter.requests.where(
        (r) => r.method == 'PATCH' && r.path == '/account/me',
      ),
      hasLength(2),
    );
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
    // "Later" ended the refused write; it is not sent after all
    expect(
      backend.adapter.requests.where(
        (r) => r.method == 'POST' && r.path == '/boards/general/posts',
      ),
      hasLength(1),
    );
  });

  testWidgets('a write refused for want of an address waits on the form '
      'above the screen and is sent again once the address is confirmed', (
    tester,
  ) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmailWriteNotice)),
    );
    final router = container.read(routerProvider);
    final boardScreens = router.routerDelegate.currentConfiguration.matches;

    var answered = false;
    unawaited(
      container
          .read(apiClientProvider)
          .noContent('/boards/general/posts', method: 'POST')
          .then((_) => answered = true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);
    expect(answered, isFalse);
    // the screen under it is kept, not replaced: what was typed there stays
    expect(
      router.routerDelegate.currentConfiguration.matches.length,
      boardScreens.length + 1,
    );

    await registerEmail(tester);

    expect(answered, isTrue);
    expect(find.byType(EmailRegisterForm), findsNothing);
    expect(find.text('First post'), findsOneWidget);
    expect(
      backend.adapter.requests.where(
        (r) => r.method == 'POST' && r.path == '/boards/general/posts',
      ),
      hasLength(2),
    );
  });

  testWidgets('a write held on the email form ends with its 403 when the form '
      'goes away by go() and not by pop', (tester) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmailWriteNotice)),
    );

    Object? failure;
    var answered = false;
    unawaited(
      container
          .read(apiClientProvider)
          .noContent('/boards/general/posts', method: 'POST')
          .then((_) => answered = true, onError: (Object e) => failure = e),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);

    container.read(routerProvider).go('/board');
    await tester.pumpAndSettle();

    expect(find.byType(EmailRegisterForm), findsNothing);
    expect(answered, isFalse);
    expect(failure, isNotNull);
    // and the next refused write raises the form again
    unawaited(
      container
          .read(apiClientProvider)
          .noContent('/boards/general/posts', method: 'POST')
          .then((_) {}, onError: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmailRegisterForm), findsOneWidget);
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

  testWidgets('a sign-in into the deletion grace offers to cancel it, and the '
      'restore token stays out of the route, the log and the screen', (
    tester,
  ) async {
    final logged = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    final backend = _Backend(deletionGrace: true);
    await tester.pumpWidget(_app(backend));
    await _signIn(tester);

    // The offer: the date, and the way to say yes or no.
    expect(find.byType(DeletionPendingForm), findsOneWidget);
    expect(find.textContaining('2026-12-05'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeletionPendingForm)),
    );
    final location = container
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();
    expect(location, isNot(contains(_Backend.restoreToken)));
    expect(find.textContaining(_Backend.restoreToken), findsNothing);
    expect(logged.join('\n'), isNot(contains(_Backend.restoreToken)));
    // nothing is signed in yet
    expect(container.read(authSessionProvider), isA<SignedOut>());

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel the deletion'));
    await tester.pumpAndSettle();

    expect(find.text('First post'), findsOneWidget);
    expect(container.read(authSessionProvider), isA<SignedIn>());
    expect(container.read(pendingDeletionProvider), isNull);
    // (the invariant check runs before tearDown callbacks: restore it here)
    debugPrint = oldDebugPrint;
    expect(logged.join('\n'), isNot(contains(_Backend.restoreToken)));
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
