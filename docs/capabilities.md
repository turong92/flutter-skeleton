<!-- Generated from capabilities.json by tool/build_capabilities.dart. Do not edit by hand. -->

# Capabilities — flutter-skeleton

Flutter mobile skeleton (Pub Workspaces + Melos): encapsulated packages and a starter app a new project picks from. The backend is the sibling kotlin-skeleton, the web twin is react-skeleton.

The source is `capabilities.json` (schema `docs/capabilities.schema.json`); this file and `llms.txt` are made from it.

## Entries

| id | What it gives | How to take it | Backend modules | Pairs with (react) |
|---|---|---|---|---|
| `lints` | Shared lint rules (flutter_lints plus avoid_print and unawaited_futures) every package and app includes. | in every project | — | — |
| `api-client` | One Dio-based REST client for the backend: envelope unwrapping (value, values, pagination), the standard ApiRequestError with its codes, header providers and an error hook. Pure Dart. | in every project | platform | `api-client` |
| `auth` | Email and password sign-in, secure token storage, silent refresh on 401 with a single in-flight refresh, session state (Riverpod), go_router redirect helpers and a login form. | in every project | auth, auth-session | `auth` |
| `ui` | Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses. | in every project | — | `ui`, `theme`, `tokens` |
| `app-starter` | The starter app: sign in, see who you are (GET /auth/me), sign out, restore the session on start. It becomes the new project's app. | in every project | auth, auth-session, platform | `app-starter` |

### `lints` — Shared lint rules (flutter_lints plus avoid_print and unawaited_futures) every package and app includes.

- Where: `skeleton_lints` (`packages/lints`) · package
- How to take it: in every project
- Needs: —
- Backend: none (Flutter only)
- Web twin (react-skeleton): —
- Not for: Project-specific rules: add them in the app's own analysis_options.yaml
- Keywords: 린트, 정적 분석, 코드 규칙 / lints, analysis options, static analysis

### `api-client` — One Dio-based REST client for the backend: envelope unwrapping (value, values, pagination), the standard ApiRequestError with its codes, header providers and an error hook. Pure Dart.

- Where: `skeleton_api_client` (`packages/api_client`) · package
- How to take it: in every project
- Needs: —
- Backend: modules `platform` · paths `/api/v1`
- Backend docs (kotlin-skeleton): `docs/modules/platform.md` · `docs/errors.md`
- Docs: `packages/api_client/README.md`
- Web twin (react-skeleton): `api-client`
- Not for: Authentication: tokens and refresh live in auth / Streams (SSE, WebSocket): not here
- Keywords: API 호출, 백엔드 연결, 에러 처리, 에러 코드, 응답 형식 / api client, rest, http client, dio, error codes, envelope

### `auth` — Email and password sign-in, secure token storage, silent refresh on 401 with a single in-flight refresh, session state (Riverpod), go_router redirect helpers and a login form.

- Where: `skeleton_auth` (`packages/auth`) · package
- How to take it: in every project
- Needs: `api-client`
- Backend: modules `auth` · `auth-session` · paths `/api/v1/auth`
- Backend docs (kotlin-skeleton): `docs/modules/auth.md` · `docs/modules/auth-session.md` · `docs/account-http-contract.md`
- Docs: `packages/auth/README.md`
- Web twin (react-skeleton): `auth`
- Not for: Sign-up, password reset, social login, MFA: not built yet / How the login screen looks: the app owns it (texts are parameters)
- Keywords: 로그인, 로그아웃, 인증, 토큰, 토큰 갱신, 세션, 리프레시 토큰, 로그인 상태 / login, logout, auth, token, session, refresh token, sign in, secure storage

### `ui` — Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses.

- Where: `skeleton_ui` (`packages/ui`) · package
- How to take it: in every project
- Needs: —
- Backend: none (Flutter only)
- Docs: `packages/ui/README.md`
- Web twin (react-skeleton): `ui` · `theme` · `tokens`
- Not for: A component library: Material widgets are used as they are / A stored theme switch: the theme follows the system
- Keywords: 테마, 다크 모드, 디자인 토큰, 색, 로딩, 에러 화면 / theme, dark mode, design tokens, colors, loading view, error view

### `app-starter` — The starter app: sign in, see who you are (GET /auth/me), sign out, restore the session on start. It becomes the new project's app.

- Where: `starter` (`apps/starter`) · app
- How to take it: in every project
- Needs: `api-client` · `auth` · `ui`
- Backend: modules `auth` · `auth-session` · `platform` · paths `/api/v1/auth`
- Backend docs (kotlin-skeleton): `docs/account-http-contract.md`
- Docs: `apps/starter/README.md`
- Web twin (react-skeleton): `app-starter`
- Not for: Anything beyond sign-in: delete what you do not use, the starter is the minimum
- Keywords: 스타터, 시작 템플릿, 새 앱, 모바일 시작 / starter, boilerplate, new app, mobile start

