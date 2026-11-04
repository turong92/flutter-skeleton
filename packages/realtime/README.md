# skeleton_realtime

Server-sent events for the kotlin-skeleton `notification-sse` module (`GET /notifications/sse`). Pure Dart. Web counterpart: react-skeleton `@skeleton/realtime`. Knows nothing of notifications or push: it hands every event to a callback.

```dart
final sse = SseConnection(dio: apiClient.dio, onEvent: (event) { /* event.event, event.data */ });
sse.start();  // foreground, signed in
sse.stop();   // background: start() may open it again
sse.close();  // sign out: never opens again
```

| Export | Meaning |
|---|---|
| `SseConnection(dio:, onEvent:, idleTimeout:)` | Opens the stream through the app's `Dio`, so the Bearer header and the token refresh interceptor apply. `dio.options.baseUrl` is the API root (`.../api/v1`). |
| `SseEvent` | `id`, `event` (the notification type; `message` if the frame has none), `data` (raw text, several `data:` lines joined with `\n`). |

What it guards
- The `connected` greeting and `:` comments (the server's 15 s heartbeat) never reach `onEvent`.
- A dropped line, or none for `idleTimeout` (45 s, three heartbeats), is opened again after 1 s, doubling to 30 s, plus jitter. The idle timer is the package's own: Dio's `receiveTimeout` is off for this call.
- `404` (server without the SSE module): this object does not connect again. Make a new one to try again.
- After `close()` nothing connects again; `stop()` is the same until the next `start()`.
- Tokens and headers are never logged.

Not here: foreground/background handling and what an event means.
