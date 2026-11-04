<!-- Generated from capabilities.json by tool/build_capabilities.dart. Do not edit by hand. -->

# Capabilities — flutter-skeleton

Flutter mobile skeleton (Pub Workspaces + Melos): encapsulated packages and a starter app a new project picks from. The backend is the sibling kotlin-skeleton, the web twin is react-skeleton.

The source is `capabilities.json` (schema `docs/capabilities.schema.json`); this file and `llms.txt` are made from it.

## new-project.sh

- `scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]`

`--packages` takes ids from the table; what a package needs comes along. The backend side is built with kotlin-skeleton `new-project.sh --modules` from the modules in the Backend column.

## Entries

| id | What it gives | How to take it | Backend modules | Pairs with (react) |
|---|---|---|---|---|
| `lints` | Shared lint rules (flutter_lints plus avoid_print and unawaited_futures) every package and app includes. | in every project | — | — |
| `api-client` | One Dio-based REST client for the backend: envelope unwrapping (value, values, pagination), the standard ApiRequestError with its codes, header providers and an error hook. Pure Dart. | in every project | platform | `api-client` |
| `auth` | Email and password sign-in, account lifecycle (sign-up, email verification, password reset, account deletion), secure token storage, silent refresh on 401 with a single in-flight refresh, session state (Riverpod), go_router redirect helpers and the forms. | in every project | auth, auth-session, account | `auth`, `account-lifecycle`, `session-refresh` |
| `legal` | Legal documents and consents: the sign-up consent boxes, a document page, the re-consent screen and the 403 LEGAL.RECONSENT_REQUIRED handling (go_router redirect to /consent). | in every project | legal, legal-jdbc | `legal`, `legal-documents` |
| `board` | Board posts, nested comments and reactions: list with paging, detail, editor, idempotent submits, delete and edit only for your own. | `--packages board` | board, board-jdbc | `board` |
| `push` | Push notifications through FCM: device registration, permission prompt, per-kind settings, a test notification, tapped-link handling and removing the device on sign-out. The app initializes Firebase. | `--packages push` | notification-push, notification-push-jdbc, notification-fcm | `push` |
| `ui` | Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses. | in every project | — | `ui`, `theme`, `tokens` |
| `app-starter` | The starter app: sign up with consents, verify email, sign in, reset the password, see who you are (GET /auth/me), delete the account, sign out, agree again when a document changes, restore the session on start. It becomes the new project's app. | in every project | auth, auth-session, account, legal, platform | `app-starter` |
| `app-sample` | The reference app: the starter's flows plus a board tab, push settings and a settings tab, wired the way a project would. Read it for wiring; a stamp removes it. | never stamped (reference app) | auth, auth-session, account, legal, board, notification-push, notification-fcm, platform | `app-sample` |

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

### `auth` — Email and password sign-in, account lifecycle (sign-up, email verification, password reset, account deletion), secure token storage, silent refresh on 401 with a single in-flight refresh, session state (Riverpod), go_router redirect helpers and the forms.

- Where: `skeleton_auth` (`packages/auth`) · package
- How to take it: in every project
- Needs: `api-client`
- Backend: modules `auth` · `auth-session` · `account` · more when present `account-jdbc` · `auth-session-jdbc` · paths `/api/v1/auth` · `/api/v1/account`
- Backend docs (kotlin-skeleton): `docs/modules/auth.md` · `docs/modules/auth-session.md` · `docs/modules/account.md` · `docs/account-http-contract.md`
- Docs: `packages/auth/README.md`
- Web twin (react-skeleton): `auth` · `account-lifecycle` · `session-refresh`
- Not for: Social login, magic link, MFA: not built yet / How the screens look: the app owns them (texts are parameters)
- Keywords: 로그인, 로그아웃, 인증, 토큰, 토큰 갱신, 세션, 리프레시 토큰, 로그인 상태, 가입, 회원가입, 비밀번호 재설정, 탈퇴, 이메일 인증 / login, logout, auth, token, session, refresh token, sign in, secure storage, sign up, password reset, account deletion, email verification

### `legal` — Legal documents and consents: the sign-up consent boxes, a document page, the re-consent screen and the 403 LEGAL.RECONSENT_REQUIRED handling (go_router redirect to /consent).

- Where: `skeleton_legal` (`packages/legal`) · package
- How to take it: in every project
- Needs: `api-client` · `auth`
- Backend: modules `legal` · `legal-jdbc` · paths `/api/v1/legal`
- Backend docs (kotlin-skeleton): `docs/modules/legal.md` · `docs/modules/legal-jdbc.md` · `docs/legal.md` · `docs/legal-http-contract.md`
- Docs: `packages/legal/README.md`
- Web twin (react-skeleton): `legal` · `legal-documents`
- Not for: A markdown renderer: documents show as plain selectable text / Cookie banners: not an app concern
- Keywords: 약관, 동의, 재동의, 개인정보 처리방침, 법적 문서 / terms, consent, reconsent, privacy policy, legal documents

### `board` — Board posts, nested comments and reactions: list with paging, detail, editor, idempotent submits, delete and edit only for your own.

- Where: `skeleton_board` (`packages/board`) · package
- How to take it: `--packages board`
- Needs: `api-client`
- Backend: modules `board` · `board-jdbc` · more when present `author-profile` · `idempotency` · paths `/api/v1/boards`
- Backend docs (kotlin-skeleton): `docs/modules/board.md` · `docs/modules/board-jdbc.md` · `docs/board-http-contract.md`
- Docs: `packages/board/README.md`
- Web twin (react-skeleton): `board`
- Not for: Guest posts, attachments, moderation, search, drafts / Choosing an author profile: the app gives a resolver
- Keywords: 게시판, 글, 댓글, 대댓글, 반응, 좋아요 / board, posts, comments, replies, reactions, likes

### `push` — Push notifications through FCM: device registration, permission prompt, per-kind settings, a test notification, tapped-link handling and removing the device on sign-out. The app initializes Firebase.

- Where: `skeleton_push` (`packages/push`) · package
- How to take it: `--packages push`
- Needs: `api-client`
- Backend: modules `notification-push` · `notification-push-jdbc` · `notification-fcm` · more when present `notification-push-legal` · paths `/api/v1/push`
- Backend docs (kotlin-skeleton): `docs/modules/notification-push.md` · `docs/modules/notification-push-jdbc.md` · `docs/modules/notification-fcm.md` · `docs/push-http-contract.md`
- Docs: `packages/push/README.md`
- Web twin (react-skeleton): `push`
- Not for: Creating the Firebase project or its config files: the project owns them (google-services.json and GoogleService-Info.plist stay out of git) / Topic or broadcast messages
- Keywords: 푸시, 알림, FCM, 기기 등록, 알림 권한 / push, notifications, fcm, device token, notification permission

### `ui` — Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses.

- Where: `skeleton_ui` (`packages/ui`) · package
- How to take it: in every project
- Needs: —
- Backend: none (Flutter only)
- Docs: `packages/ui/README.md`
- Web twin (react-skeleton): `ui` · `theme` · `tokens`
- Not for: A component library: Material widgets are used as they are / A stored theme switch: the theme follows the system
- Keywords: 테마, 다크 모드, 디자인 토큰, 색, 로딩, 에러 화면 / theme, dark mode, design tokens, colors, loading view, error view

### `app-starter` — The starter app: sign up with consents, verify email, sign in, reset the password, see who you are (GET /auth/me), delete the account, sign out, agree again when a document changes, restore the session on start. It becomes the new project's app.

- Where: `starter` (`apps/starter`) · app
- How to take it: in every project
- Needs: `api-client` · `auth` · `legal` · `ui`
- Backend: modules `auth` · `auth-session` · `account` · `legal` · `platform` · paths `/api/v1/auth` · `/api/v1/account` · `/api/v1/legal`
- Backend docs (kotlin-skeleton): `docs/account-http-contract.md` · `docs/legal-http-contract.md`
- Docs: `apps/starter/README.md`
- Web twin (react-skeleton): `app-starter`
- Not for: Anything beyond sign-in: delete what you do not use, the starter is the minimum
- Keywords: 스타터, 시작 템플릿, 새 앱, 모바일 시작 / starter, boilerplate, new app, mobile start

### `app-sample` — The reference app: the starter's flows plus a board tab, push settings and a settings tab, wired the way a project would. Read it for wiring; a stamp removes it.

- Where: `sample` (`apps/sample`) · app
- How to take it: never stamped (reference app)
- Needs: `api-client` · `auth` · `board` · `legal` · `push` · `ui`
- Backend: modules `auth` · `auth-session` · `account` · `legal` · `board` · `notification-push` · `notification-fcm` · `platform` · more when present `author-profile` · `idempotency` · paths `/api/v1/auth` · `/api/v1/account` · `/api/v1/legal` · `/api/v1/boards` · `/api/v1/push`
- Backend docs (kotlin-skeleton): `docs/sample.md`
- Docs: `apps/sample/README.md`
- Web twin (react-skeleton): `app-sample`
- Not for: A base to build on: start from the starter and copy what you need from here
- Keywords: 샘플 앱, 참조 앱, 연결 예시 / sample app, reference app, wiring example

