# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `skeleton_api_client`: Dio client with the `value` / `values` / `pagination` envelopes, `ApiRequestError` (status, code, message, trace id, field errors), `ErrorCodes` for the codes the skeleton uses, header providers and an error hook.
- Repository skeleton: Pub Workspaces root, Melos scripts (`analyze`, `format`, `test`), `skeleton_lints`, CI (format, analyze, test).
