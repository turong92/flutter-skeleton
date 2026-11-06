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
| `push` | Push notifications through FCM: device registration, permission prompt, per-kind settings, a test notification, tapped-link handling (with a fallback path for a push without a link), removing the device on sign-out, and the consent screen for promotional push (advertising and night delivery, withdrawal, two-year reconfirmation) in package:skeleton_push/advertising.dart. The app initializes Firebase. | `--packages push` | notification-push, notification-push-jdbc, notification-fcm | `push` |
| `notifications` | The notification inbox: the list with paging and pull to refresh, unread marks, folded rows, mark one and mark all as read, an unread badge for a tab, and one "read it again" call for a realtime event, a push in front or the app coming back. Everything is keyed by the signed-in account. The app builds the tab and the route. | `--packages notifications` | notification, notification-jdbc | `notifications` |
| `realtime` | Server-sent events for the notification stream: one connection over the app's own Dio (Bearer and token refresh apply), every event but the greeting handed to the app, reopened after a drop or a silent line with a capped back-off, and not tried again after a 404. Pure Dart, no screens; the app opens it only in front and signed in. | `--packages realtime` | notification, notification-sse | `realtime` |
| `iap` | In-app purchase through the App Store and Google Play: the server's product list as the store prices it, buy and restore with the server's account token, every purchase checked by the server before anything opens or finishes, left-over purchases at start, a web checkout address opened in the outside browser (only when the server's channel has the web), and the lookup that tells a person to cancel a store subscription before deleting the account. No screens. | `--packages iap` | payment, payment-iap | — |
| `storage` | Photo upload straight to the storage with a presigned address: presign, PUT with progress and cancel (no app token sent to the storage host), complete so the server checks the bytes; the app's own file rules (none by default), a photo field over image_picker and a widget that draws a stored picture from its address. | `--packages storage` | storage, storage-s3 | `storage` |
| `social-login` | Sign in with a social provider's app SDK token, core only: the provider interface, the nonce, the server call (POST /auth/social/{provider}/token), link and re-authentication tokens for settings, the controller that signs the session in only after the server accepted the token, and which providers to show (GET /auth/methods). The provider SDKs are the social-login-* packages. No screens. | `--packages social-login` | auth-social | `social-login` |
| `social-login-google` | Google sign-in for the social login core (google_sign_in 7): returns the ID token for the web client id the server checks. | `--packages social-login-google` | auth-social-google | — |
| `social-login-apple` | Sign in with Apple for the social login core (sign_in_with_apple 8, iOS app only): the ID token with a hashed nonce, the name from the first sign-in, and the token revoke the App Store asks for before an account is deleted. | `--packages social-login-apple` | auth-social-apple | — |
| `social-login-kakao` | Kakao sign-in for the social login core (kakao_flutter_sdk_user 2): through KakaoTalk when installed, else the Kakao account page; returns the access token. | `--packages social-login-kakao` | auth-social-kakao | — |
| `social-login-naver` | Naver sign-in for the social login core (flutter_naver_login 2.1): returns the access token the server checks with Naver's profile API. The Naver SDK puts its client secret in the app. | `--packages social-login-naver` | auth-social-naver | — |
| `ui` | Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses. | in every project | — | `ui`, `theme`, `tokens` |
| `app-starter` | The starter app: sign up with consents, verify email, sign in, reset the password, see who you are (GET /auth/me), delete the account, sign out, agree again when a document changes, restore the session on start. It becomes the new project's app; with storage: profile picture on the account screen; the default screens of board (with photos when storage is picked too), notifications (and the realtime stream), push, and iap come along only when those packages are picked. | in every project | auth, auth-session, account, legal, platform | `app-starter` |
| `app-sample` | The reference app: the starter's flows plus a board tab, a store tab (products, buy, restore, web checkout, my subscription, the cancel-in-the-store notice before account deletion), social sign-in buttons with linking in settings, a notifications tab (inbox with an unread badge, realtime while in front, a push in front or a tapped push reading the inbox again), notification settings (push and promotional push consent) and a settings tab, wired the way a project would. Read it for wiring; a stamp removes it. | never stamped (reference app) | auth, auth-session, account, legal, board, notification, notification-jdbc, notification-sse, notification-push, notification-push-legal, notification-fcm, payment, payment-iap, storage, storage-s3, platform, auth-social, auth-social-google, auth-social-apple, auth-social-kakao, auth-social-naver | `app-sample` |

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
- Not for: Magic link, MFA: not built yet / How the screens look: the app owns them (texts are parameters)
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
- Not for: Guest posts, moderation, search, drafts, photos on comments / Uploading photos: the editor and the detail only have places for them (attachmentField, attachmentBuilder); the app fills them with skeleton_storage / Choosing an author profile: the app gives a resolver
- Keywords: 게시판, 글, 댓글, 대댓글, 반응, 좋아요 / board, posts, comments, replies, reactions, likes

### `push` — Push notifications through FCM: device registration, permission prompt, per-kind settings, a test notification, tapped-link handling (with a fallback path for a push without a link), removing the device on sign-out, and the consent screen for promotional push (advertising and night delivery, withdrawal, two-year reconfirmation) in package:skeleton_push/advertising.dart. The app initializes Firebase.

- Where: `skeleton_push` (`packages/push`) · package
- How to take it: `--packages push`
- Needs: `api-client` · `legal`
- Backend: modules `notification-push` · `notification-push-jdbc` · `notification-fcm` · more when present `notification-push-legal` · paths `/api/v1/push`
- Backend docs (kotlin-skeleton): `docs/modules/notification-push.md` · `docs/modules/notification-push-jdbc.md` · `docs/modules/notification-fcm.md` · `docs/push-http-contract.md`
- Docs: `packages/push/README.md`
- Web twin (react-skeleton): `push`
- Not for: Creating the Firebase project or its config files: the project owns them (google-services.json and GoogleService-Info.plist stay out of git) / Topic or broadcast messages
- Keywords: 푸시, 알림, FCM, 기기 등록, 알림 권한 / push, notifications, fcm, device token, notification permission

### `notifications` — The notification inbox: the list with paging and pull to refresh, unread marks, folded rows, mark one and mark all as read, an unread badge for a tab, and one "read it again" call for a realtime event, a push in front or the app coming back. Everything is keyed by the signed-in account. The app builds the tab and the route.

- Where: `skeleton_notifications` (`packages/notifications`) · package
- How to take it: `--packages notifications`
- Needs: `api-client`
- Backend: modules `notification` · `notification-jdbc` · more when present `notification-sse` · `notification-push` · paths `/api/v1/notifications`
- Backend docs (kotlin-skeleton): `docs/modules/notification.md` · `docs/modules/notification-jdbc.md`
- Docs: `packages/notifications/README.md`
- Web twin (react-skeleton): `notifications`
- Not for: Sending notifications or announcements: the server's modules do that / The app icon badge number and system notifications in front: not built
- Keywords: 알림함, 알림 목록, 안 읽은 알림, 읽음 처리, 알림 배지 / notification inbox, notification list, unread badge, mark as read

### `realtime` — Server-sent events for the notification stream: one connection over the app's own Dio (Bearer and token refresh apply), every event but the greeting handed to the app, reopened after a drop or a silent line with a capped back-off, and not tried again after a 404. Pure Dart, no screens; the app opens it only in front and signed in.

- Where: `skeleton_realtime` (`packages/realtime`) · package
- How to take it: `--packages realtime`
- Needs: `api-client`
- Backend: modules `notification` · `notification-sse` · paths `/api/v1/notifications/sse`
- Backend docs (kotlin-skeleton): `docs/modules/notification-sse.md`
- Docs: `packages/realtime/README.md`
- Web twin (react-skeleton): `realtime`
- Not for: WebSocket (STOMP): only SSE is built / Delivery while the app is in the background: push does that
- Keywords: 실시간, SSE, 서버 푸시 연결, 알림 실시간 / realtime, server-sent events, sse, live notifications

### `iap` — In-app purchase through the App Store and Google Play: the server's product list as the store prices it, buy and restore with the server's account token, every purchase checked by the server before anything opens or finishes, left-over purchases at start, a web checkout address opened in the outside browser (only when the server's channel has the web), and the lookup that tells a person to cancel a store subscription before deleting the account. No screens.

- Where: `skeleton_iap` (`packages/iap`) · package
- How to take it: `--packages iap`
- Needs: `api-client`
- Backend: modules `payment` · `payment-iap` · one of `payment-appstore` | `payment-googleplay` · more when present `auth-web-handoff` · `payment-jdbc` · paths `/api/v1/payments/iap` · `/api/v1/payments/subscriptions`
- Backend docs (kotlin-skeleton): `docs/modules/payment-iap.md` · `docs/modules/payment-appstore.md` · `docs/modules/payment-googleplay.md` · `docs/modules/auth-web-handoff.md` · `docs/payment-http-contract.md`
- Docs: `packages/iap/README.md`
- Web twin (react-skeleton): —
- Not for: Creating products or store accounts: the project registers them in App Store Connect and Play Console / Card payment inside the app (WebView): the web checkout opens the outside browser / Refunds, family sharing, offer codes: not built
- Keywords: 인앱결제, 앱 결제, 구독, 구매 복원, 앱스토어, 구글 플레이, 스토어 구독 해지 / in-app purchase, iap, subscription, restore purchases, app store, google play, web checkout

### `storage` — Photo upload straight to the storage with a presigned address: presign, PUT with progress and cancel (no app token sent to the storage host), complete so the server checks the bytes; the app's own file rules (none by default), a photo field over image_picker and a widget that draws a stored picture from its address.

- Where: `skeleton_storage` (`packages/storage`) · package
- How to take it: `--packages storage`
- Needs: `api-client`
- Backend: modules `storage` · `storage-s3` · more when present `storage-image` · paths `/api/v1/storage`
- Backend docs (kotlin-skeleton): `docs/modules/storage.md` · `docs/modules/storage-s3.md` · `docs/modules/storage-image.md`
- Docs: `packages/storage/README.md`
- Web twin (react-skeleton): `storage`
- Not for: Large files and video: multipart upload is not built (a photo does not need it) / Camera capture, cropping, reordering photos / Guest uploads (the guest presign path)
- Keywords: 사진 올리기, 이미지 업로드, 첨부, 프리사인, 사진 고르기 / photo upload, image upload, attachment, presigned url, image picker

### `social-login` — Sign in with a social provider's app SDK token, core only: the provider interface, the nonce, the server call (POST /auth/social/{provider}/token), link and re-authentication tokens for settings, the controller that signs the session in only after the server accepted the token, and which providers to show (GET /auth/methods). The provider SDKs are the social-login-* packages. No screens.

- Where: `skeleton_social_login` (`packages/social_login`) · package
- How to take it: `--packages social-login`
- Needs: `api-client` · `auth`
- Backend: modules `auth-social` · one of `auth-social-google` | `auth-social-apple` | `auth-social-kakao` | `auth-social-naver` · paths `/api/v1/auth/social` · `/api/v1/account/identities/social`
- Backend docs (kotlin-skeleton): `docs/modules/auth-social.md` · `docs/account-http-contract.md`
- Docs: `packages/social_login/README.md`
- Web twin (react-skeleton): `social-login`
- Not for: A provider's SDK: take the social-login-google, -apple, -kakao or -naver package / Browser (code flow) sign-in: that is the web twin / Button looks: the app draws them (each provider has a design guide)
- Keywords: 소셜 로그인, 간편 로그인, 계정 연결, 소셜 계정 연결, 소셜 탈퇴 / social login, social sign-in, oauth, id token, link account, app sdk token

### `social-login-google` — Google sign-in for the social login core (google_sign_in 7): returns the ID token for the web client id the server checks.

- Where: `skeleton_social_login_google` (`packages/social_login_google`) · package
- How to take it: `--packages social-login-google`
- Needs: `social-login`
- Backend: modules `auth-social-google` · paths `/api/v1/auth/social/google`
- Backend docs (kotlin-skeleton): `docs/modules/auth-social-google.md`
- Docs: `packages/social_login_google/README.md`
- Web twin (react-skeleton): —
- Not for: Registering the client ids and the package name with SHA-1 in the Google Cloud console: the project does it / Sending a nonce: google_sign_in 7 takes one only once per run
- Keywords: 구글 로그인 / google sign-in, google login

### `social-login-apple` — Sign in with Apple for the social login core (sign_in_with_apple 8, iOS app only): the ID token with a hashed nonce, the name from the first sign-in, and the token revoke the App Store asks for before an account is deleted.

- Where: `skeleton_social_login_apple` (`packages/social_login_apple`) · package
- How to take it: `--packages social-login-apple`
- Needs: `api-client` · `social-login`
- Backend: modules `auth-social-apple` · paths `/api/v1/auth/social/apple`
- Backend docs (kotlin-skeleton): `docs/modules/auth-social-apple.md`
- Docs: `packages/social_login_apple/README.md`
- Web twin (react-skeleton): —
- Not for: Android and web Apple sign-in: a later step (Services ID and callback) / The Sign in with Apple capability and the relay-mail domain: the project registers them with Apple
- Keywords: 애플 로그인, 애플로 로그인, 애플 탈퇴 철회 / sign in with apple, apple login, apple revoke

### `social-login-kakao` — Kakao sign-in for the social login core (kakao_flutter_sdk_user 2): through KakaoTalk when installed, else the Kakao account page; returns the access token.

- Where: `skeleton_social_login_kakao` (`packages/social_login_kakao`) · package
- How to take it: `--packages social-login-kakao`
- Needs: `social-login`
- Backend: modules `auth-social-kakao` · paths `/api/v1/auth/social/kakao`
- Backend docs (kotlin-skeleton): `docs/modules/auth-social-kakao.md`
- Docs: `packages/social_login_kakao/README.md`
- Web twin (react-skeleton): —
- Not for: KakaoSdk.init and the platform files (URL scheme, Android intent filter): the app does them, the README lists them / The Kakao logo: the repo ships none, see Kakao's design guide
- Keywords: 카카오 로그인, 카카오톡 로그인 / kakao login, kakaotalk login

### `social-login-naver` — Naver sign-in for the social login core (flutter_naver_login 2.1): returns the access token the server checks with Naver's profile API. The Naver SDK puts its client secret in the app.

- Where: `skeleton_social_login_naver` (`packages/social_login_naver`) · package
- How to take it: `--packages social-login-naver`
- Needs: `social-login`
- Backend: modules `auth-social-naver` · paths `/api/v1/auth/social/naver`
- Backend docs (kotlin-skeleton): `docs/modules/auth-social-naver.md`
- Docs: `packages/social_login_naver/README.md`
- Web twin (react-skeleton): —
- Not for: A check that the token was issued to this app: Naver offers none we found, the README says what that means / The platform files (meta-data, FlutterFragmentActivity, Nid keys, handleURL): the app does them / The Naver logo: the repo ships none, see Naver's design guide
- Keywords: 네이버 로그인 / naver login

### `ui` — Design tokens as Dart constants, light and dark Material 3 themes that follow the system, and the LoadingView and ErrorView the starter uses.

- Where: `skeleton_ui` (`packages/ui`) · package
- How to take it: in every project
- Needs: —
- Backend: none (Flutter only)
- Docs: `packages/ui/README.md`
- Web twin (react-skeleton): `ui` · `theme` · `tokens`
- Not for: A component library: Material widgets are used as they are / A stored theme switch: the theme follows the system
- Keywords: 테마, 다크 모드, 디자인 토큰, 색, 로딩, 에러 화면 / theme, dark mode, design tokens, colors, loading view, error view

### `app-starter` — The starter app: sign up with consents, verify email, sign in, reset the password, see who you are (GET /auth/me), delete the account, sign out, agree again when a document changes, restore the session on start. It becomes the new project's app; with storage: profile picture on the account screen; the default screens of board (with photos when storage is picked too), notifications (and the realtime stream), push, and iap come along only when those packages are picked.

- Where: `starter` (`apps/starter`) · app
- How to take it: in every project
- Needs: `api-client` · `auth` · `legal` · `ui`
- Backend: modules `auth` · `auth-session` · `account` · `legal` · `platform` · paths `/api/v1/auth` · `/api/v1/account` · `/api/v1/legal`
- Backend docs (kotlin-skeleton): `docs/account-http-contract.md` · `docs/legal-http-contract.md`
- Docs: `apps/starter/README.md`
- Web twin (react-skeleton): `app-starter`
- Not for: Anything beyond sign-in: delete what you do not use, the starter is the minimum
- Keywords: 스타터, 시작 템플릿, 새 앱, 모바일 시작 / starter, boilerplate, new app, mobile start

### `app-sample` — The reference app: the starter's flows plus a board tab, a store tab (products, buy, restore, web checkout, my subscription, the cancel-in-the-store notice before account deletion), social sign-in buttons with linking in settings, a notifications tab (inbox with an unread badge, realtime while in front, a push in front or a tapped push reading the inbox again), notification settings (push and promotional push consent) and a settings tab, wired the way a project would. Read it for wiring; a stamp removes it.

- Where: `sample` (`apps/sample`) · app
- How to take it: never stamped (reference app)
- Needs: `api-client` · `auth` · `board` · `iap` · `legal` · `notifications` · `push` · `realtime` · `social-login` · `social-login-apple` · `social-login-google` · `social-login-kakao` · `social-login-naver` · `storage` · `ui`
- Backend: modules `auth` · `auth-session` · `account` · `legal` · `board` · `notification` · `notification-jdbc` · `notification-sse` · `notification-push` · `notification-push-legal` · `notification-fcm` · `payment` · `payment-iap` · `storage` · `storage-s3` · `platform` · `auth-social` · `auth-social-google` · `auth-social-apple` · `auth-social-kakao` · `auth-social-naver` · one of `payment-appstore` | `payment-googleplay` · more when present `author-profile` · `idempotency` · `auth-web-handoff` · `storage-image` · paths `/api/v1/auth` · `/api/v1/account` · `/api/v1/legal` · `/api/v1/boards` · `/api/v1/push` · `/api/v1/notifications` · `/api/v1/payments/iap` · `/api/v1/payments/subscriptions` · `/api/v1/storage`
- Backend docs (kotlin-skeleton): `docs/sample.md`
- Docs: `apps/sample/README.md`
- Web twin (react-skeleton): `app-sample`
- Not for: A base to build on: start from the starter and copy what you need from here
- Keywords: 샘플 앱, 참조 앱, 연결 예시 / sample app, reference app, wiring example

