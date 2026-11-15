import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_app_control/skeleton_app_control.dart';

/// A scripted backend for `GET /app/config`.
class FakeServer {
  bool maintenance = false;
  String? message;
  Map<String, Object?> platforms = {};
  Map<String, Object?> flags = {};
  int status = 200;
  int reads = 0;
  late final FakeAdapter adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    reads++;
    if (status != 200) {
      return FakeAdapter.json(status, {
        'code': 'COMMON.INTERNAL',
        'title': 'x',
        'status': status,
      });
    }
    return FakeAdapter.json(200, {
      'value': {
        'serverTime': '2026-11-16T09:00:00Z',
        'maintenance': {
          'enabled': maintenance,
          'message': maintenance ? message : null,
          'endsAt': null,
        },
        'flags': flags,
        'platforms': platforms,
      },
      'meta': {'timestamp': '2026-11-16T09:00:00Z'},
    });
  }
}

Map<String, Object?> ios({String? min, String? recommended}) => {
  'ios': {
    'minVersion': min,
    'recommendedVersion': recommended,
    'storeUrl': 'https://apps.apple.com/app/id1',
  },
};

/// The gate in an app; [launched] collects the store pages it opened.
Widget app(
  FakeServer server, {
  String version = '1.0',
  List<Uri>? launched,
  Duration poll = const Duration(seconds: 30),
}) => ProviderScope(
  overrides: [
    appControlApiProvider.overrideWithValue(
      AppControlApi(
        ApiClient(baseUrl: 'http://x/api/v1', adapter: server.adapter),
      ),
    ),
    appVersionProvider.overrideWith((ref) => version),
    appPlatformProvider.overrideWithValue('ios'),
    appControlPollIntervalProvider.overrideWithValue(poll),
    storeLauncherProvider.overrideWithValue((url) async {
      launched?.add(url);
      return true;
    }),
  ],
  child: const MaterialApp(
    home: AppControlGate(child: Scaffold(body: Text('the app'))),
  ),
);

void main() {
  testWidgets('with nothing set the app is shown as it is', (tester) async {
    final server = FakeServer();
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
    expect(server.reads, 1);
  });

  testWidgets('a server that cannot be read does not hold the app back', (
    tester,
  ) async {
    final server = FakeServer()..status = 500;
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets(
    'maintenance shows the screen with the message, and goes away when it ends',
    (tester) async {
      final server = FakeServer()
        ..maintenance = true
        ..message = 'Back at 10';
      await tester.pumpWidget(app(server, poll: const Duration(seconds: 5)));
      await tester.pumpAndSettle();

      expect(find.text('Back at 10'), findsOneWidget);
      expect(find.text('the app'), findsNothing);

      server.maintenance = false;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsOneWidget);
      expect(find.text('Back at 10'), findsNothing);
    },
  );

  testWidgets('coming back to the front reads the config again', (
    tester,
  ) async {
    final server = FakeServer();
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);

    server.maintenance = true;
    server.message = 'Down for a bit';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(server.reads, 2);
    expect(find.text('Down for a bit'), findsOneWidget);
  });

  testWidgets(
    'below the minimum: a screen that cannot be closed, the button opens the store',
    (tester) async {
      final server = FakeServer()..platforms = ios(min: '1.10');
      final launched = <Uri>[];
      await tester.pumpWidget(app(server, version: '1.9', launched: launched));
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));
      await tester.pump();

      expect(launched, [Uri.parse('https://apps.apple.com/app/id1')]);
    },
  );

  testWidgets('1.10 is not below 1.9', (tester) async {
    final server = FakeServer()..platforms = ios(min: '1.9');
    await tester.pumpWidget(app(server, version: '1.10'));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets(
    'recommended: the app stays and a notice can be closed for good',
    (tester) async {
      final server = FakeServer()
        ..platforms = ios(min: '1.0', recommended: '1.10');
      await tester.pumpWidget(app(server, version: '1.9'));
      await tester.pumpAndSettle();

      expect(find.text('the app'), findsOneWidget);
      expect(find.text('A new version is available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('A new version is available'), findsNothing);

      // the same recommended version does not come back at the next read
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('A new version is available'), findsNothing);
      expect(find.text('the app'), findsOneWidget);
    },
  );

  testWidgets('a switch is read from the config, and a missing one is off', (
    tester,
  ) async {
    final server = FakeServer()..flags = {'beta': true, 'old': false};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControlApiProvider.overrideWithValue(
            AppControlApi(
              ApiClient(baseUrl: 'http://x/api/v1', adapter: server.adapter),
            ),
          ),
          appVersionProvider.overrideWith((ref) => '1.0'),
          appPlatformProvider.overrideWithValue('ios'),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Text(
                '${ref.watch(featureProvider('beta'))}'
                ' ${ref.watch(featureProvider('old'))}'
                ' ${ref.watch(featureProvider('never-made'))}',
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('false false false'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('true false false'), findsOneWidget);
  });
}
