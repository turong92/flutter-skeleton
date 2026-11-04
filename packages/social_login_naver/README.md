# skeleton_social_login_naver

Naver sign-in for [`skeleton_social_login`](../social_login/README.md), on `flutter_naver_login` 2.1. `NaverSocialProvider` (server provider id `naver`) calls `logIn()` then `getCurrentAccessToken()` and returns the Naver **access token**; the kotlin-skeleton `auth-social-naver` module checks it with Naver's profile API (`/v1/nid/me`) and answers with its own session.

| Piece | What it is |
|---|---|
| `NaverSocialProvider()` | `id` `naver` · `obtain(nonce)` → `SocialCredential.accessToken` · `signOut()` |

- The Naver SDK takes no nonce, so `nonce` is ignored.
- Backing out is `SocialCancelled`. Android answers it with status `loggedOut`; iOS with an error whose message says "cancelled". Any other error is an `Exception` with the SDK's message.
- `signOut()` is `logOutAndDeleteToken()`: it ends the SDK session and deletes the SDK's stored tokens.
- `NaverToken.toString()` of the plugin prints the tokens. This package never prints that object; do not log it in the app either.

## Facts to know before choosing it

- **The Naver SDK puts the client secret in the app** (Android meta-data / strings, iOS `Info.plist` `NidClientSecret`). That is Naver's official way for the app SDK; it cannot be avoided. The same client id and secret are also what the server's code flow uses.
- **Whether the Naver member id differs per app is not confirmed**, and no official API was found that tells which app issued an access token. The server checks the token with Naver's profile API only. A token from another Naver app of the same person is therefore accepted if the id is the same across apps. This is the usual way domestic services do it and the module is off by default; decide with that in mind.
- The plugin is the most used one but has an unverified publisher on pub.dev and its last release (2.1.1) is not recent. An alternative is `naver_login_sdk` (verified publisher, fewer users). Replacing it means writing another `SocialProvider` with the same three members; nothing else changes.

## Wiring

```dart
ProviderScope(overrides: [
  socialProvidersProvider.overrideWithValue([NaverSocialProvider()]),
])
```

Naver needs no Dart initialization; everything is in the platform files.

## Platform settings (the app's files; not changed by this package)

Values come from Naver Developers (Application, "Naver Login"); examples only: client id `exampleClientId`, secret `exampleClientSecret`, app name `Example App`, URL scheme `exampleapp`.

- Android: `<meta-data>` `com.naver.sdk.clientId`, `com.naver.sdk.clientSecret`, `com.naver.sdk.clientName` in `AndroidManifest.xml`, and `MainActivity` must extend `FlutterFragmentActivity`.
- iOS `Info.plist`: `NidClientID`, `NidClientSecret`, `NidAppName`, `NidUrlScheme`; a `CFBundleURLTypes` entry with the same scheme; `LSApplicationQueriesSchemes` with `naversearchapp` and `naversearchthirdlogin`.
- iOS `AppDelegate.application(_:open:options:)` must pass the URL to `NidOAuth.shared.handleURL(url)` (`import NidThirdPartyLogin`) and return `true` when it handled it.
- Naver Developers: register the Android package name and the iOS bundle id, and the URL scheme.
- The server reads `skeleton.auth-social.providers.naver` (see kotlin-skeleton `docs/real-provider-setup.md`).

## Button

Shape and logo are the app's. This repo ships no Naver logo image; follow Naver's design guide: <https://developers.naver.com/docs/login/bi/bi.md>.

## Test

`cd packages/social_login_naver && flutter test`. The plugin's method channel is replaced by a fake; a real Naver login needs a device and a Naver app, and is not tested here.
