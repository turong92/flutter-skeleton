# skeleton_social_login

Sign in with a social provider's app SDK token. The app asks the provider's SDK for a token; the kotlin-skeleton `auth-social` backend checks it with the provider and answers with its own session. The target contract is `POST /auth/social/{provider}/token`, `GET /auth/methods` (`social[].nativeToken`) and the token fields of the account calls, all in `docs/account-http-contract.md` of kotlin-skeleton (modules `auth-social` + a provider module, `account`, `auth-session` with `delivery=body`).

This is the core. The SDK of each provider is a separate package (`social_login_google`, `_apple`, `_kakao`, `_naver`) that implements `SocialProvider`; a project takes only the SDKs it uses.

| Piece | What it is |
|---|---|
| `SocialProvider` | `id` (the server's provider id) · `obtain(nonce)` → `SocialCredential` · `signOut()` |
| `SocialCredential` | One token: `.idToken(...)` (Google, Apple) or `.accessToken(...)` (Kakao, Naver), the raw `nonce`, an optional `displayName`. `toString` prints no value |
| `SocialCancelled` | Thrown by a provider when the person backs out. Not an error: the controller goes back to idle |
| `generateSocialNonce()` | 32 bytes from `Random.secure`, unpadded base64url (43 characters) |
| `SocialAuthApi` | `login` · `link` · `SocialAuthApi.socialReauth(...)` (the JSON object) · `nativeTokenProviders()` |
| `socialLoginControllerProvider` | `signIn(provider)`: token → server → `AuthSession.signInWith`. State `SocialLoginIdle / Busy / Failed` |
| `availableSocialProvidersProvider` | The app's providers minus those the server did not list with a `nativeToken` |
| `SocialFailure` | The groups of a failed sign-in, for choosing text (below) |

## Wiring

```dart
ProviderScope(overrides: [
  // the SDK packages this app uses
  socialProvidersProvider.overrideWithValue([GoogleSocialProvider(...), KakaoSocialProvider()]),
])

// once, where the app wires sign-out
ref.read(signOutHooksProvider).add(ref.read(socialSignOutHookProvider));

// the login screen
final providers = ref.watch(availableSocialProvidersProvider).value ?? const [];
final state = ref.watch(socialLoginControllerProvider);
// a button per provider (shape and logo are the app's), disabled while state is SocialLoginBusy:
//   onPressed: () => ref.read(socialLoginControllerProvider.notifier).signIn(provider)
// on SocialLoginFailed, pick the text from state.failure.
```

The session is opened only after the server has accepted the token: nothing is stored and `AuthSession` stays signed out until `/token` answers `200`. The server also needs `auth-session` with the refresh token in the body, like the password login.

## Failures

| `SocialFailure` | Server answer | Suggested text |
|---|---|---|
| `emailConflict` | `409 ACCOUNT.SOCIAL_EMAIL_CONFLICT` | "An account with that email exists. Sign in with it, then link this provider in settings." |
| `notLinked` | `409 AUTH_SOCIAL.ACCOUNT_LINK_NOT_FOUND` (sign-up is closed) | "No account with this sign-in yet." |
| `tokenRejected` | `401 AUTH.SOCIAL_ID_TOKEN_INVALID` / `AUTH.SOCIAL_ACCESS_TOKEN_INVALID` | "Could not sign in. Try again." |
| `providerNotAvailable` | `404 AUTH_SOCIAL.PROVIDER_NOT_FOUND` | hide the button |
| `providerDown` | `502 AUTH_SOCIAL.PROVIDER_GATEWAY_ERROR` | "Try again later." |
| `blocked` | `403 AUTH.ACCOUNT_SUSPENDED` / `ACCOUNT.REGISTRATION_BLOCKED` | |
| `deletionPending` | `403 AUTH.ACCOUNT_DELETION_PENDING` | the account is waiting for deletion. The controller also puts the offer to cancel it into the auth package's `pendingDeletionProvider` (the failure carries no error, so no restore token); show `DeletionPendingForm` while that holds one |
| `mfaRequired` | `403 AUTH.MFA_REQUIRED` | the second step of the app (not in this skeleton) |
| `network` | no answer | |
| `sdk` | the provider's SDK threw (also reported with `FlutterError.reportError`) | |
| `other` | anything else; `SocialLoginFailed.error` has code, status and trace id | |

## Linking and re-authentication

Linking a provider in settings and the `socialReauth` of an account without an email use the same tokens:

```dart
final provider = ...; // a SocialProvider
final credential = await provider.obtain(generateSocialNonce()); // may throw SocialCancelled
await ref.read(socialAuthApiProvider).link(provider.id, credential, proof: {'currentPassword': '...'});
// the object for deleteAccount / unlink / email change:
final reauth = SocialAuthApi.socialReauth(provider.id, credential);
```

A token is single-purpose and short-lived: get a new one for each call. A rejected `socialReauth` token is `400 ACCOUNT.REAUTH_FAILED` (not a 401).

## Tokens in logs

`SocialCredential.toString` and the controller state print no token, and a token is never put in a path or a query. Do not log request bodies of `/auth/social/...` and `/account/...`.

## Tests

```
cd packages/social_login && flutter test
```

Real provider SDKs, consoles and devices are not exercised here; the tests use a fake `SocialProvider` and a scripted backend (`FakeAdapter`).
