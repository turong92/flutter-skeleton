# sample

The reference app: everything the starter has (sign up with the consent boxes, confirm the mailed code, sign in, reset a forgotten password, delete the account) plus four tabs on top of the kotlin-skeleton `apps/sample` server:

| Tab | What it shows | Packages |
|---|---|---|
| Board | the posts of board `general`, post detail with reactions and comments, write and edit | `board` |
| Notifications | the inbox (paging, pull to refresh, unread marks, mark all as read) with the unread count on the tab; a tapped row opens its link, a board comment row (no link) opens its post | `notifications`, `realtime` |
| Store | products to buy, restore purchases, web checkout when the server allows it, my subscription | `iap` |
| Settings | who is signed in, a way to the notification settings (`/settings/notifications`: this device's push switch, one switch per kind, a test notification, consent to promotional push), social sign-in links, account settings (delete), sign out | `push`, `legal`, `auth`, `social-login` |

The starter is the smaller app (accounts only). Pick the packages you need from here; this app is not meant to ship as it is.

```
lib/main.dart           ProviderScope + MaterialApp.router; Firebase only when its values are set; push hook and foreground SnackBar
lib/config.dart         AppConfig: API_BASE_URL, FIREBASE_* and social values, board code
lib/social_support.dart the providers this build has, the account's sign-in methods, social re-auth, failure texts
lib/firebase_setup.dart FirebaseOptions from the dart-define values (null = no Firebase)
lib/wiring.dart         where the packages meet: legal, board (+ author resolver), push (+ advertising, fallback link), notifications (+ account, row to path), iap on auth's ApiClient
lib/inbox_realtime.dart the notification stream: open only signed in and in front, closed on sign-out, account change or background
lib/login_id_gate.dart  an account without a login ID (`/account/me` `loginId: null`, or any call `403 ACCOUNT.LOGIN_ID_REQUIRED`) is sent to /login-id first; the server answers nothing else until it has one
lib/nickname_gate.dart  an account without a nickname is sent to /nickname after sign-in (sign-up asks for one: the kotlin sample server is `required-on-sign-up`)
lib/router.dart         routes, auth gate, then the account gates in the server's order (ID, consent, nickname; the first one that is up decides; each has a sign-out button), four-tab shell (go_router StatefulShellRoute), unknown path -> inbox
lib/screens/            login · sign-up · verify · forgot/reset password · account (delete) copied from the starter; shell · board · notifications · settings
env/dev.json.example    the dart-define file to copy
```

## Run

1. Start the backend: kotlin-skeleton `apps/sample` (its README says how; the `local` profile has the seed accounts `user@example.com` / `password`, the board `general` and author profiles for `GET /author-profiles`).
2. Run the app:

```bash
cp env/dev.json.example env/dev.json        # git-ignored
flutter run --dart-define-from-file=env/dev.json
```

`API_BASE_URL` is the API root with `/api/v1`. Android emulator: `http://10.0.2.2:<port>/api/v1`; iOS simulator: `http://localhost:<port>/api/v1`. The code never branches on the platform; plain http works in debug builds only (see the starter README).

## Push needs your own Firebase project

This repo has no Firebase project, and the app does not need one to run. With the `FIREBASE_*` values empty (as in the example) Firebase is not started and the settings tab says push is unavailable. To try push:

1. Create a Firebase project, add an Android app (`com.example.sample`, change it for your own project) and an iOS app, and upload an APNs key for iOS.
2. Put the five values (`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID`) in `env/dev.json`. No `google-services.json` or `GoogleService-Info.plist` is needed (the app passes the options in code); if you add them anyway, they are git-ignored.
3. Run the backend with FCM on (`notification-fcm` with the service account of that project).

Behaviour: the device is registered after sign-in and on a token refresh; sign-out removes it from the server first; a notification tapped while the app is in the background or closed opens its link once the session is back (`/board/7`, `/settings`, ...); a message that arrives while the app is in front shows a SnackBar on Android (iOS shows the system banner). The inbox is the original and the push is best effort: a tapped push without a link opens the Notifications tab, a push in front makes the inbox read again, and a tap does not mark the row read.

## Notifications and promotional push

The inbox needs the server's `notification` + `notification-jdbc`; the live update needs `notification-sse` (without it the app asks once, gets a 404 and stays quiet, the inbox still reads again when the app comes back). The stream is open only while somebody is signed in and the app is in front; an event only makes the app read the unread count again. The consent screen for promotional push (`/settings/notifications`) draws nothing on a server without it. What the product must set on the server (not app code): `advertising.title-prefix` as "(ad) <service name>" and `advertising.body-suffix` as the real opt-out path of the app (for example "Opt out: Settings > Notifications"); the default empty suffix sends promotions without a way to opt out.

## Payment

The Store tab is in-app purchase (`iap`): the products the server lists and the store prices, buy, restore, "Pay on the web" (only when the server's channel is `IAP_AND_WEB` or `WEB_ONLY`; it opens the outside browser with a one-time sign-in address) and the subscription the server knows. What the server says to a purchase shows as a SnackBar wherever you are. The account screen tells a person with a live App Store / Google Play subscription to cancel it there before deleting the account (the server cannot end it).

It needs the kotlin-skeleton server with `payment`, `payment-iap` and `payment-appstore` or `payment-googleplay` turned on (the `iap` switch is off by default). Without them the tab says the products could not load; the rest of the app works. No store account is in this repo: create the products in App Store Connect / Play Console and put them in the server's product map. iOS needs the In-App Purchase capability on the app id in Xcode; Android needs the app uploaded to a Play testing track before the billing library lists products. None of this was run on a device here.

## Social sign-in

The sign-in screen shows a button for each provider that this build has **and** the server lists with an app-token entrance (`GET /auth/methods`, `nativeToken`). Google and Kakao are in the build only when their value is set; Apple only on iOS (Apple's own `SignInWithAppleButton`); Naver is always in, its values are in the native files. Settings > "Social sign-in" links another provider to the account (the proof first: password, a mailed code, or, for an account with no address, a fresh sign-in with a linked provider). Deleting the account asks for the same kind of proof; an account with Sign in with Apple has Apple told to drop its access right before the delete call, after the proof (App Review; an Apple-only account sees one Apple sheet, not two). Backing out of a provider's sheet shows nothing; `409 ACCOUNT.SOCIAL_EMAIL_CONFLICT` says to sign in with the existing account and link the provider in Settings; a provider account nobody linked says "No account is registered".

Values, in three places (all examples in the repo, your real ones git-ignored):

| Where | What | Template |
|---|---|---|
| `env/<env>.json` (dart-define) | `GOOGLE_SERVER_CLIENT_ID` (web client id), `GOOGLE_IOS_CLIENT_ID` (empty = `GIDClientID` of the plist), `KAKAO_NATIVE_APP_KEY`; empty hides that button | `env/dev.json.example` |
| `ios/Flutter/Social.xcconfig` | Google client ids and reversed id, Kakao key, Naver id, secret, app name and URL scheme; `Debug` and `Release.xcconfig` include it if it exists | `Social.xcconfig.example` |
| `android/social.properties` | Kakao key, Naver id, secret and name, read by `app/build.gradle.kts` into the manifest; no file = empty values, the build still works | `social.properties.example` |

The Kakao key is in the json and in both native files: keep the three the same. Google on Android needs the package name and the SHA-1 registered in the Google Cloud console (no file). Apple needs the "Sign in with Apple" capability on your App ID and signing team (`Runner.entitlements` has it).

Buttons: Google white with an outline, Kakao `#FEE500`, Naver `#03C75A`, labelled in text only. **The logos are not in this repo**; add them following each guide: [Google](https://developers.google.com/identity/branding-guidelines), [Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple), [Kakao](https://developers.kakao.com/docs/latest/en/kakaologin/design-guide), [Naver](https://developers.naver.com/docs/login/bi/bi.md).

## Native settings in this app

- Android: `POST_NOTIFICATIONS`; `INTERNET` in `src/main`; cleartext http for `10.0.2.2` and `localhost` in `src/debug` only.
- Android social: the Kakao plugin's `AuthCodeHandlerActivity` with the `kakao<key>://oauth` intent filter (checked in the plugin source: its redirect is `kakao<key>://oauth`), the Naver `com.naver.sdk.*` meta-data, `MainActivity` is a `FlutterFragmentActivity`.
- iOS social: `CFBundleURLTypes` (Google reversed id, `kakao<key>`, Naver scheme), `GIDClientID` / `GIDServerClientID`, `LSApplicationQueriesSchemes`, the `Nid*` keys (all from `Social.xcconfig`), `com.apple.developer.applesignin` in `Runner.entitlements`, and Naver's `handleURL` in `SceneDelegate` (the app uses scenes) and `AppDelegate`.
- iOS: `UIBackgroundModes` `remote-notification` and `Runner.entitlements` (`aps-environment`) for push; the Debug configuration uses `Info-Debug.plist` (`Info.plist` plus local-network http). When you change one plist, change the other. Enable the Push Notifications capability for your own App ID and signing team in Xcode.

## Test

```bash
flutter test      # sign in → tabs, board tab, push unavailable, sign-out hook, SnackBar, link after session restore, inbox (stream closed on sign-out, no rows of the previous account, comment row → post) (fake backend)
```

## Not checked on a device

No Android SDK or Xcode ran here, so `flutter build apk`, an iOS build and everything on a real device are open. Check, in this order:

- push: a real notification arrives, a tap opens its link (or the inbox when it has none), the permission dialog, the iOS foreground banner
- the live stream on a device: the inbox count changes when another account comments, the stream closes when the app goes to the background and opens again (with one re-read) when it comes back
- the promotional push consent against a server with `notification-push-legal`, on a device
- a mailed password-reset link opens the app (App Links / Universal Links need your own domain, see the starter README)
- social sign-in with real provider apps: the Google, Apple, Kakao and Naver sheets, the Kakao and Naver return to the app (Android intent filter, iOS `handleURL` in the scene delegate), `import NidThirdPartyLogin` compiling in the Runner target
- the iOS build with the entitlements and Background Modes under your own signing team
