# sample

The reference app: everything the starter has (sign up with the consent boxes, confirm the mailed code, sign in, reset a forgotten password, delete the account) plus two tabs on top of the kotlin-skeleton `apps/sample` server:

| Tab | What it shows | Packages |
|---|---|---|
| Board | the posts of board `general`, post detail with reactions and comments, write and edit | `board` |
| Settings | who is signed in, this device's push switch and one switch per notification kind, a test notification, account settings (delete), sign out | `push`, `auth` |

The starter is the smaller app (accounts only). Pick the packages you need from here; this app is not meant to ship as it is.

```
lib/main.dart           ProviderScope + MaterialApp.router; Firebase only when its values are set; push hook and foreground SnackBar
lib/config.dart         AppConfig: API_BASE_URL, FIREBASE_* values, board code
lib/firebase_setup.dart FirebaseOptions from the dart-define values (null = no Firebase)
lib/wiring.dart         where the packages meet: legal, board (+ author resolver), push on auth's ApiClient
lib/router.dart         routes, auth gate then consent gate, two-tab shell (go_router StatefulShellRoute)
lib/screens/            login · sign-up · verify · forgot/reset password · account (delete) copied from the starter; shell · board · settings
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

Behaviour: the device is registered after sign-in and on a token refresh; sign-out removes it from the server first; a notification tapped while the app is in the background or closed opens its link once the session is back (`/board/7`, `/settings`, ...); a message that arrives while the app is in front shows a SnackBar on Android (iOS shows the system banner).

## Payment

Payment is not in this sample: an app's payment is going to be in-app purchase (IAP), after the kotlin receipt-verification module exists.


## Native settings in this app

- Android: `POST_NOTIFICATIONS`; `INTERNET` in `src/main`; cleartext http for `10.0.2.2` and `localhost` in `src/debug` only.
- iOS: `UIBackgroundModes` `remote-notification` and `Runner.entitlements` (`aps-environment`) for push; the Debug configuration uses `Info-Debug.plist` (`Info.plist` plus local-network http). When you change one plist, change the other. Enable the Push Notifications capability for your own App ID and signing team in Xcode.

## Test

```bash
flutter test      # sign in → tabs, board tab, push unavailable, sign-out hook, SnackBar, link after session restore (fake backend)
```

## Not checked on a device

No Android SDK or Xcode ran here, so `flutter build apk`, an iOS build and everything on a real device are open. Check, in this order:

- push: a real notification arrives, a tap opens its link, the permission dialog, the iOS foreground banner
- a mailed password-reset link opens the app (App Links / Universal Links need your own domain, see the starter README)
- the iOS build with the entitlements and Background Modes under your own signing team
