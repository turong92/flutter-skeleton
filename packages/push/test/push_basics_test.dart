import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_push/skeleton_push.dart';

import 'support/fake_push.dart';

void main() {
  group('safePushLink', () {
    test('keeps an app path with query and fragment', () {
      expect(safePushLink('/posts/3?x=1#c'), '/posts/3?x=1#c');
      expect(safePushLink('/'), '/');
    });

    test('drops everything that leaves the app', () {
      for (final bad in [
        '//evil.example.com/a',
        'https://evil.example.com',
        'javascript:alert(1)',
        'posts/3',
        '/\\evil.example.com',
        '',
        '   ',
        null,
        42,
      ]) {
        expect(safePushLink(bad), isNull, reason: '$bad');
      }
    });
  });

  group('PushDeviceStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('makes one id per install and keeps it', () async {
      final first = await PushDeviceStore().installationId();
      final again = await PushDeviceStore().installationId();

      expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
      expect(again, first);
    });

    test('replaces a stored id that the server would refuse', () async {
      SharedPreferences.setMockInitialValues({
        'skeleton_push.installation_id': 'short',
      });

      final id = await PushDeviceStore().installationId();

      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
    });

    test('remembers that the user turned this device off', () async {
      final store = PushDeviceStore();
      expect(await store.optedOut(), isFalse);

      await store.setOptedOut(true);

      expect(await PushDeviceStore().optedOut(), isTrue);
    });
  });

  group('PushApi', () {
    test('config reads fcm and the pushable kinds', () async {
      final adapter = FakeAdapter((_) => valueBody(configJson(fcm: false)));

      final config = await PushApi(clientWith(adapter)).config();

      expect(adapter.requests.single.path, '/push/config');
      expect(config.fcm, isFalse);
      expect(config.types, ['COMMENT', 'NEWS']);
    });

    test('preferences lists a switch per kind', () async {
      final adapter = FakeAdapter(
        (_) => valueBody({
          'items': [
            preferenceJson('COMMENT'),
            preferenceJson('NEWS', push: false, allChannelsMuted: true),
          ],
        }),
      );

      final items = await PushApi(clientWith(adapter)).preferences();

      expect(items.map((p) => p.type), ['COMMENT', 'NEWS']);
      expect(items[1].push, isFalse);
      expect(items[1].allChannelsMuted, isTrue);
    });

    test('setPreference puts the switch of one kind', () async {
      final adapter = FakeAdapter(
        (_) => valueBody(preferenceJson('NEWS', push: false)),
      );

      final pref = await PushApi(clientWith(adapter))
          .setPreference('NEWS', enabled: false);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/push/preferences/NEWS');
      expect(request.data, {'enabled': false});
      expect(pref.push, isFalse);
    });

    test('registerDevice sends the FCM token and platform', () async {
      final adapter = FakeAdapter((_) => valueBody(deviceJson('id-1')));

      await PushApi(clientWith(adapter))
          .registerDevice('id-1', token: 'tok', platform: 'android');

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/push/devices/id-1');
      expect(request.data, {
        'kind': 'FCM',
        'token': 'tok',
        'platform': 'android',
      });
    });

    test('removeDevice and sendTest hit the device paths', () async {
      final adapter = FakeAdapter(
        (o) => o.method == 'DELETE'
            ? FakeAdapter.empty(204)
            : FakeAdapter.json(202, {'meta': meta}),
      );
      final api = PushApi(clientWith(adapter));

      await api.removeDevice('id-1');
      await api.sendTest('id-1');

      expect(adapter.requests[0].method, 'DELETE');
      expect(adapter.requests[0].path, '/push/devices/id-1');
      expect(adapter.requests[1].method, 'POST');
      expect(adapter.requests[1].path, '/push/devices/id-1/test');
    });
  });

  group('removeDeviceBeforeSignOut', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('deletes this installation', () async {
      final adapter = FakeAdapter((_) => FakeAdapter.empty(204));
      final store = PushDeviceStore();

      await removeDeviceBeforeSignOut(PushApi(clientWith(adapter)), store);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/push/devices/${await store.installationId()}');
    });

    test('gives up after the time limit when the network hangs', () async {
      final never = Completer<ResponseBody>();
      final adapter = FakeAdapter((_) => never.future);

      await removeDeviceBeforeSignOut(
        PushApi(clientWith(adapter)),
        PushDeviceStore(),
        timeout: const Duration(milliseconds: 50),
      );

      expect(adapter.requests, hasLength(1)); // asked, did not wait for ever
    });

    test('does not throw when offline or refused', () async {
      final adapter = FakeAdapter((o) => errorBody(500, 'COMMON.INTERNAL'));

      await removeDeviceBeforeSignOut(
        PushApi(clientWith(adapter)),
        PushDeviceStore(),
      );

      expect(adapter.requests, hasLength(1));
    });
  });
}
