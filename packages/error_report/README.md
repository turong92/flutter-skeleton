# skeleton_error_report

Sends the errors of the device (the app, not the server) to the backend's `POST /api/v1/client-errors` (kotlin-skeleton `alert` module, `docs/alert.md` "Errors from the user's device"), where each becomes one structured log line and a pile-up becomes one alert. Web counterpart: react-skeleton `@skeleton/api-client` (`createErrorReporter`). The app only knows the `ErrorReporter` interface, so a service such as Sentry can replace `ServerErrorReporter` later without touching a screen.

```dart
final reporter = ServerErrorReporter(
  endpoint: Uri.parse('$apiBaseUrl/client-errors'),
  release: '1.4.2+7',                                    // which build the error came from
  traceId: () => apiClient.lastTraceId,                  // the last API request: grep the same id in the server log
  route: () => router.routeInformationProvider.value.uri.path,
);
installErrorReporting(reporter);                         // FlutterError.onError + PlatformDispatcher.instance.onError
await runReportedZoned(reporter, () => start());         // errors that escape the zone of main
AppLifecycleListener(onPause: reporter.flush);           // the folded repeats are sent when the app leaves the front
```

| Export | Meaning |
|---|---|
| `ErrorReporter` | `report(error, stackTrace, {source})` and `flush()`. Never throws. |
| `ServerErrorReporter(endpoint:, release:, platform:, traceId:, route:, send:, dedupeWindow:, maxReports:)` | The default. `platform` defaults to the target platform (`android` / `ios`). `send` replaces the transport (tests, another sink). |
| `NoopErrorReporter` | Reports nowhere (the starter's choice while `ERROR_REPORT` is off). |
| `installErrorReporting(reporter)` | Chains in front of the existing handlers (console output stays, nothing is marked handled). Returns a function that puts the previous ones back. |
| `runReportedZoned(reporter, body)` | `runZonedGuarded` that reports and also prints the error. |

What it guards
- **Never hurts the app**: a send that throws or is refused (offline, 429, 404 while the server path is off), a failing route or trace lookup, a reporter that throws inside a handler — all swallowed. The report is dropped, there is **no queue** (an app that was offline has bigger problems than this report; keep it small).
- **Folds repeats**: the first of an equal error (type + message + the first two stack lines) goes out at once; repeats inside `dedupeWindow` (60 s) are counted and ride on the next report as `count`, or on `flush`.
- **Budget**: at most `maxReports` (20) per app run, so a build loop cannot flood the server (which also limits per client).
- **Cuts**: message 500, stack 4,000 characters, before sending. The server cuts and scrubs again (tokens, e-mail addresses, URL queries) — still, never put a secret in an error message.
- The transport is a plain `Dio` without interceptors: a report must not trigger a token refresh or a sign-out.

The trace id needs `skeleton_api_client`'s `ApiClient.lastTraceId` (every request carries a W3C `traceparent`). Backend: kotlin-skeleton `alert` (`skeleton.alert.client-errors.enabled=true`, **off by default**).

## Tests

```bash
cd packages/error_report && flutter test
```
