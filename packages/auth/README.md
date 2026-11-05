# skeleton_auth

Email + password sign-in, token storage, silent refresh and session state for the kotlin-skeleton backend. Flutter + Riverpod 3 (hand-written providers, no generator). Web counterpart: react-skeleton `@skeleton/auth`.

Targets: `auth` (`/api/v1/auth/login` · `/me`) + `auth-session` (`/auth/refresh` · `/logout`), **body delivery** (the default): the refresh token comes in the response body. Contract: kotlin-skeleton `docs/modules/auth.md`, `docs/modules/auth-session.md`, `docs/account-http-contract.md`. Account flows (`account` module: sign-up, password reset, deletion) are below. Not here: social login, MFA.

## What the app gives, what it gets

The app overrides two providers in its `ProviderScope`:

```dart
ProviderScope(
  overrides: [
    authConfigProvider.overrideWithValue(const AuthConfig(apiBaseUrl: 'https://api.example.com/api/v1')),
    tokenStoreProvider.overrideWithValue(SecureTokenStore()),
  ],
  child: const App(),
)
```

| Export | Meaning |
|---|---|
| `TokenStore` · `SecureTokenStore` · `MemoryTokenStore` | Where the tokens live. `SecureTokenStore` = iOS Keychain / Android Keystore. Extension point: implement the interface. |
| `apiClientProvider` | The app's one `ApiClient`: sends `Authorization: Bearer`, renews on 401. Keep exactly one per app and use it for every authenticated call: the single-flight refresh lives in that client, a second client would refresh on its own and spend the rotated refresh token. |
| `authSessionProvider` | `AuthSession` notifier, state `AuthChecking` · `SignedOut` · `SignedIn(principal)`. `login(email:, password:)`, `logout()`. Starts by checking stored tokens with `GET /auth/me`. |
| `AuthApi` (`authApiProvider`) | `login` · `refresh` · `logout` · `me`. Stores nothing. |
| `authRedirect(ref)` · `authRefreshListenable(ref)` · `authRedirectFor(state, location)` | go_router wiring: checking → `/splash`, signed out → `/login`, signed in → off `/login` and `/splash` to `/me` (paths are parameters). |
| `LoginForm(labels: LoginLabels(...))` | Email/password form. Texts are parameters (default English). Shows `labels.invalidCredentials` for `AUTH.INVALID_CREDENTIALS`. |
| `createAuthClient(...)` | The wiring behind `apiClientProvider`. Call it once per app (for code that is not Riverpod): every extra client has its own single-flight and would spend the rotated refresh token. |
| `httpAdapterProvider` | Test seam: a fake Dio `HttpClientAdapter` (see `skeleton_api_client/testing.dart`). |

## Refresh rules

- A 401 on a normal call renews the access token **once**, saves the rotated pair, and repeats the call. Calls that fail together share one refresh; a call that failed with an older token than the stored one just repeats. (The refresh token rotates on every use and a reused one closes the session.)
- The session ends (store cleared, state `SignedOut`, the router goes to the login route) on a 401 with an `AUTH.*` code (`REFRESH_INVALID`, `REFRESH_REUSED`, ...), on `403 AUTH.ACCOUNT_SUSPENDED`, and after five 401s in a row without an `AUTH.*` code. `429 AUTH.TOO_MANY_REFRESHES` keeps the session and goes to the caller.
- No answer (network, timeout), 408, 429, 5xx during refresh: the response may have been lost after the server rotated the token, so the **same refresh token** is sent again (the backend's `reuse-grace`, starter 60 s, returns the same successor), after 2, 4, 8, 16, then every 30 s, for as long as the failure stays transient. A call that waits on this gets a network error after 45 s; the retrying goes on in the background.
- A sign-out or a new sign-in while a refresh is in flight wins: the late refresh result is not stored.
- On app start with an unreachable server the state is `SignedOut` but the tokens are kept for the next start.
- Tokens are never logged: no interceptor prints headers, `TokenPair` and the store `toString`s are redacted.

## Sign-up, password reset, account deletion

Targets the backend `account` module. Every widget takes its texts as a `*Labels` parameter (default English); none navigates, the app does in the callbacks.

```dart
// ProviderScope overrides, besides the two above:
signUpAttemptStoreProvider.overrideWithValue(SecureSignUpAttemptStore()),
// GoRouter: let signed-out users reach the account pages
redirect: authRedirect(ref, publicPaths: {'/sign-up', '/verify', '/forgot-password', '/reset-password'}),
```

| Export | Meaning |
|---|---|
| `AccountApi` (`accountApiProvider`) | `signUp` · `verifyEmail` (returns `AuthResult`) · `resendVerification` · `forgotPassword` · `resetPassword` · `passwordPolicy` · `me` (`hasPassword`, `email`, `displayName`, `displayTag`) · `updateDisplayName` · `requestDeleteConfirmation` · `deleteAccount({currentPassword?, confirmationCode?, socialReauth?})`. Stores nothing. |
| `SignUpForm(onSignedUp:, consentBuilder:, onConsentRejected:)` | Email + password. A 202 saves the attempt (`signUpId`, `expiresAt`, `resendAvailableAt`) in `signUpAttemptStoreProvider`. `consentBuilder` is the slot for consent checkboxes: it gets a `ConsentSlotController`; the slot calls `update(ready:, claims:)` and submit stays disabled until `ready`. The auth package does not know `legal`. |
| `SignUpForm(displayName: DisplayNameMode.none \| optional \| required)` | The nickname field. The server does not say whether it wants one (`required-on-sign-up`), so the app picks the mode that matches its server; the default is none (no field). The value is sent trimmed. A `400` `errors[].field` (`displayName`, `email`, `password`) is shown under that field (codes `Required` · `Size` · `Pattern` · `Reserved`; `message` is for logs and never shown); only what no field can show gets the common text. |
| `DisplayNameForm(onSaved:)` · `accountMeProvider` | Picks or changes the nickname (`PATCH /account/me`); for an account whose `AccountMe.displayName` is null (social sign-up, server generates none). `AccountMe.displayLabel` is `name#tag` when the server gives a `displayTag`. The app decides where to send a nickname-less account (see `apps/sample` `nickname_gate.dart`). |
| `authMethodsProvider` · `AuthMethods.loginId` | `GET /auth/methods`. A `loginId{minLength,maxLength}` key exists only on a server with login IDs on; then `SignUpForm` shows an ID field (length rules from the key, no app setting), `LoginForm` reads "ID or email" (an input without `@` is sent as `username`), and `VerifyCodeForm` handles `409 LOGIN_ID_TAKEN` like the nickname (same `signUpId` and code, a new `loginId`; the attempt is not used up). No key = nothing changes. A failed read is not remembered. |
| `LoginIdForm(onSaved:, onAlreadySet:)` · `LoginIdRequiredInterceptor(onRequired:)` | An account without a login ID (`AccountMe.loginIdRequired`: the `loginId` key is there and null) is refused with `403 ACCOUNT.LOGIN_ID_REQUIRED` on every call outside the ID endpoints. The interceptor only reports (nothing is signed out or sent again); the app shows `LoginIdForm` (`POST /account/login-id`, once, no change) and must offer a sign-out beside it. The form asks the server whether the ID is free while typing (`checkLoginId`, 400 ms after the last key, advice only: a 429 or a failure says "could not check"); `409 LOGIN_ID_TAKEN` shows under the field, `409 LOGIN_ID_ALREADY_SET` calls `onAlreadySet`. The ID candidate is never logged. See `apps/sample` `login_id_gate.dart`. |
| `EmailRegisterForm(onRegistered:, socialReauth:)` · `DiscardAccountButton` · `EmailRequiredInterceptor(onRequired:)` · `AccountMe.emailRequired` / `emailRequiredToWrite` | The first address of an account that has none. `emailRequired` in `me` = refused on every call outside the allow list (reads too, block right after sign-in); `emailRequiredToWrite` = reads pass, only a write answers `403 ACCOUNT.EMAIL_REQUIRED` (tell the person before a write screen opens). The interceptor only reports; the blocked call is NOT sent again, the person repeats it after the address is confirmed. The form sends `POST /account/email/change` then `/confirm`; an old session gets `403 ACCOUNT.REAUTH_REQUIRED` and `socialReauth` supplies a fresh provider proof. The code step carries the "no code? the address may already have an account" hint (the server answers the same for a taken address). `DiscardAccountButton` (`POST /account/discard`, after a confirmation, signs out locally) is the way out for someone who already has another account. See `apps/sample` `email_gate.dart`. |
| `DeletionPendingForm` · `pendingDeletionProvider` · `AuthSession.cancelDeletion` · `AccountApi.cancelDeletion` · `deletionPendingOf(error)` | A right password (or social proof) for an account in its deletion grace answers `403 AUTH.ACCOUNT_DELETION_PENDING` with `data.purgeAfter` and, only when the server runs `deletion.self-restore`, a single-use `data.restoreToken`. `AuthSession.login` (and the social controller) put it into `pendingDeletionProvider`; the app shows `DeletionPendingForm` while it holds one. "Cancel the deletion" is `POST /account/delete/cancel`, whose answer is a login (the session starts); `410 ACCOUNT.TOKEN_INVALID` = too late, sign in again. Without a token the form only says so. **The token lives in memory only** (not in a route, a store, a log or an error: `DeletionPending.toString` hides it) and a restart loses it. `LoginForm` shows no error for this case. See `apps/sample` `deletion_pending_gate.dart`. |
| `VerifyCodeForm(attempt:, onVerified:, onExpired:)` | 6-digit code. `409 DISPLAY_NAME_TAKEN` does not use up the attempt: a nickname field appears and the next submit repeats the same `signUpId` and code with it. A right code is the login (`AuthSession.signInWith`) and removes the attempt. `400 CODE_INVALID` shows `attemptsLeft`; `410 CODE_EXPIRED` removes the attempt and calls `onExpired`. `resendAvailableAt == null` hides the resend button; the countdown uses the device clock, the server decides. |
| `restoreSignUpAttempt(store)` | The attempt to continue after the app was killed; an expired one is removed and gives null. |
| `ForgotPasswordForm` | Always says "if an account exists...": the backend answers 202 either way. |
| `ResetPasswordForm(token:, onReset:)` | Token from `<link-base-url>/reset-password?token=`. The server ends every session, so on success this device signs out locally (`AuthSession.signOutLocally`). The token is never shown or logged. |
| `DeleteAccountForm(onDeleted:, socialReauth:)` | Proof by `GET /account/me`: password again; no password + address = mailed code (`POST /account/delete/confirmation`); no address = the app's `socialReauth` hook (`Future<Map<String, Object?>?> Function()`, null = backed out; `auth` never imports `social_login`). While `me` is unread or fails the password shows; one submit = one `Idempotency-Key`, a retry reuses it. `202` signs out locally; `409 DELETION_BLOCKED` shows `labels.blocked`. |
| `PasswordPolicyHint` · `PasswordPolicy.violations` | Hint from `GET /account/password/policy`. `maxBytes` is UTF-8 **bytes** (a non-ASCII character takes 2 to 4), `minLength` counts characters. The server stays the judge (common and breached passwords). |
| `signOutHooksProvider` | `SignOutHooks.add(hook)` registers work to do just before `logout()` (for example `push` deleting this device), while the tokens still work. Hooks run together with a time limit (3 s); a failing or slow hook never blocks the sign-out. |

Reset links: the mail opens a web address. To open the app instead, the project adds App Links / Universal Links for its own domain (`assetlinks.json`, AASA) and a route with the same path; that is the project's part.

## Tests

```bash
cd packages/auth && flutter test            # unit + widget (fake backend); backend tests skip themselves
```

**Backend contract test** (`test/backend/`, tag `backend`): login → me → silent refresh → logout and the rotated-token case against a real `apps/api`. It runs only when `API_BASE_URL` is set:

```bash
# kotlin-skeleton: PostgreSQL up (docker compose up -d postgres), then the starter with a seed account
SKELETON_AUTHSESSION_REUSEGRACE=0s \
SKELETON_ACCOUNT_SEED_ACCOUNTS_0_ID=acc_user \
SKELETON_ACCOUNT_SEED_ACCOUNTS_0_EMAIL=user@example.com \
SKELETON_ACCOUNT_SEED_ACCOUNTS_0_PASSWORD=password \
./gradlew :apps:api:bootRun --args='--spring.profiles.active=local'

# here
API_BASE_URL=http://localhost:8080/api/v1 API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
  flutter test --tags backend test/backend
```

The starter has no seed account (`skeleton.account.seed.accounts` is empty), and its `reuse-grace: 60s` would hand a spent refresh token the same successor; the "already rotated" test needs `0s`.
