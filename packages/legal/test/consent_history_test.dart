import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> event(
  String type,
  String version, {
  String action = 'AGREED',
  String at = '2026-03-01T12:00:00Z',
}) => {
  'type': type,
  'version': version,
  'action': action,
  'locale': 'en',
  'source': 'sign-up',
  'at': at,
};

ResponseBody historyPage(
  List<Map<String, Object?>> values, {
  int page = 0,
  int totalPages = 1,
}) => FakeAdapter.json(200, {
  'values': values,
  'pagination': {
    'page': page,
    'size': 2,
    'totalElements': values.length,
    'totalPages': totalPages,
    'hasNext': page + 1 < totalPages,
    'hasPrevious': page > 0,
  },
  'meta': _meta,
});

LegalApi apiWith(FakeAdapter adapter) =>
    LegalApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter));

void main() {
  test('history reads the caller\'s page and decodes the events', () async {
    final adapter = FakeAdapter(
      (_) => historyPage([event('terms', '2026-01-01')]),
    );

    final page = await apiWith(adapter).history(page: 1, size: 5);

    final request = adapter.requests.single;
    expect(request.path, '/legal/consents/me/history');
    expect(request.queryParameters, {'page': 1, 'size': 5});
    expect(page.items.single.type, 'terms');
    expect(page.items.single.version, '2026-01-01');
    expect(page.items.single.withdrawn, isFalse);
    expect(page.items.single.at, DateTime.utc(2026, 3, 1, 12));
  });

  group('ConsentHistoryView', () {
    Future<FakeAdapter> pumpView(
      WidgetTester tester,
      ResponseBody Function(RequestOptions) onHistory, {
      LegalLabels labels = const LegalLabels(),
    }) async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/legal/consents/me/history') return onHistory(o);
        if (o.path == '/legal/documents') {
          return FakeAdapter.json(200, {
            'values': [
              {
                'type': 'terms',
                'locale': 'en',
                'version': '1',
                'title': 'Terms of service',
                'required': true,
                'requiredAtSignUp': true,
              },
            ],
            'meta': _meta,
          });
        }
        return FakeAdapter.json(404, {
          'code': 'X',
          'title': 'x',
          'status': 404,
        });
      });
      final container = ProviderContainer(
        overrides: [legalApiProvider.overrideWithValue(apiWith(adapter))],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: ConsentHistoryView(labels: labels)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return adapter;
    }

    testWidgets(
      'lists each event: document title, what happened, version, when',
      (tester) async {
        await pumpView(
          tester,
          (_) => historyPage([
            event(
              'marketing',
              '3',
              action: 'WITHDRAWN',
              at: '2026-04-02T00:00:00Z',
            ),
            event('terms', '1'),
          ]),
        );

        expect(find.text('Terms of service'), findsOneWidget);
        // a document the list does not know shows its type
        expect(find.text('marketing'), findsOneWidget);
        expect(find.textContaining('Withdrawn'), findsOneWidget);
        expect(find.textContaining('Agreed'), findsOneWidget);
        expect(find.textContaining('2026-03-01'), findsOneWidget);
      },
    );

    testWidgets('nothing recorded says so', (tester) async {
      await pumpView(tester, (_) => historyPage([]));

      expect(find.text('Nothing recorded yet.'), findsOneWidget);
    });

    testWidgets('more pages are read on request and added below', (
      tester,
    ) async {
      final adapter = await pumpView(
        tester,
        (o) => o.queryParameters['page'] == 0
            ? historyPage([event('terms', '1')], totalPages: 2)
            : historyPage(
                [event('terms', '2', at: '2026-05-05T00:00:00Z')],
                page: 1,
                totalPages: 2,
              ),
      );
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Terms of service'), findsNWidgets(2));
      expect(find.text('Load more'), findsNothing);
      expect(
        adapter.requests
            .where((r) => r.path == '/legal/consents/me/history')
            .map((r) => r.queryParameters['page']),
        [0, 1],
      );
    });

    testWidgets('a failed read offers a retry', (tester) async {
      var fail = true;
      await pumpView(
        tester,
        (_) => fail
            ? FakeAdapter.json(500, {'code': 'X', 'title': 'x', 'status': 500})
            : historyPage([event('terms', '1')]),
      );
      expect(find.text('Could not load the documents.'), findsNothing);
      expect(find.text('Could not load the history.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Terms of service'), findsOneWidget);
    });

    testWidgets('an answer that cannot be read is a failed read too', (
      tester,
    ) async {
      await pumpView(
        tester,
        (_) => FakeAdapter.json(200, {
          'values': [
            {'type': 'terms'},
          ],
          'pagination': {'page': 0},
          'meta': _meta,
        }),
      );

      expect(find.text('Could not load the history.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the Korean labels', (tester) async {
      await pumpView(
        tester,
        (_) => historyPage([event('terms', '1', action: 'WITHDRAWN')]),
        labels: const LegalLabels.ko(),
      );

      expect(find.textContaining('철회'), findsOneWidget);
    });
  });
}
