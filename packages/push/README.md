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
