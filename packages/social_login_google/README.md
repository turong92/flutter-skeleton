# skeleton_social_login_google

Google for `skeleton_social_login`, with `google_sign_in` 7. It asks Google for an ID token; the kotlin-skeleton `auth-social-google` module checks it (JWKS, `iss`, `aud` = the **web** client id, `exp`).

```dart
GoogleSocialProvider(
  serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'), // web client id
  clientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),          // iOS client id, optional
)
```

The package reads no dart-define itself: the app passes the values in and hides the button when `serverClientId` is empty.

## Setup summary

Google Cloud console, one project: an OAuth client of type **Web** (its id is `serverClientId` here and `client-id` of `auth-social-google` on the server), an **Android** client (package name + signing SHA-1) and an **iOS** client.

| Where | What (example values only) |
|---|---|
| Server | `skeleton.auth-social-google.client-id` = `1234567890-web.apps.googleusercontent.com` |
| App code | `serverClientId` = the same web client id |
| `ios/Runner/Info.plist` | `GIDClientID` = `1234567890-ios.apps.googleusercontent.com`; a URL type with the reversed iOS client id (`com.googleusercontent.apps.1234567890-ios`) |
| Android | nothing in the manifest; the Android OAuth client must match the package name and the signing key (debug and release keys both) |

## Notes

- No nonce goes to Google. `google_sign_in` 7 takes one only in `initialize`, once per app run, so a fresh value per sign-in is not possible; the server compares a nonce only when the token has one.
- `initialize` runs once per provider object on the first sign-in. Keep one `GoogleSocialProvider` for the app.
- Backing out of the Google sheet throws `SocialCancelled`. `signOut()` ends Google's own session.
- Tokens are never printed: the credential's `toString` is redacted and the failure messages hold no token.

Test: `cd packages/social_login_google && flutter test` (the platform interface is replaced by a fake; no device or account is used).
