import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> summary(
  String type, {
  String locale = 'en',
  String version = '1',
  bool requiredAtSignUp = true,
  bool required = true,
}) => {
  'type': type,
  'locale': locale,
  'version': version,
  'title': '$type title $locale',
  'required': required,
  'requiredAtSignUp': requiredAtSignUp,
};

ResponseBody status(List<Map<String, Object?>> missing) =>
    FakeAdapter.json(200, {
      'value': {'blocked': missing.isNotEmpty, 'items': [], 'missing': missing},
      'meta': _meta,
    });

/// A scripted backend for the legal screens.
class FakeLegal {
  List<Map<String, Object?>> documents = [
    summary('terms'),
    summary('terms', locale: 'ko'),
    summary('privacy'),
    summary('marketing', requiredAtSignUp: false, required: false),
    // agreed later, not at sign-up: not on the sign-up list
    summary('tax', requiredAtSignUp: false),
  ];
  bool failDocuments = false;
  List<Map<String, Object?>> statusMissing = [];
  int statusReads = 0;
  ResponseBody Function(RequestOptions)? onAgree;
  late final FakeAdapter adapter = FakeAdapter(_handle);

  ResponseBody _handle(RequestOptions options) {
    switch ((options.method, options.path)) {
      case ('GET', '/legal/documents'):
        return failDocuments
            ? FakeAdapter.json(500, {
                'code': 'COMMON.INTERNAL',
                'title': 'x',
                'status': 500,
              })
            : FakeAdapter.json(200, {'values': documents, 'meta': _meta});
      case ('GET', final path) when path.startsWith('/legal/documents/'):
        final type = path.substring('/legal/documents/'.length);
        return FakeAdapter.json(200, {
          'value': {
            ...summary(
              type,
              version: options.queryParameters['version'] as String? ?? '1',
              locale: options.queryParameters['locale'] as String? ?? 'en',
            ),
            'markdown': '# $type\n\n**not rendered**',
          },
          'meta': _meta,
        });
      case ('GET', '/legal/consents/me'):
        statusReads++;
        return status(statusMissing);
      case ('POST', '/legal/consents'):
        return onAgree!(options);
    }
    return FakeAdapter.json(404, {'code': 'X', 'title': 'x', 'status': 404});
  }

  LegalApi get api =>
      LegalApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter));
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  FakeLegal legal,
  Widget child,
) async {
  final container = ProviderContainer(
    overrides: [legalApiProvider.overrideWithValue(legal.api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('SignUpConsents', () {
    testWidgets(
      'a box per sign-up document and per optional one, all unchecked; the rest is left out',
      (tester) async {
        final values = <SignUpConsentsValue>[];
        await pump(
          tester,
          FakeLegal(),
          SignUpConsents(locale: 'ko', onChanged: values.add),
        );

        expect(find.text('terms title ko'), findsOneWidget);
        expect(find.text('privacy title en'), findsOneWidget); // no ko: first
        expect(find.text('marketing title en'), findsOneWidget);
        expect(find.textContaining('tax'), findsNothing);
        expect(find.text('Required'), findsNWidgets(2));
        expect(find.text('Optional'), findsOneWidget);
        expect(
          tester
              .widgetList<Checkbox>(find.byType(Checkbox))
              .map((c) => c.value),
          [false, false, false],
        );
        expect(values.last.complete, isFalse);
        expect(values.last.claims, isEmpty);
      },
    );

    testWidgets(
      'complete once the required ones are checked; the claims carry the version and locale shown',
      (tester) async {
        final values = <SignUpConsentsValue>[];
        await pump(
          tester,
          FakeLegal()..documents[0] = summary('terms', version: '2026-05-01'),
          SignUpConsents(locale: 'en', onChanged: values.add),
        );

        await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
        await tester.pump();
        expect(values.last.complete, isFalse);

        await tester.tap(find.byKey(SignUpConsents.checkKey('privacy')));
        await tester.pump();
        expect(values.last.complete, isTrue);
        expect(values.last.toJson(), [
          {'type': 'terms', 'version': '2026-05-01', 'locale': 'en'},
          {'type': 'privacy', 'version': '1', 'locale': 'en'},
        ]);

        // an optional one joins only when the user checks it
        await tester.tap(find.byKey(SignUpConsents.checkKey('marketing')));
        await tester.pump();
        expect(values.last.claims.map((c) => c.type), [
          'terms',
          'privacy',
          'marketing',
        ]);
        await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
        await tester.pump();
        expect(values.last.complete, isFalse);
      },
    );

    testWidgets('no required document: complete from the start', (
      tester,
    ) async {
      final values = <SignUpConsentsValue>[];
      await pump(
        tester,
        FakeLegal()
          ..documents = [
            summary('marketing', requiredAtSignUp: false, required: false),
          ],
        SignUpConsents(onChanged: values.add),
      );

      expect(values.last.complete, isTrue);
      expect(values.last.claims, isEmpty);
    });

    testWidgets(
      'documents read again with a new version: the old checks do not carry over',
      (tester) async {
        final legal = FakeLegal();
        final values = <SignUpConsentsValue>[];
        final container = await pump(
          tester,
          legal,
          SignUpConsents(onChanged: values.add),
        );
        await tester.tap(find.byKey(SignUpConsents.checkKey('terms')));
        await tester.tap(find.byKey(SignUpConsents.checkKey('privacy')));
        await tester.pump();
        expect(values.last.complete, isTrue);

        legal.documents = [
          summary('terms', version: '2'),
          summary('privacy'),
          summary('marketing', requiredAtSignUp: false, required: false),
        ];
        container.invalidate(legalDocumentsProvider);
        await tester.pumpAndSettle();

        expect(values.last.complete, isFalse);
        expect(values.last.claims.map((c) => c.type), ['privacy']);
        expect(values.last.claims.single.version, '1');
      },
    );

    testWidgets('a failed load shows a retry button that loads again', (
      tester,
    ) async {
      final legal = FakeLegal()..failDocuments = true;
      await pump(tester, legal, SignUpConsents(onChanged: (_) {}));
      expect(find.text('Could not load the documents.'), findsOneWidget);

      legal.failDocuments = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('Read opens the document as plain markdown text', (
      tester,
    ) async {
      await pump(tester, FakeLegal(), SignUpConsents(onChanged: (_) {}));

      await tester.tap(find.byKey(SignUpConsents.viewKey('terms')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('**not rendered**', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('# terms'), findsOneWidget);
    });

    testWidgets('tapping the title toggles the box on and off', (tester) async {
      await pump(tester, FakeLegal(), SignUpConsents(onChanged: (_) {}));
      bool checked() => tester
          .widget<Checkbox>(find.byKey(SignUpConsents.checkKey('terms')))
          .value!;

      await tester.tap(find.text('terms title en'));
      await tester.pump();
      expect(checked(), isTrue);

      await tester.tap(find.text('terms title en'));
      await tester.pump();
      expect(checked(), isFalse);
    });

    testWidgets('labels are parameters', (tester) async {
      await pump(
        tester,
        FakeLegal(),
        SignUpConsents(
          onChanged: (_) {},
          labels: const LegalLabels(required: '필수', optional: '선택', view: '보기'),
        ),
      );

      expect(find.text('필수'), findsNWidgets(2));
      expect(find.text('선택'), findsOneWidget);
      expect(find.text('보기'), findsNWidgets(3));
    });

    testWidgets('what can be pressed has a border or a fill at rest', (
      tester,
    ) async {
      await pump(tester, FakeLegal(), SignUpConsents(onChanged: (_) {}));

      expect(find.byType(OutlinedButton), findsNWidgets(3));
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('ReconsentScreen', () {
    const missing = [
      {'type': 'terms', 'version': '2', 'reason': 'OUTDATED'},
      {'type': 'privacy', 'version': '3', 'reason': 'MISSING'},
    ];

    Future<(ProviderContainer, FakeLegal)> open(
      WidgetTester tester, {
      List<Map<String, Object?>> needs = missing,
      VoidCallback? onLeave,
    }) async {
      final legal = FakeLegal();
      final container = ProviderContainer(
        overrides: [legalApiProvider.overrideWithValue(legal.api)],
      );
      addTearDown(container.dispose);
      container.read(reconsentProvider.notifier).require([
        for (final m in needs) MissingConsent.fromJson(m),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ReconsentScreen(locale: 'en', onLeave: onLeave),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, legal);
    }

    testWidgets(
      'agreeing posts exactly the missing versions and then clears the state',
      (tester) async {
        final (container, legal) = await open(tester);
        legal.onAgree = (_) => status(const []);

        expect(find.text('terms title en'), findsOneWidget);
        FilledButton agree() =>
            tester.widget(find.byKey(ReconsentScreen.agreeKey));
        expect(agree().onPressed, isNull);

        await tester.tap(find.byKey(ReconsentScreen.checkKey('terms')));
        await tester.tap(find.byKey(ReconsentScreen.checkKey('privacy')));
        await tester.pump();
        expect(agree().onPressed, isNotNull);
        await tester.tap(find.byKey(ReconsentScreen.agreeKey));
        await tester.pumpAndSettle();

        final post = legal.adapter.requests.last;
        expect(post.data, {
          'consents': [
            {'type': 'terms', 'version': '2', 'locale': 'en'},
            {'type': 'privacy', 'version': '3', 'locale': 'en'},
          ],
          'source': 're-consent',
        });
        expect(container.read(reconsentProvider), isEmpty);
      },
    );

    testWidgets(
      'a newer version in between keeps the screen with the new list',
      (tester) async {
        final (container, legal) = await open(tester);
        legal.onAgree = (_) => status([
          {'type': 'terms', 'version': '4', 'reason': 'OUTDATED'},
        ]);

        await tester.tap(find.byKey(ReconsentScreen.checkKey('terms')));
        await tester.tap(find.byKey(ReconsentScreen.checkKey('privacy')));
        await tester.pump();
        await tester.tap(find.byKey(ReconsentScreen.agreeKey));
        await tester.pumpAndSettle();

        final now = container.read(reconsentProvider);
        expect(now.map((m) => (m.type, m.version)), [('terms', '4')]);
        expect(find.byKey(ReconsentScreen.checkKey('privacy')), findsNothing);
        expect(
          tester
              .widget<Checkbox>(find.byKey(ReconsentScreen.checkKey('terms')))
              .value,
          isFalse,
        );
      },
    );

    testWidgets('the sign-out button calls onLeave', (tester) async {
      var left = 0;
      await open(tester, onLeave: () => left++);
      await tester.tap(find.byKey(ReconsentScreen.leaveKey));
      expect(left, 1);
    });

    testWidgets(
      'a stale version (409) shows the message and reads the status again',
      (tester) async {
        final (container, legal) = await open(tester);
        legal.onAgree = (_) => FakeAdapter.json(409, {
          'code': 'LEGAL.VERSION_STALE',
          'title': 'x',
          'status': 409,
          'data': {
            'stale': [
              {'type': 'terms', 'requiredVersion': '9'},
            ],
          },
        });
        legal.statusMissing = [
          {'type': 'terms', 'version': '9', 'reason': 'OUTDATED'},
        ];

        await tester.tap(find.byKey(ReconsentScreen.checkKey('terms')));
        await tester.tap(find.byKey(ReconsentScreen.checkKey('privacy')));
        await tester.pump();
        await tester.tap(find.byKey(ReconsentScreen.agreeKey));
        await tester.pumpAndSettle();

        expect(legal.statusReads, 1);
        expect(container.read(reconsentProvider).single.version, '9');
        expect(
          find.text('Could not save your agreement. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}
