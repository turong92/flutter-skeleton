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

## Screens of the optional packages

The starter also carries the default screens of `board`, `storage` (the photo field of the board), `push`, `notifications`, `realtime` and `iap`. In the skeleton they are all there and compiled (so analyze and the tests cover them); `scripts/new-project.sh --packages ...` keeps only the ones picked and removes the rest (screens, routes, wiring, dependencies, native settings). What belongs to a package sits between two marker lines in any text file of the app: `// #if board storage` … `// #endif` (yaml: `# #if`, xml and plist: `<!-- #if ... -->`). The block stays when every id after `#if` is kept (`a|b` = either); `// #file board` on one of the first 3 lines means the whole file goes with the package. Ids are catalog ids: the package folder name with hyphens (`board`, `social-login`), lower case. Rules: no nesting, no "not kept" (in the skeleton the code of all blocks is there together), and a line that looks like a marker but is not well formed, or a marker in a file type the stamp does not read, stops the stamp. Entry points are on the account screen (`/me`): Board, Notifications (unread badge), Notification settings, Store. Firebase values for push come from `env/dev.json` (`FIREBASE_*`, see `lib/config.dart`); on iOS push needs the Push Notifications capability on your App ID (add it in Xcode, like the Associated Domains note below). The board code is `BOARD_CODE` (default `general`); a server whose board needs an author profile also needs `boardAuthorResolverProvider` in `lib/wiring.dart`. Social sign-in (`social-login-google|apple|kakao|naver`): the buttons on the sign-in page, a provider's SDK sign-out with the app's, the proof for deleting an account that has no password or address, and Apple's revoke before a delete. A provider shows only with its values: Google (`GOOGLE_SERVER_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`) and Kakao (`KAKAO_NATIVE_APP_KEY`) from `env/dev.json`, and the native files `ios/Flutter/Social.xcconfig` and `android/social.properties` (copy the `.example` files; git-ignored); Apple is shown on iOS and Naver always, once the server lists them. Sign in with Apple needs the capability on your App ID (`Runner.entitlements` is not linked, like Associated Domains). Not in the starter: linking a provider to a signed-in account (the sample's Social sign-in page), the board's account gates.

## Languages

The texts are in `lib/l10n/app_ko.arb` (template) and `app_en.arb` (gen_l10n; `flutter pub get` writes the Dart files, which are git-ignored). The app follows the device language and falls back to Korean. A package's texts come from its `*Labels`: `context.byLocale(const LoginLabels.ko(), const LoginLabels())`. With the `i18n` package the app also keeps the language the person picked (device only) and shows a menu on the account page. The default language is Korean, but the `legal`, `board`, `iap` and `storage` Labels have English defaults only, so the app fills them from its own ARB texts. A new text goes into both ARB files; `skeleton_i18n/testing.dart` has `arbProblems` to check that they match.

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

The backend mails one https link, `https://app.example.com/reset-password?token=...` (its `link-base-url` setting). With the app installed it opens the `/reset-password` route (App Links / Universal Links); without it the same link opens the web page. The starter carries the native entries for `app.example.com`: the `intent-filter` in `AndroidManifest.xml` and `ios/Runner/Runner.entitlements` (`applinks:`; not linked to the Runner target, because a free personal team cannot sign Associated Domains. With a paid team add the capability and set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`).

The project's part:

- Change the domain in those two files and in the backend's `link-base-url`.
- Serve `/.well-known/assetlinks.json` (package name, signing SHA-256) and `/.well-known/apple-app-site-association` (appID, path `/reset-password*`) from that domain.

Not checked on a device here.
