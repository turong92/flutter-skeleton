# skeleton_auth

Email + password sign-in, token storage, silent refresh and session state for the kotlin-skeleton backend. Flutter + Riverpod 3 (hand-written providers, no generator). Web counterpart: react-skeleton `@skeleton/auth`.

Targets: `auth` (`/api/v1/auth/login` · `/me`) + `auth-session` (`/auth/refresh` · `/logout`), **body delivery** (the default): the refresh token comes in the response body. Contract: kotlin-skeleton `docs/modules/auth.md`, `docs/modules/auth-session.md`, `docs/account-http-contract.md`. Not here: sign-up, password reset, social login, MFA.

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
| `createAuthClient(...)` | The wiring behind `apiClientProvider`, for code that is not Riverpod. |
| `httpAdapterProvider` | Test seam: a fake Dio `HttpClientAdapter` (see `skeleton_api_client/testing.dart`). |

## Refresh rules

- A 401 on a normal call renews the access token **once**, saves the rotated pair, and repeats the call. Calls that fail together share one refresh; a call that failed with an older token than the stored one just repeats. (The refresh token rotates on every use and a reused one closes the session.)
- The session ends (store cleared, state `SignedOut`, the router goes to the login route) on a 401 with an `AUTH.*` code (`REFRESH_INVALID`, `REFRESH_REUSED`, ...), on `403 AUTH.ACCOUNT_SUSPENDED`, and after five 401s in a row without an `AUTH.*` code. `429 AUTH.TOO_MANY_REFRESHES` keeps the session and goes to the caller.
- No answer (network, timeout), 408, 429, 5xx during refresh: the response may have been lost after the server rotated the token, so the **same refresh token** is sent again (the backend's `reuse-grace`, starter 60 s, returns the same successor), after 2, 4, 8, 16, then every 30 s, for as long as the failure stays transient. A call that waits on this gets a network error after 45 s; the retrying goes on in the background.
- A sign-out or a new sign-in while a refresh is in flight wins: the late refresh result is not stored.
- On app start with an unreachable server the state is `SignedOut` but the tokens are kept for the next start.
- Tokens are never logged: no interceptor prints headers, `TokenPair` and the store `toString`s are redacted.

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
