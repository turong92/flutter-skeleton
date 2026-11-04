# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `skeleton_api_client`: Dio client with the `value` / `values` / `pagination` envelopes, `ApiRequestError` (status, code, message, trace id, field errors), `ErrorCodes` for the codes the skeleton uses, header providers and an error hook.
- `skeleton_auth`: token stores (secure, memory), `AuthApi`, an interceptor that renews the access token on 401 with a single in-flight refresh, `AuthSession` (Riverpod notifier: checking, signed out, signed in), go_router redirect helpers, `LoginForm`. Backend contract test (tag `backend`) against a real kotlin-skeleton `apps/api`.
- `skeleton_ui`: design tokens as Dart constants, light and dark Material 3 themes, `LoadingView` and `ErrorView`.
- `apps/starter`: sign in, see `GET /auth/me`, sign out; stored-token restore on start; `--dart-define-from-file` settings; cleartext http only in debug builds (Android `src/debug` network security config, iOS Debug-only `Info-Debug.plist`); `INTERNET` declared in the main Android manifest. CI builds a debug APK (not yet run).
- Repository skeleton: Pub Workspaces root, Melos scripts (`analyze`, `format`, `test`), `skeleton_lints`, CI (format, analyze, test).
