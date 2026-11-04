# skeleton_api_client

Backend (kotlin-skeleton `modules/platform`) REST client. Dio underneath; it knows the response envelope and the standard error body, and nothing about authentication. Pure Dart, no Flutter dependency (`dart test` runs without a device).

Targets: `platform` module contract (`/api/v1`, `ApiError`, `{ value }` · `{ values }` · `{ values, pagination }` envelopes).

```dart
final client = ApiClient(
  baseUrl: 'https://api.example.com/api/v1',
  headerProviders: [() => {'X-Time-Zone': 'Europe/Berlin'}], // per request, may be async
  onError: (error) => log(error.code),                        // once, just before a call throws
);

final hello = await client.value('/hello', decode: (json) => json['message'] as String);
```

## `ApiClient`

| Member | Meaning |
|---|---|
| `ApiClient(baseUrl:, headerProviders:, onError:, adapter:, timeout:)` | `baseUrl` includes `/api/v1`. `timeout` is 15 s. `adapter` is for tests (a fake `HttpClientAdapter`). |
| `value<T>(path, decode:)` | Unwraps `value`. |
| `list<T>(path, decode:)` | Unwraps `values`. |
| `page<T>(path, decode:)` | `Page<T>`: `items` + `pagination` (`PageInfo`). |
| `noContent(path)` | A call without a body (204). |
| `json:` `query:` `headers:` `method:` | Request body, query, extra headers (they win over providers), HTTP method (default `GET`). |
| `skipAuth: true` | Leaves the header providers out and marks the request (`ApiClient.skipAuthKey`) so the 401 recovery ignores it. Login and refresh use it. |
| `dio` | The Dio instance. Other packages add interceptors here (the auth package adds the 401 recovery). |

## Errors

Every failure is an `ApiRequestError`: `code` · `status` · `message` (`detail`, else `title`) · `traceId` · `fieldErrors` · `apiError`.

| Case | `code` | `status` |
|---|---|---|
| 4xx/5xx with an `ApiError` body | the backend code (`ErrorCodes`) | the HTTP status |
| a response that is not the contract (proxy page, missing envelope key) | `ClientErrorCodes.httpError` | the HTTP status |
| no response (network, timeout, cancel) | `ClientErrorCodes.networkError` | `0` |

`ErrorCodes` holds only codes the backend enum has and the skeleton branches on; add one with the Kotlin entry it mirrors.

## Tests

```bash
cd packages/api_client && dart test
```
