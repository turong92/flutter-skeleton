# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Stage 3 (sign-up, legal, board, push, sample app): `skeleton_auth` sign-up, email verification, password reset and account deletion; `skeleton_legal` (sign-up consents, document page, `403 LEGAL.RECONSENT_REQUIRED` re-consent); `skeleton_board` (posts, nested comments, reactions); `skeleton_push` (FCM registration, settings, removal on sign-out); `apps/sample` wiring them; the starter gets the account and consent screens. Catalog entries `legal`, `board`, `push` and `app-sample` (`stampFlag.included: never`); a stamp always removes `apps/sample` and keeps `board` / `push` only with `--packages board,push`.
- `skeleton_iap` (`--packages iap`): in-app purchase checked by kotlin's `payment-iap`; catalog entry `iap`. `apps/sample` gets a Store tab (products, buy, restore, web checkout when the server's channel has the web, my subscription) and a "cancel it in the store" notice before account deletion. The Toss WebView attempt is kept on a local branch.
- `scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]` (string work in `tool/new_project/stamp.dart`) and `scripts/test-new-project.sh`; a path-filtered `new-project` workflow runs the test only when the stamper or what it rewrites changed.
- Capability catalog: `capabilities.json` + schema, generated `docs/capabilities.md` and `llms.txt`, and `dart tool/build_capabilities.dart --check` (CI) that ties entries to the real packages, `needs` to the pubspecs and, when kotlin-skeleton / react-skeleton are cloned next to this repo, backend module names and react twin ids to theirs. `tool/` is a workspace package with its own tests.
- `skeleton_api_client`: Dio client with the `value` / `values` / `pagination` envelopes, `ApiRequestError` (status, code, message, trace id, field errors), `ErrorCodes` for the codes the skeleton uses, header providers and an error hook.
- `skeleton_auth`: token stores (secure, memory), `AuthApi`, an interceptor that renews the access token on 401 with a single in-flight refresh, `AuthSession` (Riverpod notifier: checking, signed out, signed in), go_router redirect helpers, `LoginForm`. Backend contract test (tag `backend`) against a real kotlin-skeleton `apps/api`.
- `skeleton_ui`: design tokens as Dart constants, light and dark Material 3 themes, `LoadingView` and `ErrorView`.
- `apps/starter`: sign in, see `GET /auth/me`, sign out; stored-token restore on start; `--dart-define-from-file` settings; cleartext http only in debug builds (Android `src/debug` network security config, iOS Debug-only `Info-Debug.plist`); `INTERNET` declared in the main Android manifest. CI builds a debug APK (not yet run).
- Repository skeleton: Pub Workspaces root, Melos scripts (`analyze`, `format`, `test`), `skeleton_lints`, CI (format, analyze, test).
