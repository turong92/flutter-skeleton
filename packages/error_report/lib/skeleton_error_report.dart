/// Error reporting from the device to the backend (kotlin-skeleton `alert`
/// module, `POST /api/v1/client-errors`). See README.md.
library;

export 'src/error_reporter.dart' show ErrorReporter, NoopErrorReporter;
export 'src/install.dart' show installErrorReporting, runReportedZoned;
export 'src/server_error_reporter.dart'
    show ErrorReportSend, ServerErrorReporter;
