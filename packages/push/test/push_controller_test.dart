import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_push/testing.dart';

import 'support/fake_push.dart';

class _SignedIn extends Notifier<bool> {
  @override
  bool build() => false;
  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final _signedInSwitch = NotifierProvider<_SignedIn, bool>(_SignedIn.new);

class _SlowInitialSource extends FakePushTokenSource {
  _SlowInitialSource({super.permission, super.initial});
  final answer = Completer<void>();

  @override
  Future<PushMessage?> initialMessage() async {
    await answer.future;
    return initial;
  }
}

class _Rig {
  _Rig({
    bool signedIn = true,
    this.fcm = true,
    FakePushTokenSource? source,
    String? fallback,
  }) : source = source ?? FakePushTokenSource() {
    adapter = FakeAdapter((o) {
      final custom = respond?.call(o);
      if (custom != null) return custom;
      if (o.path == '/push/config') return valueBody(configJson(fcm: fcm));
      if (o.method == 'PUT' && o.path.startsWith('/push/devices/')) {
        return valueBody(deviceJson('x'));
      }
      if (o.method == 'DELETE') return FakeAdapter.empty(204);
      return errorBody(404, 'COMMON.NOT_FOUND');
    });
    container = ProviderContainer(
      overrides: [
        pushApiProvider.overrideWithValue(PushApi(clientWith(adapter))),
        pushTokenSourceProvider.overrideWithValue(this.source),
        pushSignedInProvider.overrideWith((ref) => ref.watch(_signedInSwitch)),
        pushOpenLinkProvider.overrideWithValue(opened.add),
        pushFallbackLinkProvider.overrideWithValue(fallback),
      ],
    );
    addTearDown(container.dispose);
    if (signedIn) container.read(_signedInSwitch.notifier).set(true);
    container.listen(pushControllerProvider, (_, _) {});
  }

  final bool fcm;
  final FakePushTokenSource source;
  late final FakeAdapter adapter;
  late final ProviderContainer container;
  ResponseBody? Function(RequestOptions options)? respond;
  final opened = <String>[];

  PushController get controller =>
      container.read(pushControllerProvider.notifier);
  PushStatus get status => container.read(pushControllerProvider).status;
  void signIn(bool value) =>
      container.read(_signedInSwitch.notifier).set(value);

  List<RequestOptions> puts() => [
    for (final r in adapter.requests)
      if (r.method == 'PUT' && r.path.startsWith('/push/devices/')) r,
  ];

  Future<void> settle() => pumpEventQueue(times: 100);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signed out: asks nothing and stays unavailable', () async {
    final rig = _Rig(signedIn: false);
    await rig.settle();

    expect(rig.status, PushStatus.unavailable);
    expect(rig.adapter.requests, isEmpty);
  });

  test('fcm off on the server: no registration', () async {
    final rig = _Rig(fcm: false);
    await rig.settle();

    expect(rig.status, PushStatus.unavailable);
    expect(rig.puts(), isEmpty);
  });

  test(
    'no initialized Firebase: unavailable and the server is not asked',
    () async {
      final rig = _Rig(source: FakePushTokenSource(available: false));
      await rig.settle();

      expect(rig.status, PushStatus.unavailable);
      expect(rig.adapter.requests, isEmpty);
    },
  );

  test(
    'signed in, fcm on, permission given: registers with the token',
    () async {
      final rig = _Rig(
        source: FakePushTokenSource(
          permission: PushPermission.granted,
          token: 'tok-1',
        ),
      );
      await rig.settle();

      expect(rig.status, PushStatus.enabled);
      final put = rig.puts().single;
      expect(put.data, {
        'kind': 'FCM',
        'token': 'tok-1',
        'platform': 'android',
      });
      expect(
        put.path,
        '/push/devices/${await PushDeviceStore().installationId()}',
      );
    },
  );

  test('a PUSH.KIND_DISABLED answer means unavailable', () async {
    final rig = _Rig(
      source: FakePushTokenSource(permission: PushPermission.granted),
    );
    rig.respond = (o) =>
        o.method == 'PUT' ? errorBody(400, PushErrorCodes.kindDisabled) : null;
    await rig.settle();

    expect(rig.status, PushStatus.unavailable);
  });

  test(
    'not asked yet: waits for the person, then registers once allowed',
    () async {
      final rig = _Rig();
      await rig.settle();
      expect(rig.status, PushStatus.notAsked);
      expect(rig.puts(), isEmpty);
      expect(rig.source.permissionRequests, 0);

      await rig.controller.requestPermission();
      await rig.settle();

      expect(rig.source.permissionRequests, 1);
      expect(rig.status, PushStatus.enabled);
      expect(rig.puts(), hasLength(1));
    },
  );

  test('refused: denied, nothing registered', () async {
    final rig = _Rig(
      source: FakePushTokenSource(requestResult: PushPermission.denied),
    );
    await rig.settle();

    await rig.controller.requestPermission();
    await rig.settle();

    expect(rig.status, PushStatus.denied);
    expect(rig.puts(), isEmpty);
  });

  test('already denied in the system: denied without asking again', () async {
    final rig = _Rig(
      source: FakePushTokenSource(permission: PushPermission.denied),
    );
    await rig.settle();

    expect(rig.status, PushStatus.denied);
    expect(rig.source.permissionRequests, 0);
  });

  test('signing in later registers then', () async {
    final rig = _Rig(
      signedIn: false,
      source: FakePushTokenSource(permission: PushPermission.granted),
    );
    await rig.settle();
    expect(rig.puts(), isEmpty);

    rig.signIn(true);
    await rig.settle();

    expect(rig.status, PushStatus.enabled);
    expect(rig.puts(), hasLength(1));
  });

  test('signing out drops back to unavailable', () async {
    final rig = _Rig(
      source: FakePushTokenSource(permission: PushPermission.granted),
    );
    await rig.settle();

    rig.signIn(false);
    await rig.settle();

    expect(rig.status, PushStatus.unavailable);
  });

  test('every token refresh is sent again', () async {
    final rig = _Rig(
      source: FakePushTokenSource(
        permission: PushPermission.granted,
        token: 'tok-1',
      ),
    );
    await rig.settle();

    rig.source.refreshToken('tok-2');
    await rig.settle();

    expect(rig.puts().map((r) => (r.data as Map)['token']), ['tok-1', 'tok-2']);
  });

  test(
    'turned off on this device: deleted, remembered, not registered at start',
    () async {
      final rig = _Rig(
        source: FakePushTokenSource(permission: PushPermission.granted),
      );
      await rig.settle();

      await rig.controller.setDeviceEnabled(false);
      await rig.settle();

      expect(rig.status, PushStatus.off);
      expect(
        rig.adapter.requests.where((r) => r.method == 'DELETE'),
        hasLength(1),
      );

      final again = _Rig(
        source: FakePushTokenSource(permission: PushPermission.granted),
      );
      await again.settle();
      expect(again.status, PushStatus.off);
      expect(again.puts(), isEmpty);

      await again.controller.setDeviceEnabled(true);
      await again.settle();
      expect(again.status, PushStatus.enabled);
      expect(again.puts(), hasLength(1));
    },
  );

  group('tapped notifications', () {
    test('a link tapped while the app runs opens at once', () async {
      final rig = _Rig(
        source: FakePushTokenSource(permission: PushPermission.granted),
      );
      await rig.settle();

      rig.source.tap(PushMessage(link: '/posts/7'));
      await rig.settle();

      expect(rig.opened, ['/posts/7']);
    });

    test('a tap without a link goes to the fallback path', () async {
      final rig = _Rig(
        source: FakePushTokenSource(permission: PushPermission.granted),
        fallback: '/notifications',
      );
      await rig.settle();

      rig.source.tap(PushMessage(title: 'no link'));
      rig.source.tap(PushMessage(link: '/posts/7'));
      await rig.settle();

      expect(rig.opened, ['/notifications', '/posts/7']);
    });

    test('a link to outside the app is dropped', () async {
      final rig = _Rig(
        source: FakePushTokenSource(permission: PushPermission.granted),
      );
      await rig.settle();

      rig.source.tap(PushMessage(link: 'https://evil.example.com'));
      rig.source.tap(PushMessage(link: '//evil.example.com'));
      rig.source.tap(PushMessage(title: 'no link'));
      await rig.settle();

      expect(rig.opened, isEmpty);
    });

    test(
      'the tap that started the app waits until the session is back',
      () async {
        final rig = _Rig(
          signedIn: false,
          source: FakePushTokenSource(
            permission: PushPermission.granted,
            initial: PushMessage(link: '/inbox/3'),
          ),
        );
        await rig.settle();
        expect(rig.opened, isEmpty);

        rig.signIn(true);
        await rig.settle();

        expect(rig.opened, ['/inbox/3']);
      },
    );

    test('the session comes back before initialMessage answers', () async {
      final source = _SlowInitialSource(
        permission: PushPermission.granted,
        initial: PushMessage(link: '/inbox/3'),
      );
      final rig = _Rig(signedIn: false, source: source);
      await rig.settle();

      rig.signIn(true);
      await rig.settle();
      expect(rig.opened, isEmpty);

      source.answer.complete();
      await rig.settle();

      expect(rig.opened, ['/inbox/3']);
    });

    test('the tap that started the app is opened once', () async {
      final rig = _Rig(
        source: FakePushTokenSource(
          permission: PushPermission.granted,
          initial: PushMessage(link: '/inbox/3'),
        ),
      );
      await rig.settle();
      rig.signIn(false);
      await rig.settle();
      rig.signIn(true);
      await rig.settle();

      expect(rig.opened, ['/inbox/3']);
    });
  });

  test('foreground messages come out of pushMessagesProvider', () async {
    final rig = _Rig(
      source: FakePushTokenSource(permission: PushPermission.granted),
    );
    final seen = <String?>[];
    rig.container.listen(
      pushMessagesProvider,
      (_, next) => seen.add(next.value?.title),
    );
    await rig.settle();

    rig.source.receive(PushMessage(title: 'Hello'));
    await rig.settle();

    expect(seen, ['Hello']);
  });
}
