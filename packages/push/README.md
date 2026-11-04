# skeleton_push

Push notification registration and settings for the kotlin-skeleton `notification-push` + `notification-fcm` modules (FCM through `firebase_messaging`).

| Piece | What it is |
|---|---|
| `PushApi` | `config` · `preferences` · `setPreference` · `registerDevice` · `removeDevice` · `sendTest` |
| `PushTokenSource` | Where the token and incoming messages come from. `FirebasePushTokenSource` (default) and `FakePushTokenSource` (`package:skeleton_push/testing.dart`) |
| `pushControllerProvider` | State `unavailable / notAsked / denied / enabled / off`; registers the device |
| `PushPrompt` | In-app band; the tap on its button asks for permission. After a refusal it only points to the device settings |
| `PushSettingsView` | This device's switch, one switch per kind, a test notification |
| `pushSignOutHookProvider` | Deletes this device's registration before sign-out (2 s limit, never throws) |
| `safePushLink` | A tapped notification's `data.link` is kept only if it is an in-app path (`/...`, not `//`, no scheme) |

| `pushFallbackLinkProvider` | Where a tapped notification goes when it has no in-app `link` (e.g. the inbox route). Default null: such a tap opens nothing |

## Advertising consent: `package:skeleton_push/advertising.dart`

Separate library because it needs `skeleton_legal` (a dependency of this package). It does not import `notifications` or `realtime`. For servers with `notification-push-legal` and an advertising kind; on a server without it (`GET /push/advertising` is 404) the view draws nothing.

| Piece | What it is |
|---|---|
| `AdvertisingApi` | `advertising()` = `GET /push/advertising` (sender, `marketing` and `marketing-night` state, night window). Agree and withdraw are `LegalApi.agree` / `withdraw` |
| `AdvertisingSettingsView` | Place it under `PushSettingsView`. Both consents start off and have no switch that turns them on: "Agree" opens the document (`LegalDocumentPage`), the box under it starts unchecked, and only then is the shown version recorded (`source: push-settings`). Night is locked while advertising is off. Off = confirm, then withdraw (advertising takes a still-agreed night with it). A band asks for the two-year reconfirmation (`source: reconfirm`). The server is read again after every change; a failed read shows an error and a retry, never a switch. `409 LEGAL.VERSION_STALE` reads the document again |
| `AdvertisingLabels` | Every text (English defaults) |

```dart
advertisingApiProvider.overrideWith((ref) => AdvertisingApi(ref.watch(apiClientProvider))),
legalApiProvider.overrideWith((ref) => LegalApi(ref.watch(apiClientProvider))),
```

**What the product fills in on the server** (not app code): `advertising.title-prefix` as "(광고) <service name>" and `body-suffix` as the app's real opt-out route (e.g. "Opt out: Settings > Notifications"). With the default empty suffix an advertising push goes out without a way to opt out.

## Wiring

The package does not import `auth` and does not initialize Firebase.

```dart
ProviderScope(overrides: [
  pushApiProvider.overrideWith((ref) => PushApi(ref.watch(apiClientProvider))),
  // true only once the session is restored
  pushSignedInProvider.overrideWith((ref) => ref.watch(sessionProvider) is SignedIn),
  // the app's router; tapped notifications arrive here, already filtered
  pushOpenLinkProvider.overrideWithValue((link) => router.go(link)),
])
```

- Watch `pushControllerProvider` once at the app root. It registers at start, right after sign-in and on every token refresh (`PUT /push/devices/{installationId}`), only when signed in and `config.fcm` is true. `400 PUSH.KIND_DISABLED` means `unavailable`.
- Sign-out: `ref.read(signOutHooksProvider).add(ref.read(pushSignOutHookProvider))` (auth runs hooks before it clears the tokens).
- A tap on a notification with no `link` goes to `pushFallbackLinkProvider` when it is set.
- A notification that started the app (`getInitialMessage`) is held until `pushSignedInProvider` is true, then handed to `pushOpenLinkProvider` once.
- In front: iOS shows the system banner (presentation options are set). Android shows nothing, so listen to `pushMessagesProvider` and show your own (a SnackBar).
- `installationId` is made per install (`[A-Za-z0-9_-]{32}`) and kept in `shared_preferences`; a reinstall gets a new one. Tokens are never logged.
- Texts: pass `PushLabels(...)` (English defaults) to `PushPrompt` and `PushSettingsView`.

## Firebase (two ways, no config file is committed)

This public repo has no Firebase project. The app initializes Firebase itself; without it push is `unavailable` and the app runs as usual.

1. `FirebaseOptions` from `--dart-define` (what `apps/sample` does): build `FirebaseOptions` from `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID` and `FIREBASE_IOS_APP_ID` (kept in an untracked `env/*.json`), and call `Firebase.initializeApp(options: ...)` only when they are set.
2. `flutterfire configure`: generates `firebase_options.dart` and platform files; call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

Put the generated or downloaded files in `.gitignore`: `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, `firebase.json`, `env/*.json`.

iOS also needs the Push Notifications capability, Background Modes (Remote notifications) and an APNs key uploaded to Firebase. Android 13+ needs `POST_NOTIFICATIONS` in the manifest.

## Tests

```
cd packages/push && flutter test
API_BASE_URL=http://localhost:8080/api/v1 API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
  flutter test --tags backend test/backend   # against kotlin apps/sample
```

Not checked on a device (no Android SDK or Xcode here): real receipt, the tap that opens a screen, the system permission dialog, iOS foreground banner. Hand these to QA when a device exists.
