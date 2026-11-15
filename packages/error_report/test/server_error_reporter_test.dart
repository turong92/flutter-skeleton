import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_error_report/skeleton_error_report.dart';

const _trace = '0af7651916cd43dd8448eb211c80319c';

class _Harness {
  _Harness({
    int maxReports = 20,
    Duration dedupeWindow = const Duration(seconds: 60),
    FutureOr<void> Function(Uri, Map<String, Object?>)? send,
    String? Function()? route,
    String? Function()? traceId,
  }) {
    reporter = ServerErrorReporter(
      endpoint: Uri.parse('https://api.example.com/api/v1/client-errors'),
      release: '1.4.2+7',
      platform: 'android',
      traceId: traceId ?? () => _trace,
      route: route ?? () => '/orders/42',
      send:
          send ??
          (url, body) {
            sent.add((url, body));
          },
      dedupeWindow: dedupeWindow,
      maxReports: maxReports,
      now: () => clock,
    );
  }

  late final ServerErrorReporter reporter;
  final sent = <(Uri, Map<String, Object?>)>[];
  DateTime clock = DateTime.utc(2026, 11, 16);
  void advance(Duration d) => clock = clock.add(d);
}

StackTrace _stack(String line) =>
    StackTrace.fromString('#0      main ($line)\n#1      other (x.dart:1:1)');

void main() {
  group('ServerErrorReporter', () {
    test('sends what the owner needs: error, route, release and the last request trace id', () {
      final h = _Harness();

      h.reporter.report(
        StateError('bad state'),
        _stack('a.dart:1:1'),
        source: 'FlutterError.onError',
      );

      final (url, body) = h.sent.single;
      expect(url.toString(), 'https://api.example.com/api/v1/client-errors');
      expect(body['platform'], 'android');
      expect(body['source'], 'FlutterError.onError');
      expect(body['name'], 'StateError');
      expect(body['message'], contains('bad state'));
      expect(body['stack'], contains('a.dart:1:1'));
      expect(body['route'], '/orders/42');
      expect(body['release'], '1.4.2+7');
      expect(body['traceId'], _trace);
      expect(body['count'], 1);
    });

    test('a repeat inside the window is folded into the next report', () {
      final h = _Harness();
      final stack = _stack('a.dart:1:1');

      h.reporter.report(StateError('boom'), stack);
      h.reporter.report(StateError('boom'), stack);
      h.reporter.report(StateError('boom'), stack);
      expect(h.sent, hasLength(1));

      h.advance(const Duration(seconds: 61));
      h.reporter.report(StateError('boom'), stack);
      expect(h.sent, hasLength(2));
      expect(h.sent[1].$2['count'], 3);
    });

    test('flush sends the folded repeats once', () {
      final h = _Harness();
      final stack = _stack('a.dart:1:1');
      h.reporter.report(StateError('boom'), stack);
      h.reporter.report(StateError('boom'), stack);

      h.reporter.flush();
      expect(h.sent, hasLength(2));
      expect(h.sent[1].$2['count'], 1);

      h.reporter.flush();
      expect(h.sent, hasLength(2));
    });

    test('different errors are not folded', () {
      final h = _Harness();
      h.reporter.report(StateError('one'), _stack('a.dart:1:1'));
      h.reporter.report(StateError('two'), _stack('a.dart:1:1'));
      h.reporter.report(StateError('one'), _stack('b.dart:9:9'));
      expect(h.sent, hasLength(3));
    });

    test('stops after the budget of reports per app run', () {
      final h = _Harness(maxReports: 2);
      for (var i = 0; i < 6; i++) {
        h.reporter.report(StateError('distinct $i'), null);
      }
      expect(h.sent, hasLength(2));
    });

    test('cuts oversized text before it leaves the device', () {
      final h = _Harness();
      h.reporter.report(
        StateError('m' * 5000),
        StackTrace.fromString('s' * 20000),
      );
      final body = h.sent.single.$2;
      expect((body['message'] as String).length, 500);
      expect((body['stack'] as String).length, 4000);
    });

    test(
      'a failing or refused send never reaches the app (offline, 429, thrown)',
      () async {
        final throws = _Harness(send: (_, _) => throw StateError('offline'));
        expect(
          () => throws.reporter.report(StateError('a'), null),
          returnsNormally,
        );

        final rejects = _Harness(
          send: (_, _) => Future.error(StateError('429')),
        );
        expect(
          () => rejects.reporter.report(StateError('b'), null),
          returnsNormally,
        );
        await Future<void>.delayed(
          Duration.zero,
        ); // the rejected future is handled, no unhandled error

        final lookups = _Harness(
          route: () => throw StateError('no router yet'),
          traceId: () => throw StateError('no client yet'),
        );
        lookups.reporter.report(StateError('c'), null);
        expect(lookups.sent.single.$2['route'], isNull);
        expect(lookups.sent.single.$2['traceId'], isNull);
      },
    );

    test('reports things that are not Error objects too', () {
      final h = _Harness();
      h.reporter.report('plain text', null);
      expect(h.sent.single.$2['message'], 'plain text');
    });
  });

  test('NoopErrorReporter does nothing', () {
    expect(
      () => const NoopErrorReporter().report(StateError('x'), null),
      returnsNormally,
    );
  });
}
