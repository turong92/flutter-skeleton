import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_error_report/skeleton_error_report.dart';

class _Recording implements ErrorReporter {
  final reports = <(Object, StackTrace?, String)>[];
  var flushed = 0;

  @override
  void report(
    Object error,
    StackTrace? stackTrace, {
    String source = 'manual',
  }) => reports.add((error, stackTrace, source));

  @override
  void flush() => flushed++;
}

void main() {
  group('installErrorReporting', () {
    late FlutterExceptionHandler? savedFlutter;
    late ErrorCallback? savedPlatform;

    setUp(() {
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });

    test(
      'framework errors and uncaught platform errors reach the reporter',
      () {
        final reporter = _Recording();
        var previousSaw = 0;
        FlutterError.onError = (_) => previousSaw++;
        installErrorReporting(reporter);

        final error = StateError('render failed');
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: StackTrace.current),
        );
        final handled = PlatformDispatcher.instance.onError!(
          StateError('async'),
          StackTrace.current,
        );

        expect(reporter.reports.map((r) => r.$3), [
          'FlutterError.onError',
          'PlatformDispatcher.onError',
        ]);
        expect(reporter.reports.first.$1, same(error));
        expect(
          previousSaw,
          1,
          reason: 'the handler that was there keeps running (console output)',
        );
        expect(handled, isFalse, reason: 'the error is not swallowed');
      },
    );

    test('a silent framework error (one the framework meant to hide) is not reported', () {
      final reporter = _Recording();
      FlutterError.onError = (_) {};
      installErrorReporting(reporter);

      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('hidden'), silent: true),
      );

      expect(reporter.reports, isEmpty);
    });

    test('uninstall puts the previous handlers back', () {
      final reporter = _Recording();
      final uninstall = installErrorReporting(reporter);
      uninstall();
      expect(FlutterError.onError, same(savedFlutter));
      expect(PlatformDispatcher.instance.onError, same(savedPlatform));
    });

    test('a reporter that throws does not break the handlers', () {
      FlutterError.onError = (_) {};
      installErrorReporting(_Throwing());
      expect(
        () => FlutterError.reportError(
          FlutterErrorDetails(exception: StateError('x')),
        ),
        returnsNormally,
      );
      expect(
        () => PlatformDispatcher.instance.onError!(
          StateError('y'),
          StackTrace.empty,
        ),
        returnsNormally,
      );
    });
  });

  test(
    'runReportedZoned reports an error that escapes the guarded body',
    () async {
      final reporter = _Recording();
      runReportedZoned(reporter, () {
        Future<void>(() => throw StateError('late'));
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reporter.reports.single.$3, 'zone');
      expect((reporter.reports.single.$1 as StateError).message, 'late');
    },
  );
}

class _Throwing implements ErrorReporter {
  @override
  void report(
    Object error,
    StackTrace? stackTrace, {
    String source = 'manual',
  }) => throw StateError('reporter down');

  @override
  void flush() {}
}
