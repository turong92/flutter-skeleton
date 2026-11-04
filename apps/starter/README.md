# starter

The app a new project takes along: sign in with email and password, see `GET /api/v1/auth/me`, sign out. An expired access token is renewed silently; when the renewal fails the app returns to the sign-in screen. Backend: kotlin-skeleton `apps/api`.

```
lib/main.dart          ProviderScope (overrides: auth config, secure token store) + MaterialApp.router + themes
lib/config.dart        AppConfig.apiBaseUrl = String.fromEnvironment('API_BASE_URL')
lib/router.dart        /splash (checking) · /login · /me, redirect from skeleton_auth
lib/screens/           LoginScreen (wraps LoginForm) · MeScreen
env/dev.json.example   the dart-define file to copy
```

## Run

```bash
cp env/dev.json.example env/dev.json        # git-ignored
flutter run --dart-define-from-file=env/dev.json
```

`API_BASE_URL` is the API root with `/api/v1`. Where the app runs decides the host:

| Runs on | Host of the backend on your machine |
|---|---|
| Android emulator | `10.0.2.2` (set in `env/dev.json`; the code never branches on it) |
| iOS simulator | `localhost` |

The starter backend has no seed account: start it with `skeleton.account.seed.accounts` (see `packages/auth/README.md`).

## Plain http is for debug builds only

- Android: `android/app/src/debug/` carries a `network_security_config` that allows cleartext for `10.0.2.2` and `localhost` only. `src/main` has no such config, so a release build is https-only. `src/main` does declare `INTERNET`.
- iOS: the Debug configuration of the Runner target uses `Runner/Info-Debug.plist`, which is `Info.plist` plus `NSAppTransportSecurity > NSAllowsLocalNetworking`. Release and Profile use `Info.plist`. When you change one plist, change the other.

## Test

```bash
flutter test      # sign in → my account → sign out, wrong password, restart restore (fake backend)
```
