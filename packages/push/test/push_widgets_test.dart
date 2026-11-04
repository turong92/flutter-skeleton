import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_push/testing.dart';

import 'support/fake_push.dart';

class FakePushServer {
  List<Map<String, Object?>> prefs = [
    preferenceJson('COMMENT'),
    preferenceJson('NEWS', allChannelsMuted: true),
  ];
  ResponseBody? Function(RequestOptions options)? respond;
  late final FakeAdapter adapter = FakeAdapter((o) {
    final custom = respond?.call(o);
    if (custom != null) return custom;
    if (o.path == '/push/config') return valueBody(configJson());
    if (o.method == 'GET' && o.path == '/push/preferences') {
      return valueBody({'items': prefs});
    }
    if (o.method == 'PUT' && o.path.startsWith('/push/preferences/')) {
      final type = o.path.split('/').last;
      return valueBody(preferenceJson(type, push: (o.data as Map)['enabled'] as bool));
    }
    if (o.method == 'PUT') return valueBody(deviceJson('x'));
    if (o.method == 'DELETE') return FakeAdapter.empty(204);
    if (o.path.endsWith('/test')) return FakeAdapter.json(202, {'meta': meta});
    return errorBody(404, 'COMMON.NOT_FOUND');
  });
}

Future<FakePushServer> pumpPush(
  WidgetTester tester,
  Widget child, {
  FakePushTokenSource? source,
  FakePushServer? server,
}) async {
  SharedPreferences.setMockInitialValues({});
  final fake = server ?? FakePushServer();
  final container = ProviderContainer(
    overrides: [
      pushApiProvider.overrideWithValue(PushApi(clientWith(fake.adapter))),
      pushTokenSourceProvider.overrideWithValue(source ?? FakePushTokenSource()),
      pushSignedInProvider.overrideWithValue(true),
    ],
  );
  addTearDown(container.dispose);
  container.listen(pushControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  return fake;
}

void main() {
  group('PushPrompt', () {
    testWidgets('asks nothing until the button is tapped', (tester) async {
      final source = FakePushTokenSource();
      await pumpPush(tester, const PushPrompt(), source: source);

      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(source.permissionRequests, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Turn on notifications'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(source.permissionRequests, 1);
      expect(find.text('Turn on notifications'), findsNothing); // registered: band gone
    });

    testWidgets('after a refusal only explains where the setting is', (tester) async {
      await pumpPush(
        tester,
        const PushPrompt(),
        source: FakePushTokenSource(permission: PushPermission.denied),
      );

      expect(find.textContaining('device settings'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('texts come from the labels', (tester) async {
      await pumpPush(
        tester,
        const PushPrompt(labels: PushLabels(promptEnable: '알림 켜기')),
      );

      expect(find.text('알림 켜기'), findsOneWidget);
    });

    testWidgets('is hidden while open is false or when push cannot work', (tester) async {
      await pumpPush(tester, const PushPrompt(open: false));
      expect(find.byType(FilledButton), findsNothing);

      await pumpPush(
        tester,
        const PushPrompt(),
        source: FakePushTokenSource(available: false),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('PushSettingsView', () {
    testWidgets('shows the device switch, the kinds and the test button', (tester) async {
      await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.granted),
      );

      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(find.text('COMMENT'), findsOneWidget);
      expect(find.text('NEWS'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Send a test notification'), findsOneWidget);
    });

    testWidgets('a kind switch puts that kind; one muted in all channels is read only', (tester) async {
      final server = await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.granted),
      );

      final switches = find.byType(Switch);
      expect(tester.widget<Switch>(switches.at(2)).onChanged, isNull); // NEWS

      await tester.tap(switches.at(1)); // COMMENT
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      final put = server.adapter.requests.singleWhere((r) => r.path == '/push/preferences/COMMENT');
      expect(put.data, {'enabled': false});
    });

    testWidgets('the device switch off deletes the registration', (tester) async {
      final server = await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.granted),
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(server.adapter.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    });

    testWidgets('the test button posts the test and says it was sent', (tester) async {
      final server = await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.granted),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Send a test notification'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(server.adapter.requests.where((r) => r.path.endsWith('/test')), hasLength(1));
      expect(find.text('Sent. It should arrive in a moment.'), findsOneWidget);
    });

    testWidgets('a second test within a minute says to wait', (tester) async {
      final server = FakePushServer()
        ..respond = (o) => o.path.endsWith('/test') ? errorBody(429, PushErrorCodes.testTooSoon) : null;
      await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.granted),
        server: server,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Send a test notification'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(find.text('One test a minute. Try again shortly.'), findsOneWidget);
    });

    testWidgets('unavailable push shows the reason and no switches', (tester) async {
      await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(available: false),
      );

      expect(find.text('Notifications are not available in this app.'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('denied: the device switch is off, locked and explains', (tester) async {
      await pumpPush(
        tester,
        const PushSettingsView(),
        source: FakePushTokenSource(permission: PushPermission.denied),
      );

      final device = tester.widget<Switch>(find.byType(Switch).first);
      expect(device.value, isFalse);
      expect(device.onChanged, isNull);
      expect(find.textContaining('device settings'), findsOneWidget);
    });
  });
}
