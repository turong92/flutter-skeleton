/// Where a caught error goes. The app and the handlers only know this
/// interface: a service such as Sentry replaces [ServerErrorReporter] by
/// implementing it, and nothing else changes.
abstract interface class ErrorReporter {
  /// Never throws: a report that cannot be sent is dropped.
  void report(Object error, StackTrace? stackTrace, {String source = 'manual'});

  /// Sends the repeats that were folded and not yet carried by a later report
  /// (the app going to the background).
  void flush();
}

/// Reports nowhere (the default while the backend path is off, and tests).
class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void report(
    Object error,
    StackTrace? stackTrace, {
    String source = 'manual',
  }) {}

  @override
  void flush() {}
}
