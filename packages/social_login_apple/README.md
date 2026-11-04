# skeleton_social_login_apple

Sign in with Apple for `skeleton_social_login`, with `sign_in_with_apple` 8. iOS app only in this version (Android and web Apple need a Services ID and a callback; a later step). The kotlin-skeleton `auth-social-apple` module checks the identityToken (JWKS, `iss`, `aud` = the bundle id, `exp`, nonce required).

```dart
final apple = AppleSocialProvider();
if (apple.isVisible) { /* iOS: show the Sign in with Apple button */ }
```

`isVisible` is `Platform.isIOS` (false on web). The package draws no button: use the SDK's `SignInWithAppleButton` (Apple's HIG) and call `signIn(apple)` from the core controller.

## Nonce

The SDK gets `sha256(nonce)` as hex; Apple puts that in the token's `nonce` claim. The server gets the raw nonce in the credential and hashes it to compare. A stolen token alone is useless without the raw value.

## Account deletion

App Review requires revoking the Apple tokens when an account is deleted. Do it **right before `POST /account/delete`, after the proof is in hand** (with `skeleton_auth` that is `DeleteAccountForm(beforeDelete: ...)`): a revoke earlier lets the proof's own Apple sheet link the app again.

When the account is proven by its Apple sign-in, take both from one sheet: `final proof = await apple.obtainForDelete(nonce)` gives `proof.credential` (for `socialReauth`) and `proof.authorizationCode` (for `apple.revokeWithCode(client, code)`). Otherwise:

```dart
await apple.revokeBeforeDelete(ref.read(apiClientProvider));
```

It opens the Apple sheet for a fresh `authorizationCode` and calls `POST /auth/social/apple/revoke {authorizationCode}` (signed in, `204`). Backing out throws `SocialCancelled`: do not delete then. Server errors come as `ApiRequestError`: `401 AUTH_SOCIAL.INVALID_AUTHORIZATION_CODE`, `404 AUTH_SOCIAL.PROVIDER_NOT_FOUND` (Apple off), `502 AUTH_SOCIAL.PROVIDER_GATEWAY_ERROR`. A revoke without a delete does no harm: the next Apple sign-in asks for consent again and arrives as the same `sub`.

## Setup summary

| Where | What (example values only) |
|---|---|
| Apple developer | App ID with the *Sign in with Apple* capability; a key (`.p8`) for the server; under *Sign in with Apple for Email Communication* register the sending mail domain (without it a hidden-email account cannot get the delete code) |
| Server | `skeleton.auth-social-apple.{client-id=com.example.app, team-id=ABCDE12345, key-id=ABC123DEFG, private-key}` |
| `ios/Runner/Runner.entitlements` | `com.apple.developer.applesignin` = `[Default]` |

Apple gives the name (`displayName` here) and the real email only on the first authorization of the app; the server uses the name only as the nickname of a new account.

Test: `cd packages/social_login_apple && flutter test` (the SDK platform is replaced by a fake; no device or account is used).
