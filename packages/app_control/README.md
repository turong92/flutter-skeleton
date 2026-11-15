# skeleton_app_control

Switch things on and off without a release — the app's half of the kotlin-skeleton `app-control` module. It reads `GET /api/v1/app/config` (public, open during maintenance; contract: kotlin-skeleton `docs/app-control-http-contract.md`) and shows a **maintenance screen**, a **forced update** (installed version below the platform's `minVersion`) or a **recommended update** the person may close. `featureProvider` reads the switches the operator made visible to clients. Web counterpart: react-skeleton `@skeleton/app-control`.

```dart
// 1. Give it the one ApiClient the app uses for everything
appControlApiProvider.overrideWith((ref) => AppControlApi(ref.watch(apiClientProvider))),

// 2. Put the gate above the app
MaterialApp.router(
  builder: (context, child) => AppControlGate(
    labels: const AppControlLabels.ko(),
    child: child!,
  ),
  ...
)

// 3. Read a switch anywhere
final on = ref.watch(featureProvider('new-checkout'));   // a switch nobody made is off
```

| Export | Meaning |
|---|---|
| `AppControlApi(client, {basePath})` | `config()` — `GET /app/config`, no credentials. |
| `AppControlGate(child:, labels:)` | Maintenance screen · forced-update screen (store button) · closable notice above `child`. Reads the config at start and every time the app comes back to the front; while maintenance is on it reads again by itself (`appControlPollIntervalProvider`, 30 s) and goes away when it is lifted. A failed read keeps what was known and never holds the app back. |
| `appStateOf(config, appVersion:, platform:, dismissed:)` | The decision as a pure function: maintenance, then forced, then recommended (not the one already closed), otherwise `AppOk`. |
| `isVersionBelow(version, limit)` · `AppVersion` | Numbers part by part: `1.9` is below `1.10`, `1.2` equals `1.2.0`; `+build` and `-suffix` are cut; unreadable is never below. |
| `appVersionProvider` · `appPlatformProvider` | The installed version name (`package_info_plus`) and `android` / `ios` — override them in tests. |
| `storeLauncherProvider` | Opens the store link (`url_launcher`, outside the app) — override it in tests. |
| `featureProvider(key)` | A switch visible to clients; missing = off. |
| `AppControlLabels` · `AppControlLabels.ko()` | The texts (English default, Korean 해요 style). |

The server never refuses a request for the app version: the minimum is enforced here, from the config. The **Update** button exists only when the platform's `storeUrl` is set on the server. In the starter it is wired with `--packages app-control` (`// #if app-control`).
