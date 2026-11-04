# starter

The app a new project takes along: sign up (with the legal consent boxes) and confirm the mailed code, sign in, see `GET /api/v1/auth/me`, reset a forgotten password, delete the account, sign out. A `403 LEGAL.RECONSENT_REQUIRED` opens the consent screen without ending the session. An expired access token is renewed silently; when the renewal fails the app returns to the sign-in screen. Backend: kotlin-skeleton `apps/api`.

```
lib/main.dart          ProviderScope (overrides: auth config, secure token store) + MaterialApp.router + themes
lib/config.dart        AppConfig.apiBaseUrl = String.fromEnvironment('API_BASE_URL')
lib/router.dart        routes, redirect = auth gate then consent gate, reconsent interceptor, consent state cleared on sign-out
lib/wiring.dart        where auth and legal meet (legalApiProvider on the auth ApiClient)
lib/screens/           login · sign-up · verify · forgot/reset password · account (delete) · me
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
flutter test      # sign in/out, sign up → code → signed in, reset, delete, re-consent 403 (fake backend)
```

## Routes

| Path | Screen | Open when signed out |
|---|---|---|
| `/login` · `/me` | sign in · who am I (link to account settings) | login only |
| `/sign-up` | email, password, consent boxes from `legal` | yes |
| `/verify` | the mailed 6-digit code; a right code signs in and goes to `/me` (the pending sign-up survives an app kill) | yes |
| `/forgot-password` | asks for a reset mail | yes |
| `/reset-password?token=` | sets the new password, then `/login` | yes |
| `/account` | delete the account (password typed again), then `/login` | no |
| `/consent` | shown while a `403 LEGAL.RECONSENT_REQUIRED` is pending; returns to where the user was | no |

`publicPaths` in `lib/router.dart` are open in every sign-in state, so each screen navigates itself when it is done.

## Reset links and App Links / Universal Links

The backend mails a web address such as `https://app.example.com/reset-password?token=...` (its `link-base-url` setting). The route above already handles that path, but a tap on the link opens the app only if the project connects its own domain:

- Android: an `intent-filter` with `android:autoVerify="true"` for the domain and `/.well-known/assetlinks.json` served from it.
- iOS: the Associated Domains entitlement `applinks:app.example.com` and `/.well-known/apple-app-site-association` served from it.

The domain, those two files and the native entries are the project's part (they depend on its domain and signing keys), so the starter ships none of them. Until then the link opens in the browser. Not checked on a device here.
