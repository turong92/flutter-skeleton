# flutter-skeleton

Flutter 모바일 앱 스켈레톤 — **Pub Workspaces + Melos**. kotlin-skeleton 백엔드, react-skeleton 웹과 같은 기조로, 캡슐화된 패키지를 모아 두고 프로젝트가 필요한 것만 골라 쓴다. 스켈레톤 자체가 돌아가고 시험되는 레포다(생성기 스크립트가 아니다).

> 상태: **1단계(최소 버전)**. 스타터 앱에서 이메일 · 비밀번호로 로그인하고, `GET /api/v1/auth/me` 로 내 정보를 보고, 로그아웃한다. 액세스 토큰이 만료되면 리프레시 토큰으로 조용히 갱신하고, 갱신에 실패하면 로그인 화면으로 돌아간다. 기능 카탈로그는 `capabilities.json`(`docs/capabilities.md` · `llms.txt` 가 거기서 만들어진다). 새 프로젝트는 `scripts/new-project.sh` 로 골라 찍는다(아래).

## 구조

```
apps/starter/        # 새 프로젝트가 가져가는 앱 (android/ · ios/ 포함)
packages/
├── lints/           # skeleton_lints — flutter_lints + 몇 규칙
├── api_client/      # skeleton_api_client — Dio · envelope 벗기기 · 표준 에러 (순수 Dart)
├── auth/            # skeleton_auth — 토큰 저장소 · 로그인 · 401 갱신 · AuthSession · LoginForm
└── ui/              # skeleton_ui — 토큰 · 라이트/다크 ThemeData · 로딩/에러 부품
```

패키지 id 는 react-skeleton 과 같게(`auth`, `api-client`, `ui`), Dart 이름은 `skeleton_<id>` 다(`auth` · `ui` 가 pub.dev 이름과 겹쳐서 접두사를 붙인다).

## 도구

- Flutter 3.47.9 (루트 `pubspec.yaml` 의 `environment.flutter` 가 버전의 유일한 자리다. CI 도 여기서 읽는다)
- Melos: `dart pub global activate melos`

## 명령

```bash
flutter pub get                                    # 워크스페이스 전체 의존 해석
melos run analyze                                  # 모든 패키지 flutter analyze --fatal-infos
melos run test                                     # test/ 가 있는 모든 패키지
dart format --output=none --set-exit-if-changed .  # CI 가 보는 포맷 검사
```

작업 중에는 바뀐 패키지 폴더에서만 돌린다: `cd packages/api_client && dart test` · `cd packages/auth && flutter test`.

## 새 프로젝트

```bash
scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]
```

레포를 복사해 `apps/starter` 를 `apps/<name>` 으로 바꾸고(pubspec 이름 · Android namespace/applicationId/MainActivity 폴더 · iOS 번들 id · 표시 이름), 스타터가 쓰는 패키지 + `--packages` 만 남긴다. `--prefix acme` 는 `skeleton_` 를 `acme_` 로 바꾼다. 바꿀 문자열을 못 찾으면 멈춘다. `scripts/test-new-project.sh` 가 기본 찍기와 `--packages` 찍기를 해 보고 찍힌 곳에서 pub get · analyze · test 를 돌린다(CI 에서는 관련 파일이 바뀔 때만).

## 설정

앱 설정은 `--dart-define-from-file=env/<env>.json` 으로 넣는다(키는 `API_BASE_URL` 하나). `env/*.json` 은 gitignore 이고 `.example` 만 커밋한다.

## 백엔드

짝은 kotlin-skeleton `apps/api` 다. 요청 · 응답 계약은 그쪽 `docs/account-http-contract.md`, `docs/modules/auth.md`, `docs/modules/auth-session.md` 가 정본이다.
