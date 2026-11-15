import 'dart:async';

import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

/// Hands framework errors (`FlutterError.onError`) and errors nobody caught
/// (`PlatformDispatcher.instance.onError`) to [reporter]. The handlers that
/// were there keep running (the console output stays) and nothing is marked as
/// handled. Returns a function that puts the previous handlers back.
void Function() installErrorReporting(ErrorReporter reporter) {
  final previousFlutter = FlutterError.onError;
  final previousPlatform = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    _safely(
      () => reporter.report(
        details.exception,
        details.stack,
        source: 'FlutterError.onError',
      ),
    );
    if (previousFlutter != null) {
      previousFlutter(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _safely(
      () => reporter.report(error, stack, source: 'PlatformDispatcher.onError'),
    );
    return previousPlatform?.call(error, stack) ?? false;
  };

  return () {
    FlutterError.onError = previousFlutter;
    PlatformDispatcher.instance.onError = previousPlatform;
  };
}

/// Runs [body] in a zone whose uncaught errors go to [reporter]. As with any
/// `runZonedGuarded` such an error no longer ends the isolate, so it is also
/// written to the console, as it would be without the zone. Use it around the
/// whole of `main`, so `WidgetsFlutterBinding.ensureInitialized()` and `runApp`
/// share the zone.
R? runReportedZoned<R>(ErrorReporter reporter, R Function() body) =>
    runZonedGuarded(body, (error, stack) {
      _safely(() => reporter.report(error, stack, source: 'zone'));
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack, library: 'zone'),
      );
    });

void _safely(void Function() action) {
  try {
    action();
  } catch (_) {
    // A reporter that fails must not take the handler down with it.
  }
}
