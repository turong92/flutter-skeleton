// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_legal/skeleton_legal.dart';
import 'package:skeleton_push/advertising.dart';

import 'support/fake_push.dart';

Map<String, Object?> consentJson(
  String type, {
  String state = 'NONE',
  bool effective = false,
  bool reconfirmDue = false,
  String? expiresAt,
}) => {
  'type': type,
  'state': state,
  'agreedAt': state == 'AGREED' || state == 'EXPIRED'
      ? '2026-10-02T03:04:05Z'
      : null,
  'expiresAt': expiresAt,
  'reconfirmDue': reconfirmDue,
  'effective': effective,
};

/// The backend as far as the advertising screen sees it: the state read,
/// the document, and the consent calls (which change the state).
class _Server {
  Map<String, Object?> consent = consentJson('marketing');
  Map<String, Object?> night = consentJson('marketing-night');
  String docVersion = '2026-01-01';
  int status = 200; // GET /push/advertising
  String? agreeFails; // error code of the next POST /legal/consents
  final posts = <Map<String, Object?>>[];
  final withdrawn = <String>[];
  int documentReads = 0;
  int stateReads = 0;

  Map<String, Object?> get _ad => {
    'advertisingTypes': ['promo.notes-tips'],
    'senderName': 'Example Co.',
    'consent': consent,
    'night': night,
    'nightWindow': {'start': '21:00', 'end': '08:00', 'zone': 'Asia/Seoul'},
  };

  Map<String, Object?> get _legal => {
    'blocked': false,
    'items': <Object?>[],
    'missing': <Object?>[],
  };

  late final FakeAdapter adapter = FakeAdapter((o) {
    if (o.method == 'GET' && o.path == '/push/advertising') {
      stateReads++;
      return status == 200
          ? valueBody(_ad)
          : errorBody(status, 'COMMON.NOT_FOUND');
    }
    if (o.method == 'GET' && o.path.startsWith('/legal/documents/')) {
      documentReads++;
      return valueBody({
        'type': o.path.split('/').last,
        'locale': 'en',
        'version': docVersion,
        'title': 'Marketing terms',
        'markdown': 'You agree to promotions.',
      });
    }
    if (o.method == 'POST' && o.path == '/legal/consents') {
      final failure = agreeFails;
      if (failure != null) {
        agreeFails = null;
        return errorBody(409, failure);
      }
      final body = o.data as Map<String, Object?>;
      posts.add(body);
      for (final claim in body['consents']! as List) {
        final type = (claim as Map)['type'];
        if (type == 'marketing') {
          consent = consentJson('marketing', state: 'AGREED', effective: true);
        } else {
          night = consentJson(
            'marketing-night',
            state: 'AGREED',
            effective: consent['effective'] == true,
          );
        }
      }
      return valueBody(_legal);
    }
    if (o.method == 'POST' && o.path.endsWith('/withdraw')) {
      final type = o.path.split('/')[3];
      withdrawn.add(type);
      if (type == 'marketing') {
        consent = consentJson('marketing', state: 'WITHDRAWN');
      } else {
        night = consentJson('marketing-night', state: 'WITHDRAWN');
      }
      return valueBody(_legal);
    }
    return errorBody(404, 'COMMON.NOT_FOUND');
  });
}

Future<_Server> pump(WidgetTester tester, [_Server? server]) async {
  final fake = server ?? _Server();
  final client = clientWith(fake.adapter);
  final container = ProviderContainer(
    overrides: [
      advertisingApiProvider.overrideWithValue(AdvertisingApi(client)),
      legalApiProvider.overrideWithValue(LegalApi(client)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdvertisingSettingsView(now: DateTime.utc(2028, 9, 20)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  return fake;
}

Finder agreeButton(int index) =>
    find.widgetWithText(OutlinedButton, 'Agree').at(index);
final confirm = find.widgetWithText(FilledButton, 'Agree and receive');

Future<void> settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 50));

void main() {
  testWidgets('a backend without the route draws nothing', (tester) async {
    await pump(tester, _Server()..status = 404);

    expect(find.byType(Text), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('a failed read shows an error and no switch, then retries', (
    tester,
  ) async {
    final server = _Server()
      ..consent = consentJson('marketing', state: 'AGREED', effective: true)
      ..status = 500;
    await pump(tester, server);

    expect(
      find.text('Could not load your promotional settings.'),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Agree'), findsNothing);

    server.status = 200;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await settle(tester);

    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('both start off with no switch to turn on', (tester) async {
    await pump(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Agree'), findsNWidgets(2));
  });

  testWidgets('consent is not sent until the box is checked, then posts the '
      'version that was shown and reads the server again', (tester) async {
    final server = await pump(tester);

    await tester.tap(agreeButton(0));
    await settle(tester);
    expect(find.text('You agree to promotions.'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(confirm, warnIfMissed: false);
    await settle(tester);
    expect(server.posts, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    final reads = server.stateReads;
    await tester.tap(confirm);
    await settle(tester);

    expect(server.posts.single, {
      'consents': [
        {'type': 'marketing', 'version': '2026-01-01', 'locale': 'en'},
      ],
      'source': 'push-settings',
    });
    expect(server.stateReads, reads + 1);
    expect(find.byType(Switch), findsOneWidget); // consent on, read back
    expect(find.textContaining('Agreed ('), findsOneWidget); // SnackBar
  });

  testWidgets('night stays locked without advertising consent even when the '
      'server still holds a night agreement', (tester) async {
    await pump(
      tester,
      _Server()..night = consentJson('marketing-night', state: 'AGREED'),
    );

    expect(find.byType(Switch), findsNothing);
    expect(
      find.text('Agree to promotional notifications first.'),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(agreeButton(1)).onPressed,
      isNull,
      reason: 'night cannot be agreed to while advertising is not',
    );
  });

  testWidgets('withdrawing advertising withdraws the night agreement too, '
      'after a confirm that says so', (tester) async {
    final server = _Server()
      ..consent = consentJson('marketing', state: 'AGREED', effective: true)
      ..night = consentJson(
        'marketing-night',
        state: 'AGREED',
        effective: true,
      );
    await pump(tester, server);

    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(
      find.textContaining('Night notifications are turned off too'),
      findsOneWidget,
    );
    expect(server.withdrawn, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw consent'));
    await settle(tester);

    expect(server.withdrawn, ['marketing', 'marketing-night']);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Withdrawn ('), findsOneWidget);
  });

  testWidgets('a stale version reads the document again and the next try '
      'carries the new version', (tester) async {
    final server = await pump(tester);
    await tester.tap(agreeButton(0));
    await settle(tester);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(server.documentReads, 1);

    server
      ..agreeFails = 'LEGAL.VERSION_STALE'
      ..docVersion = '2026-06-01';
    await tester.tap(confirm);
    await settle(tester);

    expect(server.posts, isEmpty);
    expect(server.documentReads, 2);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tester.tap(confirm);
    await settle(tester);

    final claim = (server.posts.single['consents']! as List).single as Map;
    expect(claim['version'], '2026-06-01');
  });

  testWidgets('a consent close to expiry is confirmed again as a reconfirm', (
    tester,
  ) async {
    final server = _Server()
      ..consent = consentJson(
        'marketing',
        state: 'AGREED',
        effective: true,
        reconfirmDue: true,
        expiresAt: '2028-10-01T00:00:00Z',
      );
    await pump(tester, server);

    expect(find.text('Please confirm your consent (D-11)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(tester);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tester.tap(confirm);
    await settle(tester);

    expect(server.posts.single['source'], 'reconfirm');
  });
}
