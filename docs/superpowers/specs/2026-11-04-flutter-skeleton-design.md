# flutter-skeleton — 설계 초안

- 날짜: 2026-11-04 · 상태: 승인(정해야 할 것 1~3 은 맨 끝 「결정됨」) · 대상 레포: 새 공개 레포 `flutter-skeleton`(형제: `kotlin-skeleton` · `react-skeleton`)
- 형 지시 원문: "https://github.com/hongmono/create-flutter-monorepo 이거 참조해서 플러터 스켈레톤도 깔아보자. 우리 스켈레톤 기조 유지해서."

## 1. 목적과 범위

kotlin-skeleton API 와 짝을 이루는 Flutter 모바일 앱 스켈레톤을 만든다. 기조는 react-skeleton 과 같다.

- 캡슐화된 패키지를 모아 둔 워크스페이스다. 새 프로젝트는 `new-project.sh --packages a,b` 로 필요한 것만 골라 찍어 간다.
- 스켈레톤 자체가 돌아가고 시험되는 레포다(생성기 스크립트가 아니다).
- `capabilities.json` 이 정본 카탈로그다. 항목마다 짝 백엔드 모듈을 적는다.
- 기본값은 중립이다. 앱 설정(`env/*.json`, 앱 코드)에서 덮어쓴다.

**1단계(최소 버전)**: 스타터 앱에서 이메일·비밀번호로 로그인하고 → `GET /api/v1/auth/me` 로 내 정보를 보고 → 로그아웃한다. 액세스 토큰이 만료되면 리프레시 토큰으로 조용히 갱신하고, 갱신에 실패하면 로그인 화면으로 돌아간다. 백엔드는 kotlin-skeleton `apps/api`(스타터, 시드 사용자)를 그대로 쓴다.

**2단계(기조 완성)**: 카탈로그 + 생성기·가드, `new-project.sh`.

### 비목표(1·2단계에서 하지 않는 것)

- 가입·메일 확인·비밀번호 재설정 등 계정 수명주기 화면, 소셜 로그인, MFA
- 푸시(FCM), 실시간(SSE), 알림함, 업로드, 결제, 다국어
- 네이티브 flavor(환경별 번들 id·아이콘), iOS 빌드 CI, 스토어 배포
- 참조 앱(sample), 워크벤치, 위젯 카탈로그(Widgetbook 같은 것)
- 코드 생성(build_runner) — 필요해지는 패키지가 생길 때 들인다(§4)
- kotlin-skeleton · react-skeleton 레포 수정(카탈로그 교차 등록은 §7, 정해야 할 것 3)

### 다음에 넓힐 것(순서는 추천)

1. `account-lifecycle`(가입·확인·재설정·탈퇴 화면) — 백엔드 `account` 가 이미 다 연다
2. `push` — `notification-push` + `notification-fcm` 짝, `PUT /api/v1/push/devices/{installationId}`
3. `realtime` + `notifications` — `notification-sse` · `notification` 짝
4. `storage`(사진 업로드), `i18n`(gen-l10n), `social-login`(§10 확인 못 한 것 선결)
5. 네이티브 flavor, iOS 빌드 CI, kotlin·react 카탈로그에 flutter 짝 등록

## 2. 참조 레포에서 가져올 것과 버릴 것

참조: `create_flutter_monorepo.sh` 한 파일(1059줄, heredoc 으로 파일을 찍는 대화형 생성기) + README.

| 항목 | 판정 | 이유 |
|---|---|---|
| Pub Workspaces + Melos(설정은 루트 `pubspec.yaml` 의 `melos:`) | 가져옴 | 지금 Flutter 모노레포의 표준 조합. 의존 해석은 pub 이, 여러 패키지 명령은 melos 가 맡는다 |
| `apps/` · `packages/` 나눔 | 가져옴 | react-skeleton 과 같은 꼴 |
| 공용 린트 패키지(`flutter_lints` include) | 가져옴 | `flutter create` 기본 린트라 중립이다. 규칙은 최소로만 더한다(§4) |
| go_router · Riverpod · Dio | 가져옴 | §4 의 업계 관행과 같다 |
| 디자인 토큰을 Dart 상수로 두고 ThemeData 를 만드는 `design_system` | 가져옴 → `ui` 로 이름 바꿈 | react 의 `tokens`·`theme`·`ui` 경계와 짝을 맞춘다(§3) |
| DDD 층 패키지(`domain` · `data` · `presentation`) | 버림 | 층은 프로젝트가 골라 갈 수 있는 단위가 아니다. 우리는 기능(capability) 단위로 패키지를 나누고, 층은 패키지 안의 폴더로 둔다 |
| GetIt + Injectable(+ Riverpod 다리) | 버림 | DI 가 두 벌이 된다. Riverpod provider 가 DI 를 겸하는 것이 Riverpod 쪽 관행이다 |
| Retrofit | 버림 | 우리 응답은 envelope(`value`·`list`·`page`)를 벗겨야 해서 어차피 손으로 감싼다. 생성기가 하나 더 붙는 값이 없다 |
| slang | 버림 | 다국어의 국룰은 Flutter 공식 `gen-l10n`(ARB)이다. 다국어는 1단계 범위 밖이다 |
| `build.yaml` 로 `generated/` 폴더에 생성물 몰기 | 버림 | 기본 위치(`*.g.dart` 를 옆에 두기)가 관행이다. 1단계는 코드 생성 자체가 없다 |
| 대화형 생성 스크립트·업데이트 모드 | 버림 | 우리 기조는 「돌아가는 레포를 복사하고 골라 남기기」다. heredoc 안의 코드는 분석·시험이 안 된다 |
| 의존 버전 `any` + 생성할 때 `--tighten` | 버림 | 캐럿 제약(`^x.y.z`)과 커밋된 `pubspec.lock` 이 관행이다. 찍은 날마다 결과가 달라지지 않는다 |
| 여러 앱(client · admin) 묻기 | 버림 | 1단계는 스타터 하나. 관리자 앱이 필요해지면 그때 앱을 더한다 |

## 3. 레포 구조

```
flutter-skeleton/
├── pubspec.yaml            # workspace: 목록 + melos: 스크립트(analyze · format · test), pubspec.lock 커밋
├── analysis_options.yaml   # include: package:skeleton_lints/analysis_options.yaml
├── apps/starter/           # 새 프로젝트가 가져가는 앱 (android/ · ios/ 커밋)
│   ├── lib/main.dart       # ProviderScope + override(설정 · 토큰 저장소) + MaterialApp.router
│   ├── lib/config.dart     # String.fromEnvironment('API_BASE_URL') 등
│   ├── lib/router.dart     # /login · /me (+ 인증 redirect)
│   ├── lib/screens/        # me_screen.dart (로그인 화면은 auth 패키지 위젯을 감싼다)
│   ├── env/dev.json.example
│   └── test/               # 로그인 → 내 정보 → 로그아웃 위젯 시험(가짜 백엔드)
├── packages/
│   ├── lints/              # skeleton_lints
│   ├── api_client/         # skeleton_api_client (순수 Dart)
│   ├── auth/               # skeleton_auth (Flutter + Riverpod)
│   └── ui/                 # skeleton_ui (Flutter)
├── tool/                   # 2단계: build_capabilities.dart · new_project/(stamp 도우미)
├── scripts/                # 2단계: new-project.sh · test-new-project.sh
├── capabilities.json       # 2단계: 정본 카탈로그 · docs/capabilities.schema.json
├── docs/ · llms.txt        # 2단계: capabilities.md · llms.txt 는 생성물
├── CLAUDE.md · README.md · CHANGELOG.md
└── .github/workflows/ci.yml
```

### 패키지와 경계

| 패키지(id) | 짝 백엔드 | 하는 일 | 하지 않는 것 |
|---|---|---|---|
| `lints` | 없음 | `flutter_lints` + 몇 규칙 | 스타일 취향 규칙 |
| `api-client` | `platform` (`/api/v1`) | Dio 인스턴스 만들기, envelope 벗기기(`value<T>` · `list<T>` · `page<T>`), 표준 에러 `ApiRequestError`(status · code · message · traceId · fieldErrors), 백엔드 enum 에 있는 코드만 담은 `ErrorCodes`, 요청 훅 자리(헤더 공급자 · 에러 처리기) | 인증 지식, Flutter 의존, 화면 |
| `auth` | `auth` · `auth-session`(-jdbc) | `TokenStore`(인터페이스 + `flutter_secure_storage` 구현 + 메모리 구현), `AuthApi`(login · refresh · logout · me), 인증 인터셉터(Bearer 붙이기, 401 에서 리프레시를 한 번만 돌리고 재시도, 실패하면 로그아웃 상태), `AuthSession`(Riverpod Notifier: 확인 중 · 로그아웃 · 로그인(principal)), go_router redirect 도우미, `LoginForm` 위젯(문구는 매개변수, 기본 영어) | 가입·재설정 화면(다음), 소셜, 라우트 정의 자체(앱 몫) |
| `ui` | 없음 | 토큰(색 · 간격 · 모서리 · 글자 크기) Dart 상수, 라이트·다크 `ThemeData`, 스타터가 쓰는 만큼의 부품(로딩 · 에러 표시) | Material 부품을 다시 만들기, 테마 전환 저장(1단계는 시스템 설정 따라감) |

결정과 근거:

- **카탈로그 id 는 react 와 같게, Dart 패키지 이름은 `skeleton_<id 의 - 를 _ 로>`.** 형이 「X 가 필요하다」에서 셋(kotlin 모듈 · react 패키지 · flutter 패키지)을 같은 id 로 찾게 하려는 것이다. 접두사를 붙이는 이유는 `auth` · `ui` · `time` 이 pub.dev 이름과 겹치기 때문이다. 이것은 react 의 `@skeleton/` 스코프와 같은 역할이고, `--prefix acme` 로 바꾼다.
- **react 의 `tokens` · `theme` · `ui` 셋을 flutter 에서는 `ui` 하나로 묶는다.** react 가 나눈 이유는 CSS 생성물과 SSR 안전 때문이다. Flutter 는 `ThemeData` 하나가 그 셋을 다 맡는다. 카탈로그에서는 `ui` 항목의 `pairsWith` 로 react 의 셋을 가리킨다.
- **`api_client` 는 순수 Dart 로 둔다.** `dart test` 로 기기 없이 빠르게 시험하고, 백엔드 계약 시험(§8)도 기기 없이 돈다.
- **확장 지점(developer 는 이것만 만든다)**:
  - `TokenStore` 인터페이스 — 프로젝트마다 저장 위치가 다르다(보안 저장소, 시험용 메모리).
  - `ApiClient` 생성 인자(`baseUrl`, 헤더 공급자 목록, 에러 처리기) — 패키지가 늘어도(시간대 헤더, 멱등 키) 생성 인자만 늘어난다.
  - `AuthSession` 을 Riverpod provider override 로 주입하는 자리 — 앱이 설정·저장소를 넣는다.
  - `LoginForm` 문구 매개변수 — 문구는 react 와 같이 prop 으로 받고, 기본은 영어다.

## 4. 기술 선택(업계 관행 근거)

| 영역 | 선택 | 근거 |
|---|---|---|
| 모노레포 | Pub Workspaces(Dart 3.6+) + Melos 현행 메이저 | Melos 7 부터 pub workspace 위에서 돈다. Flutter 모노레포의 사실상 표준이다. **workspace 목록은 glob 을 안 받아** 경로를 하나씩 적는다(§6 에서 new-project 가 이 목록을 다시 쓴다) |
| 상태관리 | Riverpod 3(`flutter_riverpod`, 손으로 쓴 provider) | 새 Flutter 프로젝트에서 가장 많이 고르는 쪽이고 DI 를 겸한다. 참조 레포도 같다. `riverpod_generator` 는 쓰지 않는다 — provider 몇 개 때문에 build_runner 를 모든 앱에 강제하지 않는다(정해야 할 것 1) |
| 라우팅 | go_router | flutter.dev 가 관리하는 공식 패키지다. `redirect` + `refreshListenable` 이 인증 가드의 표준 꼴이다 |
| HTTP | Dio | 인터셉터 · `QueuedInterceptor`(리프레시 한 번만 돌리기)가 있어 토큰 갱신 구현의 관행이다. react 의 axios 와 같은 자리 |
| 토큰 저장 | flutter_secure_storage | iOS Keychain / Android Keystore. 모바일 토큰 저장의 국룰이다. 리프레시 토큰은 body 로 받는다 — 백엔드 `auth-session` 기본 전달이 body 라 맞는다 |
| 코드 생성 | 1단계 없음 | DTO 가 셋(토큰 쌍 · principal · 에러)뿐이라 `fromJson` 을 손으로 쓴다. 상태는 Dart 3 `sealed class` 로 충분하다. DTO 가 많은 패키지가 생기면 그때 `json_serializable`(필요하면 `freezed`)을 그 패키지에만 들이고, 생성물은 커밋하고 CI 에서 신선도를 검사한다(react 의 `tokens:check` 와 같은 방식) |
| 환경 | `--dart-define-from-file=env/<env>.json` | 키는 `API_BASE_URL` 하나다. 코드는 `String.fromEnvironment` 로 읽는다. 네이티브 flavor 없이 되는 Flutter 공식 방식이다. `env/*.json` 은 gitignore 하고 `.example` 만 커밋한다. flavor(환경별 번들 id)는 다음으로 미룬다 |
| 린트 | `flutter_lints` + `implementation_imports` · `depend_on_referenced_packages` 는 켜진 채로 + `avoid_print` · `unawaited_futures` | 앞의 둘이 react 의 「패키지 안쪽 금지 · 선언한 의존 = 실제 import」를 언어 도구로 막는다. 따로 시험을 만들지 않는다. 나머지는 실제 버그를 막는 것만 더한다 |
| 플랫폼 | android · ios | 모바일 스켈레톤이다. 웹은 react-skeleton 이 맡는다. 다른 플랫폼은 프로젝트가 `flutter create --platforms` 로 더한다 |
| SDK 고정 | 루트 `environment.flutter` 에 만들 때의 stable 을 적는다. CI 는 `subosito/flutter-action` 의 `flutter-version-file: pubspec.yaml` 을 쓴다 | 버전이 한 곳에 있다. FVM 은 강제하지 않는다(중립) |

**막아야 할 진짜 문제(1단계)**:

- 개발 HTTP 허용은 디버그에만 둔다. Android 는 `src/debug` 의 `network_security_config` 로 `localhost` · `10.0.2.2` 만 cleartext 를 허용한다. iOS 는 `NSAllowsLocalNetworking` 을 쓴다. 릴리스 빌드에는 들어가지 않는다.
- Android 에뮬레이터에서 호스트 백엔드 주소는 `10.0.2.2` 다. 이것은 `env/dev.json.example` 의 주석과 README 에만 적고 코드에서 분기하지 않는다.
- 토큰은 로그에 남기지 않는다. 인터셉터는 `Authorization` 을 찍지 않고, `TokenStore` 구현의 `toString` 에도 값이 나오지 않게 한다.
- 리프레시는 동시에 401 이 여러 개 와도 한 번만 돈다. `AUTH.REFRESH_REUSED` · `AUTH.REFRESH_INVALID` 가 오면 저장소를 비우고 로그아웃 상태로 간다.

## 5. 최소 버전 1단계 — 끝에서 끝까지

```
[starter] /login ── LoginForm ── AuthApi.login(POST /api/v1/auth/login)
        → TokenStore.save(access, refresh) → AuthSession = signedIn(principal)
        → go_router redirect → /me ── GET /api/v1/auth/me → 이메일 · 권한 표시
        → [로그아웃] POST /api/v1/auth/logout → TokenStore.clear → /login
앱 재시작: TokenStore 에 리프레시가 있으면 확인 중(스플래시) → me 성공이면 /me, 401 이면 refresh 한 번 → 실패하면 /login
```

- 백엔드는 kotlin-skeleton `apps/api` 를 로컬로 띄우고 시드 사용자로 로그인한다. 요청·응답 모양은 kotlin `docs/account-http-contract.md`, `docs/modules/auth.md` · `auth-session.md` 가 정본이다. 패키지 README 에는 「어느 모듈 수준 계약을 겨냥하는지」만 적는다(react 관례).
- 1단계 완료 판정:
  1. `melos run analyze` · `melos run test` 가 통과한다.
  2. 백엔드 계약 시험(§8)이 로컬 `apps/api` 를 상대로 통과한다.
  3. `flutter build apk --debug` 가 통과한다.
  4. 가능하면 에뮬레이터·시뮬레이터에서 눈으로 한 번 확인한다(qa).

## 6. new-project(골라 찍기) — 2단계

```
scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]
```

react `new-project.sh` 와 같은 순서로 한다. Dart 도우미 `tool/new_project/stamp.dart` 가 문자열 치환을 맡는다(node 의존 없음).

1. 레포를 `<target-dir>` 로 복사한다(`.dart_tool` · `build` · `.git` · `.claude` · `env/*.json` 제외).
2. `apps/starter` → `apps/<name>`. 바꾸는 것: pubspec `name`, Android `namespace` · `applicationId` · `MainActivity` 패키지 폴더, iOS `PRODUCT_BUNDLE_IDENTIFIER` · 표시 이름. 기본 org 는 `com.example`. **바꿀 문자열을 못 찾으면 조용히 넘기지 않고 멈춘다**(react `stamp.mjs` 와 같다).
3. 패키지 = 스타터가 쓰는 것 + `--packages` 를 pubspec 의존으로 닫은 것. 나머지 `packages/*` 는 지우고 루트 `workspace:` 목록을 다시 쓴다.
4. `--prefix` 가 있으면 `skeleton_` → `<prefix>_` 로 바꾼다(pubspec 이름 · import).
5. `capabilities.json` 을 `mode: project` 로 줄인다(고른 것만 남기고, 빠진 것은 `omitted`).
6. README · CLAUDE.md · CHANGELOG 를 프로젝트용으로 바꾼다. new-project 도구는 따라가지 않는다.

`scripts/test-new-project.sh` 는 기본 찍기와 `--packages` 하나 찍기를 해 본 뒤 찍힌 곳에서 `flutter pub get` · `analyze` · `test` 를 돌린다. CI 에서는 new-project 관련 파일이 바뀐 PR 에서만 돈다.

## 7. 카탈로그 짝 맞추기 — 2단계

- `capabilities.json` 은 react 와 같은 뼈대로 둔다: `schemaVersion` · `mode` · `name` · `summary` · `newProject` · `capabilities[]`(`id` · `kind` · `package` · `path` · `stampFlag` · `needs` · `backend{modules, oneOfModules, optionalModules, basePaths, docs}` · `pairsWith{react: [id…]}` · `notFor` · `keywords{ko,en}`) · `decisions` · `examples`. `siblings` 에 kotlin · react 를 적는다.
- `tool/build_capabilities.dart` 가 `docs/capabilities.md` · `llms.txt` 를 만들고, `--check` 로 어긋남을 막는다. 검사하는 것: 항목과 실제 패키지 목록, `needs` = pubspec 의 `skeleton_*` 의존, `docs` 경로 존재.
- **짝 레포 검사는 옆에 클론돼 있을 때만 읽는다**(react `siblingCheck.mjs` 와 같다). `../kotlin-skeleton/docs/modules/README.md` 에 `backend.*` 모듈 이름이 다 있는지, `../react-skeleton/capabilities.json` 에 `pairsWith.react` id 가 있는지 본다. 옆 레포는 고치지 않는다.
- kotlin 쪽 등록(모듈 항목의 `frontend` 옆에 flutter 짝을 적을지)은 정해야 할 것 3.

## 8. 시험 전략(국소 위주)

- **패키지 단위 시험**: 바뀐 패키지 폴더에서만 `dart test`(api_client) · `flutter test`(auth · ui · 앱) 를 돌린다. melos 로는 `melos exec --scope=<pkg> -- flutter test`. 전체(`melos run test`)는 조각이 끝날 때 한 번 돈다.
- **HTTP 가짜**: Dio `HttpClientAdapter` 를 가짜로 바꿔 끼운다. 라이브러리(`http_mock_adapter`)를 쓸지 직접 작은 가짜를 둘지는 developer 가 정한다(내 판단: 둘 다 무방).
  - 반드시 덮을 경우: envelope 벗기기 3종, 에러 코드 해석, 401 이 동시에 여럿 와도 refresh 는 한 번, refresh 실패 → 로그아웃, 재시작 복원.
- **위젯 시험**: 스타터에서 로그인 → 내 정보 → 로그아웃, 그리고 잘못된 비밀번호면 `AUTH.INVALID_CREDENTIALS` 문구를 보여 주는지. `ProviderScope` override 로 가짜 저장소와 가짜 어댑터를 넣는다.
- **백엔드 계약 시험**: `packages/auth/test/backend/`, 태그 `backend`. `API_BASE_URL` · 시드 계정 환경변수가 있을 때만 돌고 없으면 건너뛴다(kotlin `FcmRealSendTest` 와 같은 방식). 순수 Dart 로 login → me → refresh → logout 을 실제 `apps/api` 에 대고 돈다. 기기가 없어도 끝에서 끝까지를 증명한다.
- 기기 통합 시험(`integration_test`)은 1단계에 두지 않는다. CI 에 에뮬레이터가 필요해 비싸다.

## 9. CI(`.github/workflows/ci.yml`, ubuntu)

1. `subosito/flutter-action`(`flutter-version-file: pubspec.yaml`, 캐시) → `flutter pub get`
2. `dart format --output=none --set-exit-if-changed .` · `melos run analyze` · `melos run test`
3. `flutter build apk --debug`(apps/starter) — Gradle·매니페스트 깨짐을 잡는다
4. 2단계: `dart run tool/build_capabilities.dart --check`, new-project 경로가 바뀌었을 때만 `test-new-project.sh`

백엔드 계약 시험은 CI 에서 돌리지 않는다. react 처럼 kotlin `apps/api` 를 CI 에 띄우는 잡은 다음에 넓힐 것으로 둔다. iOS 빌드(macOS 러너)도 다음에 넓힐 것이다.

## 10. 확인 못 한 것

- **이 맥에 Flutter·Dart·Melos 가 없다**(`which flutter dart melos` 셋 다 없음). 구현 전에 설치가 필요하다. 1단계 확인에 쓸 Android 에뮬레이터·iOS 시뮬레이터(Xcode)가 있는지도 보지 않았다.
- 현행 Flutter stable 과 Melos 메이저 번호는 만들 때 확인한다. 검색에서는 Melos 문서가 8.x 로 보였고, 참조 레포 README 는 8, 레포 설명은 7 로 서로 다르다.
- pub workspace 가 이제 glob 을 받는지 확인하지 않았다(검색 결과는 「아직 안 받는다」). 받는다면 §6 의 3번이 더 쉬워진다.
- **모바일 소셜 로그인**: 백엔드 `GET /auth/methods` 가 PKCE·인가 URL 을 주지만, 제공자별로 앱 리다이렉트(커스텀 스킴·앱 링크)를 받아 주는지, 카카오·구글 네이티브 SDK 토큰을 교환하는 길이 있는지는 보지 않았다. 다음에 넓힐 것 4 의 선결 조사다.
- kotlin `apps/api` 시드 사용자의 정확한 계정·환경변수 이름은 보지 않았다. 구현할 때 kotlin `docs/minimal-composition.md` 와 `apps/api` 를 확인한다.

## 11. 작업 목록

| 키 | 내용 | 의존 | 크기 |
|---|---|---|---|
| F1 | 레포 뼈대: 루트 pubspec(workspace · melos 스크립트) · `skeleton_lints` · `.gitignore` · CI(§9 의 1~3, 앱 빌드는 F5 이후 켬) · README · CLAUDE.md · CHANGELOG | — | 작음 |
| F2 | `skeleton_api_client`: Dio 생성, envelope 3종, `ApiRequestError` · `ErrorCodes`(쓰는 것만), 헤더 공급자 · 에러 처리기 자리, 단위 시험, README(API 표) | F1 | 중간 |
| F3 | `skeleton_auth`: `TokenStore`(보안 · 메모리), `AuthApi`, 인증 인터셉터(리프레시 한 번만 돌리기), `AuthSession`, redirect 도우미, `LoginForm`, 단위·위젯 시험 + 백엔드 계약 시험(태그) | F2 | 큼 |
| F4 | `skeleton_ui`: 토큰 · 라이트/다크 ThemeData · 로딩/에러 부품 | F1 | 작음 |
| F5 | `apps/starter`: 설정(dart-define) · 라우터(/login · /me) · 내 정보 화면 · 재시작 복원 · 디버그 전용 cleartext · 위젯 시험 · `flutter build apk --debug` CI 켜기. **여기까지가 1단계** | F3, F4 | 중간 |
| F6 | 카탈로그: `capabilities.json` · 스키마 · `tool/build_capabilities.dart`(생성 + `--check` + 짝 레포 검사) · CI 연결 | F5 | 중간 |
| F7 | `new-project.sh` + `tool/new_project/stamp.dart` + `test-new-project.sh` + CI(경로 필터) | F6 | 큼 |

F2 와 F4 는 나란히 갈 수 있다. 1단계 = F1~F5 이고, F5 가 끝나면 형에게 한 번 보여 준다.

## 정해야 할 것

1. **상태관리**(패키지 `auth` 와 앞으로 화면을 가진 패키지가 무엇에 묶이는지가 정해진다)
   - **Riverpod 3 (추천)**: 신규 Flutter 에서 가장 흔하고 DI 를 겸한다. 참조 레포와도 같다.
   - Bloc/Cubit: 큰 팀에서 흔하다. 상태 전이를 명시적으로 쓰지만 코드가 길어진다.
   - 패키지는 상태관리 없이 `ValueListenable`/`Stream` 만 내보내고 앱이 고른다: 가장 중립적이다. 대신 앱마다 연결 코드를 다시 쓰고, react 패키지가 훅을 주는 것과 어긋난다.
2. **레포 자리**
   - **별도 공개 레포 `flutter-skeleton` (추천)**: kotlin · react 가 각자 레포다. SDK·CI·버전 태그·CHANGELOG 가 섞이지 않는다.
   - react-skeleton 안의 `apps/` · `packages/` 에 둔다: 카탈로그가 하나가 된다. 대신 pnpm 과 pub 워크스페이스가 한 레포에 섞이고 CI 가 무거워진다.
3. **kotlin 카탈로그에 flutter 짝을 적을지**(kotlin 레포를 고치게 된다)
   - **flutter 쪽 `backend` 가 정본이고, kotlin 에는 `siblings.mobile` 한 줄만 (추천)**: kotlin 을 거의 안 건드린다. 「이 모듈의 모바일 짝」은 flutter 카탈로그에서 찾는다.
   - kotlin 모듈 항목마다 `mobile` 짝도 적고 양쪽에서 검사한다: 찾기는 가장 쉽다. 대신 모듈 129개의 카탈로그와 가드를 고쳐야 하고, flutter 패키지가 늘 때마다 kotlin PR 이 따라간다.

## 12. 3단계 — 기본 서비스

형 지시 원문: "계속 쭉 해. 일단 기본 서비스 할 수 있는 수준으로. 가입, 푸시, 게시판 개념, 결제 위주로"

**3단계(최소 버전)**: 스타터에서 가입(메일 6자리 코드) → 바로 로그인 → 비밀번호 재설정 → 탈퇴까지 된다. 참조 앱 `apps/sample` 에서는 게시판(글 · 댓글 · 반응), 푸시(기기 등록 · 종류별 끄기 · 시험 알림 · 눌러서 이동), 토스 결제(주문 → 결제창 → 승인 → 내 결제 내역)를 kotlin `apps/sample` 에 대고 끝에서 끝까지 돌린다.

### 12.1 비목표(3단계에서 하지 않는 것)

- 소셜 · 매직 링크 로그인, MFA, 로그인 아이디, 이메일 변경, 연락 이메일, 세션 목록, 탈퇴 취소 화면
- 게시판: 비회원 글, 첨부 · 사진, 운영자 도구(숨김 · 고정 · 승인), 검색 · 정렬 바꾸기, 임시저장, 작성자 프로필 고르기 화면
- 푸시: 클릭 열람 보고(`POST /push/opened` — kotlin FCM 전달기가 아직 `open` 을 안 싣는다), 광고 동의, 내 다른 기기 목록, 알림함(`notifications`), 앱이 켜져 있을 때 안드로이드 시스템 알림 띄우기
- 결제: 카카오페이 · 네이버페이 직접 연동, Paddle, 구독, 환불 요청, 쿠폰, 인앱결제(IAP)
- 캡차(kotlin 은 기본 꺼짐), 다국어, iOS 빌드 CI, 기기 통합 시험

### 12.2 무엇을 어디에 둘지

| 패키지(id) | 짝 백엔드 | 하는 일 | 확장 지점 |
|---|---|---|---|
| `auth`(넓힘) | `auth` · `auth-session` + `account` · `account-jdbc` | 지금 것 + `AccountApi`(sign-up · verification/resend · verify-email · password forgot/reset/policy · delete), 위젯 `SignUpForm` · `VerifyCodeForm` · `ForgotPasswordForm` · `ResetPasswordForm` · `DeleteAccountForm` | `authRedirect(publicPaths:)`, `AuthSession.signInWith(AuthResult)`(코드 확인이 곧 로그인), `signOutHooksProvider`(로그아웃 직전에 부를 일 목록), `SignUpForm` 의 동의 칸 자리, 문구 매개변수 |
| `legal`(새) | `legal` · `legal-jdbc` | 문서 읽기(`GET /legal/documents` · `/{type}`), 가입 동의 체크 목록, 동의 화면(`missing` 을 받아 `POST /legal/consents`), `403 LEGAL.RECONSENT_REQUIRED` 를 받으면 「동의 필요」 상태로 바꾸는 인터셉터 + redirect 도우미 | 문구 매개변수 |
| `board`(새) | `board` · `board-jdbc` (선택 `author-profile` · `idempotency`) | `BoardApi`, `PostListView`(쪽 넘김 · 당겨서 새로고침) · `PostDetailView`(본문 · 반응 · 댓글 트리) · `PostEditor`(쓰기 · 고치기) · 지우기 | 게시판 코드는 매개변수, `boardAuthorResolverProvider`(`authorRequired` 서버에서 글쓴이 id 를 주는 함수), 반응 종류별 라벨 · 아이콘 맵 |
| `push`(새) | `notification-push` · `notification-push-jdbc` · `notification-fcm` | `PushApi`(config · devices · preferences · test), `PushController`(못 씀 · 안 물음 · 거절 · 켜짐), `PushPrompt`(앱 안 띠 → 눌러야 권한 요청), `PushSettingsView`(이 기기 스위치 · 종류별 스위치 · 시험 알림), 탭한 알림의 `link` 넘기기 | `PushTokenSource` 인터페이스(Firebase 구현 + 시험용 가짜), `onOpenLink` 콜백(이동은 앱 라우터가 한다) |
| `payment`(새) | `payment` · `payment-jdbc` · `payment-toss` | `PaymentApi`(config · orders · confirm · order · 내 주문 목록), `purchase()` 흐름(주문 → 결제창 → 승인 → 확인 중이면 되묻기), `TossCheckoutPage`(WebView), `OrderListView` · `PaymentResultView` · 테스트 결제 띠 | `checkout.kind` 로 가르는 한 곳(지금은 `TOSS_PAYMENT_WINDOW` 만, 그 밖은 「지원 안 함」 오류), 결제창 돌아올 주소(successUrl · failUrl) 매개변수 |

결정과 근거:

- **가입 · 재설정 · 탈퇴는 `auth` 안에 둔다(새 패키지 없음).** react 도 `account-lifecycle` 을 `@skeleton/auth` 안의 패턴으로 둔다. 카탈로그는 `auth` 의 `pairsWith.react` 에 `account-lifecycle` · `session-refresh` 를 더한다. 스키마에 `pattern` 종류를 새로 만들지 않는다.
- **`legal` 패키지를 더한다.** 형이 고른 범위는 아니지만 없으면 가입이 안 된다. kotlin `apps/api` 는 `legal` 이 있어 `terms` · `privacy` 동의 없이 가입하면 `400 LEGAL.CONSENT_REQUIRED` 다. 재동의 필터(`apps/api` · `apps/sample` 이 켬)는 새 판이 나오면 게시판 · 결제 호출을 모두 `403` 으로 막는다. `auth` 와 `legal` 은 서로를 모르고, 동의 목록을 가입 요청에 잇는 일은 스타터가 한다.
- **스타터는 계정 수명주기까지, 게시판 · 푸시 · 결제는 새 `apps/sample` 에 둔다.**
  - 새 프로젝트를 찍을 때 고르지 않은 패키지는 지워진다. 그래서 스타터가 `board` 를 import 하면 `--packages` 없이 찍은 프로젝트가 컴파일되지 않는다. react 가 starter · sample 을 나눈 이유와 같다.
  - 짝 백엔드도 갈린다. 스타터는 kotlin `apps/api`(계정 · 동의만), 샘플은 kotlin `apps/sample`(게시판 · 푸시 · 결제 · 시드 계정 · `general` 게시판 · 응원 상품)이다.
  - 샘플은 찍을 때 늘 빠진다(`stampFlag.included: never`). 프로젝트는 샘플의 화면 묶음을 보고 자기 앱에 라우트를 붙인다(react 카탈로그 `byHand` 와 같다).
- **결제는 토스 결제창(API 개별 연동 키 `test_ck_`)을 WebView 로 연다.**
  - 토스 공식 Flutter SDK(`tosspayments_widget_sdk_flutter`)는 결제위젯 전용이고 결제위젯 키(`gck`)를 쓴다. kotlin `payment-toss` 는 결제창 키(`ck`/`sk`)만 내주므로 그 SDK 로는 승인이 맞지 않는다.
  - WebView 는 `flutter_inappwebview` 를 쓴다. 토스 웹뷰 안내가 `webview_flutter_android` 3.16.0 이하만 쓰라고 한다(이후 판에서 일부 카드 앱이 안 열림). 오래된 판에 묶이지 않으려고, 토스 자기 Flutter SDK 가 쓰는 쪽을 고른다.
  - 결제창 페이지는 JS SDK v2 를 싣는 작은 HTML 이고 앱이 그 문자열을 불러온다. 돌아올 주소는 실제로 열리지 않는 고정 주소이고, WebView 가 그 주소로 가려는 순간 가로채 `paymentKey` · `orderId` · `amount` 를 읽는다.
- **푸시는 `firebase_messaging` 을 쓰고 Firebase 설정 파일은 커밋하지 않는다.**
  - 공개 레포라 Firebase 프로젝트가 없다. 샘플은 `FirebaseOptions` 를 `env/dev.json` 의 dart-define(`FIREBASE_API_KEY` · `FIREBASE_PROJECT_ID` · `FIREBASE_MESSAGING_SENDER_ID` · `FIREBASE_ANDROID_APP_ID` · `FIREBASE_IOS_APP_ID`)으로 만든다. 값이 없으면 Firebase 를 띄우지 않고 푸시는 「못 씀」 상태로 앱이 그대로 돈다.
  - 프로젝트가 `flutterfire configure` 로 `firebase_options.dart` 를 만들어 넘겨도 된다. 패키지는 초기화된 Firebase 를 쓰기만 한다(README 에 두 길을 적는다).
  - `google-services.json` · `GoogleService-Info.plist` 는 `.gitignore` 에 넣는다.
- **인앱결제 규정**: 앱 안에서 쓰는 디지털 상품(이용권 · 아이템 · 창작자 후원)은 Apple 3.1.1 · Google Play 결제 정책에 따라 IAP 가 강제된다. 앱 밖에서 받는 실물 · 서비스(3.1.3(e))는 반대로 PG 를 쓴다. 그래서 `payment` 카탈로그의 `notFor` 와 README 에 「실물 · 앱 밖 서비스용, 디지털 상품은 IAP(아직 없음)」를 적는다. 샘플의 `cheer`(응원)는 kotlin 견본 상품을 빌린 시연일 뿐 그대로 출시하면 심사에 걸린다는 것도 적는다.

### 12.3 패키지마다 막아야 할 진짜 문제

**auth(가입 · 재설정 · 탈퇴)**
- 가입 시도(`signUpId` · `expiresAt`)를 저장소에 둔다. 메일 앱으로 넘어간 사이 안드로이드가 앱을 죽여도 코드 입력 화면으로 돌아와야 한다. 확인되거나 만료되면 지운다.
- `resendAvailableAt: null` 이면 다시 보내기 단추를 숨긴다. 카운트다운은 기기 시계로 하고 판정은 서버(`410 CODE_EXPIRED`)를 따른다. `400 ACCOUNT.CODE_INVALID` 는 `data.attemptsLeft` 를 보인다.
- 로그아웃 상태에서도 `/sign-up` · `/verify` · `/forgot-password` · `/reset-password` 로 갈 수 있어야 한다. 지금 redirect 는 모두 `/login` 으로 보낸다 → `publicPaths` 를 더한다.
- 재설정 링크는 `<link-base-url>/reset-password?token=`(웹 주소)다. 앱에 같은 경로의 라우트를 두어, 프로젝트가 App Links · Universal Links 를 걸면 그대로 앱이 연다(도메인 · `assetlinks.json` · AASA 는 프로젝트 몫, README 에 적음). 성공하면 모든 세션이 끝나므로 로컬도 로그아웃한다. 토큰은 로그에 남기지 않는다.
- **탈퇴는 앱 안에 있어야 한다.** 가입이 있는 앱은 Apple 5.1.1(v) 가 이것을 요구한다. 비밀번호로 다시 인증하고, `Idempotency-Key` 는 제출 한 번에 하나다(재시도는 같은 키). `202` 를 받으면 로컬도 로그아웃하고, `409 ACCOUNT.DELETION_BLOCKED` 는 문구로 보인다.
- `GET /account/password/policy` 로 힌트를 보인다. 길이 상한은 UTF-8 **바이트**(`maxBytes`)다.
- **닉네임**: 서버는 가입에 닉네임이 필요한지 알려 주지 않는다(`required-on-sign-up`). 가입 폼은 `DisplayNameMode`(none 기본 · optional · required)를 앱 설정으로 받고, 앞뒤 공백을 떼어 보낸다. `400` 의 `errors[].field` 는 그 칸 아래에 보이고(`message` 는 로그용이라 안 보인다) 칸에 안 맞는 것만 공통 문구다. `verify-email` 의 `409 DISPLAY_NAME_TAKEN` 은 시도를 소모하지 않으므로 닉네임 칸을 띄워 같은 `signUpId`·코드로 다시 보낸다. 닉네임 없는 계정(`/account/me` 의 `displayName` 이 null)은 `DisplayNameForm`(`PATCH /account/me`)으로 받고, `displayTag` 가 있으면 `이름#태그` 로 보인다.
- **로그인 아이디**: 앱 설정이 없다. `GET /auth/methods` 에 `loginId{minLength,maxLength}` 키가 있을 때만 가입 폼에 아이디 칸이 생기고(길이는 그 키), 로그인 입력은 「ID or email」이 되며 `@` 없는 입력은 `username` 으로 보낸다. `verify-email` 의 `409 LOGIN_ID_TAKEN` 은 시도를 소모하지 않으므로 닉네임과 같이 칸을 띄워 같은 `signUpId`·코드로 다시 보낸다. 키가 없으면 지금과 똑같다.
- **계정 게이트**: 서버 순서는 `ACCOUNT.LOGIN_ID_REQUIRED` → (`EMAIL_REQUIRED`) → `LEGAL.RECONSENT_REQUIRED` 이고, 앱의 닉네임이 맨 뒤다. 아이디 없는 계정은 `/account/me` 의 `loginId: null`(키가 있고 null) 또는 어떤 호출의 403 으로 알고, 서버는 아이디 엔드포인트 밖의 모든 호출을 막으므로 아이디 정하기(`LoginIdForm`, `POST /account/login-id`, 한 번뿐)가 먼저다. 라우터는 올라와 있는 게이트 중 **첫 것**만 정해 다음 게이트가 앞 게이트 화면에서 사람을 끌어내지 못하게 한다. 게이트 화면마다 로그아웃 출구가 있어야 앱이 갇히지 않는다. 입력 중 확인(`/account/login-id/availability`)은 조언일 뿐이고 429·실패는 「확인하지 못했다」로 두며 거절하지 않는다.
- **이메일 필수**: `me.emailRequired` 는 로그인 직후 막고(읽기도 403), `me.emailRequiredToWrite` 는 읽기를 막지 않고 쓰기 직전에 미리 안내한다(게시판 위 띠 + 글쓰기 단추가 먼저 등록 화면을 연다). 쓰기가 `403 ACCOUNT.EMAIL_REQUIRED` 로 막혀도 같은 화면이 열리고 「나중에」로 닫을 수 있다. 확인이 끝나도 막혔던 호출을 자동으로 다시 보내지 않는다(사용자가 같은 동작을 다시 한다 — 계약 E12 는 같은 호출 재전송이라 적었지만 이 앱은 아이디 게이트와 같은 방식으로 맞췄다). 오래된 세션의 `REAUTH_REQUIRED` 는 `socialReauth` 로 제공자 재인증을 받아 한 번 더 보낸다. 이미 계정이 있는 사람의 출구는 `POST /account/discard`(확인 창 뒤, 로컬 로그아웃)와 로그아웃이다.

**legal**
- 가입 폼은 `requiredAtSignUp` 문서마다 체크를 둔다. 선택 문서는 체크하지 않은 채로 둔다. 실은 판(`version`)을 그대로 보내고, `400 LEGAL.CONSENT_REQUIRED` 면 문서를 다시 읽는다.
- `403 LEGAL.RECONSENT_REQUIRED` 는 로그아웃 · 갱신 대상이 아니다. 동의 화면으로 보내고 끝나면 원래 화면으로 돌아간다. 막힌 호출을 붙잡아 다시 보내지는 않는다 — 돌아간 화면이 다시 읽는다.
- 문서 본문은 마크다운 원문을 그대로 고른 글자로 보인다(렌더러는 다음).

**board**
- 본문은 평문으로만 그린다(HTML 해석 없음). 지워진 · 가린 댓글은 `body: null` 이다. 자리를 남겨 스레드 모양을 지킨다.
- 「내 글」 판정은 서버의 `mine` 이다. `accountId` 와 비교하지 않는다(작성자 프로필 서버에서는 늘 다르다).
- `GET /config` 의 `authorRequired` 가 참인데 resolver 가 없으면 쓰기 단추를 감추고 이유를 보인다(죽지 않는다).
- 글 · 댓글 만들기는 제출마다 `Idempotency-Key` 를 하나 쓰고, 보내는 동안 단추를 막는다(두 번 눌러 두 글).
- 댓글 깊이 상한(config)에 닿은 댓글에는 답글 단추가 없다. 길이 상한도 config 에서 읽는다.
- 상세 GET 은 조회수를 올린다. 댓글 · 반응 뒤에는 그 부분만 다시 읽는다.
- `403 ACCOUNT.EMAIL_REQUIRED` · `LOGIN_ID_REQUIRED`(샘플 서버의 관문)는 문구로 보인다. 그 화면은 비목표다.

**push**
- 권한은 앱 안 띠를 사람이 눌렀을 때만 묻는다. iOS 는 한 번 거절하면 앱에서 다시 못 묻는다. Android 13+ 는 `POST_NOTIFICATIONS` 다. 거절되면 설정으로 가는 안내만 한다.
- 등록(`PUT /devices/{installationId}`)은 로그인 상태이고 `config.fcm == true` 일 때만 한다. 앱 시작, 로그인 직후, `onTokenRefresh` 마다 보낸다. `400 PUSH.KIND_DISABLED` 는 「못 씀」으로 본다.
- `installationId` 는 설치마다 하나(`[A-Za-z0-9_-]{16,64}`)이고 `shared_preferences` 에 둔다. 앱을 지우면 같이 사라진다. iOS Keychain 은 다시 깔아도 남아 「설치마다」가 깨진다.
- 로그아웃 **전에** `DELETE /devices/{id}` 를 한다. auth 의 `signOutHooksProvider` 에 걸고 시간 상한을 둔다(오프라인이라도 로그아웃은 멈추지 않는다).
- 알림을 탭하면 `data.link` 로 간다. `/` 로 시작하고 `//` · 스킴이 없는 앱 안 경로만 받고 나머지는 버린다. 꺼진 앱이 탭으로 켜지면(`getInitialMessage`) 세션 복원이 끝난 뒤에 이동한다.
- 앞에 켜져 있을 때: iOS 는 표시 옵션을 켠다. Android 는 시스템이 안 띄우므로 메시지 스트림만 내고 샘플이 SnackBar 로 보인다. 토큰은 로그에 남기지 않는다.

**payment**
- 금액은 클라이언트가 정하지 않는다. 주문은 `(itemType, itemRef, quantity)` 로만 만든다. 승인에 보내는 `amount` 는 **서버 주문의 금액**이다. 돌아온 주소의 `amount` · `orderId` 가 주문과 다르면 승인하지 않는다.
- `Idempotency-Key` 는 「구매」 한 번에 하나다. 같은 시도를 다시 보내면 같은 주문(`200`)을 받는다.
- WebView 안의 처리:
  - 돌아올 주소는 로드 전에 가로챈다.
  - Android 의 `intent://` 는 앱 스킴으로 바꿔 연다. 앱이 없으면 `market://` 으로 보낸다. 그 밖의 비 http 스킴은 `url_launcher` 로 연다.
  - 샘플 네이티브 설정에 카드 · 은행 앱 목록을 넣는다(Android `<queries>`, iOS `LSApplicationQueriesSchemes`, 토스 문서의 목록).
  - 이 판단은 순수 함수(`classifyCheckoutNavigation` · intent 변환)로 빼서 시험한다.
- 승인 결과:
  - `200` → 결제됨.
  - `202 CONFIRMING` → `GET /orders/{id}` 를 간격을 늘리며 되묻는다(횟수 상한, 넘으면 「확인 중 — 내역에서 확인」).
  - `402 DECLINED` → `data.category` 로 문구를 고른다.
  - 창을 닫으면 → 「취소함」. 주문은 서버 만료 작업이 닫는다.
- 앱이 승인 전에 죽으면 토스는 승인 API 전까지 돈을 옮기지 않는다. 다음에 「내 결제 내역」이 서버 상태를 보인다.
- `available: false` → 「지금은 결제할 수 없어요」. `testMode` → 테스트 결제 띠를 늘 보인다. 결제는 테스트 키로만 한다(토스 문서의 공개 테스트 키).

### 12.4 작업 목록

| 키 | 내용 | 의존 | 크기 |
|---|---|---|---|
| F8 | `api_client`: `newIdempotencyKey()`(UUID v4 모양, `Random.secure`) + 시험 — 여러 패키지가 같이 쓰는 것이라 먼저 넣는다(지휘가 직접 해도 된다) | — | 작음 |
| F9 | `auth` 넓히기: `AccountApi` · 가입 시도 저장 · `signInWith` · `publicPaths` · `signOutHooksProvider` · 다섯 폼 위젯(문구 매개변수), 단위 · 위젯 시험, 백엔드 계약 시험(`apps/api`) | F8 | 큼 |
| F10 | `legal` 새 패키지: 문서 · 동의 API, 가입 체크 목록, 동의 화면, 재동의 인터셉터 + redirect 도우미, 시험, 계약 시험(`apps/api`) | F8 | 중간 |
| F11 | `starter`: `/sign-up` · `/verify` · `/forgot-password` · `/reset-password` · `/account`(탈퇴) · `/consent` 라우트, 가입 폼에 동의 체크 목록 잇기, 위젯 시험(가입 → 코드 → 로그인, 재설정, 탈퇴), README(재설정 링크 · 앱 링크) | F9, F10 | 중간 |
| F12 | `board` 새 패키지: API · 목록 · 상세(반응 · 댓글 트리) · 편집기 · 지우기, author resolver 자리, 시험, 계약 시험(`apps/sample`, 시드 계정 + `general`) | F8 | 큼 |
| F13 | `push` 새 패키지: API · `PushTokenSource`(Firebase 구현 + 가짜) · `PushController` · `PushPrompt` · `PushSettingsView` · 링크 거르기, 시험, 계약 시험(`apps/sample`: config · preferences · 기기 등록은 `fcm` 이 켜져 있을 때 200, 아니면 400 `KIND_DISABLED`) | F8 | 중간 |
| F14 | `payment` 새 패키지: API · `purchase()` · `TossCheckoutPage`(flutter_inappwebview) · 돌아올 주소와 intent 순수 함수 · 결과 · 내역 · 테스트 띠, 시험, 계약 시험(`apps/sample` + 토스 테스트 키: config · 주문 만들기 · 같은 키 재전송 · 내역) | F8 | 큼 |
| F15 | `apps/sample`(flutter create, android · ios): 로그인 → 탭(게시판 · 결제 · 설정), board resolver(`GET /author-profiles` 첫 프로필), 푸시 잇기(Firebase dart-define · sign-out hook · 링크 이동 · SnackBar), 결제 화면(`cheer-3000`), 네이티브 설정(`<queries>` · `POST_NOTIFICATIONS` · `LSApplicationQueriesSchemes` · 푸시 entitlements · 디버그 전용 cleartext), 위젯 시험, CI 에 `flutter build apk --debug` 추가 | F9, F10, F12, F13, F14 | 큼 |
| F16 | 카탈로그 · 찍기: `legal`(always) · `board` · `push` · `payment`(flag) · `app-sample`(`never` — 스키마에 값 더함) 항목, `auth` 요약 · 백엔드 · `pairsWith` 고치기, stamp 가 `apps/sample` 을 지우고 `--packages board,push,payment` 를 따르게, `test-new-project.sh` 에 그 조합 한 번, CLAUDE.md · README · CHANGELOG | F11, F15 | 중간 |

**서로 기다리지 않는 묶음**: F8 이 끝나면 **F9 · F10 · F12 · F13 · F14 다섯이 나란히** 간다. 서로의 파일을 건드리지 않는다. push 의 sign-out 연결은 샘플(F15)에서 하므로 F13 은 F9 를 기다리지 않는다. 그다음 F11 과 F15 가 나란히 가고(F11 은 F9 · F10 끝나는 대로), 마지막이 F16 이다. 다섯을 나란히 띄우면 developer 다섯이 동시에 돈다(비용).

### 12.5 시험 전략

- **국소 시험**: 바뀐 패키지 폴더에서만 `flutter test` 를 돌린다. 전체 `melos run analyze` · `melos run test` 는 묶음이 끝날 때 지휘가 한 번 돌린다.
- **HTTP 가짜**: 지금의 `skeleton_api_client/testing.dart` 의 `FakeAdapter` 를 그대로 쓴다. 반드시 덮을 것:
  - 가입: 시도 저장과 복원, `attemptsLeft`, `resendAvailableAt: null`
  - 탈퇴: 같은 키로 재시도
  - 재동의: 403 이 로그아웃으로 새지 않는다
  - 게시판: 지워진 댓글 자리, `authorRequired` 인데 resolver 없음
  - 푸시: 로그인 전 · `fcm:false` 면 등록 안 함, 로그아웃 전 DELETE 순서, 바깥 링크 버림, 꺼진 앱 탭이 복원 뒤에 이동
  - 결제: 금액이 다른 돌아온 주소는 승인 안 함, 202 되묻기 상한, 402 category 문구
- **순수 함수 시험**: 결제의 돌아올 주소 판정과 intent → 앱 스킴 변환. 토스 문서의 intent 예시 몇 개를 넣는다. WebView 위젯 자체는 플랫폼이 없어 시험하지 않으므로 얇게 둔다.
- **백엔드 계약 시험**(태그 `backend`, 순수 Dart, 환경변수가 있을 때만):
  - 스타터 쪽은 kotlin `apps/api` 에 대고 돈다. 동의 없는 가입이 `400 LEGAL.CONSENT_REQUIRED`, 동의 있는 가입이 `202 signUpId`, 틀린 코드가 `400 CODE_INVALID`, forgot 이 `202`, 두 번째 시드 계정 탈퇴가 `202` 인지 본다. 메일의 코드는 못 읽으니 「코드 확인 → 로그인」은 위젯 시험으로 덮는다.
  - 샘플 쪽은 kotlin `apps/sample` 로컬 프로필(시드 `user@example.com`, 토스 테스트 키)에 대고 돈다. 서버는 F3 처럼 scratchpad 복사본 + 별도 compose 프로젝트로 띄우고 끝나면 내린다. kotlin 레포는 고치지 않는다.
- **CI**: `flutter build apk --debug` 를 starter · sample 둘에 돌린다. 플러그인(Firebase · WebView)의 Gradle · 매니페스트 · minSdk 깨짐을 잡는다. 계약 시험은 CI 에서 돌리지 않는다.
- **이 맥에서 확인할 수 없는 것**(Android SDK · Xcode 시뮬레이터 없음): 푸시 실수신과 탭 이동, 토스 결제창 표시와 카드 앱 전환, 재설정 링크의 앱 열림, iOS 빌드. 실기기 확인은 형 기기가 생길 때 qa 에 넘길 목록으로 README 에 남긴다.

### 12.6 다음에 넓힐 것(순서는 추천)

1. 인앱결제(`in_app_purchase` + kotlin 영수증 검증 모듈 — 백엔드부터) · 환불 요청 · 구독
2. 카카오페이 · 네이버페이 직접 연동(`*_REDIRECT` 를 같은 WebView 가로채기로), Paddle 은 모바일에서 빼는 게 맞는지 확인
3. 알림함(`notifications`) · 푸시 클릭 열람 보고(kotlin FCM 전달기가 `open` 을 실은 뒤) · 내 다른 기기 목록 · 광고 동의
4. 게시판 첨부(`storage`) · 작성자 프로필(`author-profile`) · 운영자 도구 · 검색
5. 소셜 로그인 · 로그인 아이디 · 이메일 필수 관문 화면, 문서 마크다운 렌더링, `--with-sample`, iOS 빌드 CI

## 정해야 할 것(3단계)

1. **결제 범위**(이번에 무엇을 만드는지가 바뀐다)
   - **토스 결제창(WebView)만, 실물 · 앱 밖 서비스용으로 못 박기 (추천)**: kotlin 이 지금 받아 주는 길이고 국내 PG 앱의 관행이다. 디지털 상품용 IAP 는 백엔드 영수증 검증부터 필요해 따로 간다.
   - IAP 까지 이번에: 디지털 상품 앱도 바로 쓸 수 있다. 대신 kotlin 에 Apple · Google 영수증 검증 모듈이 먼저 있어야 한다(지금 없음).
   - 카카오페이 · 네이버페이 직접 연동도 이번에: 토스 계약 없이 쓰는 프로젝트를 덮는다. 대신 F14 가 두 배가 되고 기기 확인 못 한 경로가 늘어난다.
2. **비밀번호 재설정 링크를 앱에서 어떻게 받을지**
   - **앱에 `/reset-password` 라우트와 화면을 두고, 앱 링크 연결은 프로젝트가 도메인으로 (추천)**: 백엔드는 그대로다. 링크가 안 걸린 프로젝트에서는 웹(react) 재설정 화면이 받는다.
   - 앱은 요청만 하고 재설정은 늘 웹에서: 앱이 가장 작다. 대신 웹이 없는 모바일 단독 프로젝트는 재설정을 못 한다.
   - kotlin 에 「메일 6자리 코드로 재설정」을 더한다: 링크 · 도메인 없이 앱 안에서 끝난다. 대신 kotlin 레포를 고쳐야 하고 보안 검토가 다시 필요하다.
3. **게시판 · 푸시 · 결제 화면을 둘 자리**
   - **새 참조 앱 `apps/sample`, 찍을 때 늘 빠짐 (추천)**: 고르지 않은 패키지가 지워져도 스타터가 컴파일된다. react 의 starter · sample 과 같다.
   - 스타터에 다 넣고 찍을 때 고르지 않은 화면 코드를 도려낸다: 앱이 하나로 끝난다. 대신 stamp 가 Dart 코드를 잘라 내는 일을 맡아 깨지기 쉽다.

## 확인 못 한 것(3단계)

- **토스 JS SDK v2 를 `loadHtmlString` 으로 띄운 WebView**(origin 이 우리가 준 baseUrl)에서 결제창이 뜨는지 확인하지 않았다. 열리지 않는 고정 돌아올 주소를 토스가 받아 주는지도 확인하지 않았다. 안 되면 결제창 HTML 을 정적 파일로 어딘가 올려야 한다(백엔드 또는 웹). F14 첫 단계에서 실제 테스트 키로 재 본다(기기 없이는 Android 에뮬레이터 대신 데스크톱 브라우저로 같은 HTML 을 열어 보는 정도).
- `flutter_inappwebview` 로 카드 · 은행 앱 전환이 되는지는 기기에서만 알 수 있다. 토스의 `webview_flutter_android` ≤ 3.16.0 경고가 지금 판에도 맞는지 확인하지 않았다.
- `google-services.json` 없이 Dart 의 `FirebaseOptions` 만으로 Android FCM 토큰이 나오는지는 검색으로 확정하지 못했다. 안 되면 샘플만 Google Services Gradle 플러그인을 쓰고, 파일은 gitignore 한 채 없으면 플러그인을 건너뛰게 한다.
- iOS 푸시(APNs entitlement · Background Modes · Firebase 에 APNs 키 올리기)는 Xcode 가 없어 빌드조차 확인하지 못한다.
- Flutter 3.27 부터 딥 링크가 기본으로 켜진다는 것을 기억으로만 안다. App Links · Universal Links 는 도메인이 있어야 확인할 수 있다.
- Apple 심사 지침 3.1.1 · 3.1.3(e) 원문을 이번에 다시 읽지 않았다(검색 결과의 2차 자료). 한국 스토어의 외부 결제 허용(StoreKit External Purchase)도 이번 판단에 넣지 않았다.
- kotlin 로컬 메일이 어디로 가는지(코드를 시험이 읽을 수 있는지) 보지 않았다. 못 읽는다고 보고 시험 전략을 짰다.

## 결정됨 (2026-11-04, 형)

1. 상태관리: Riverpod 3 (손으로 쓴 provider, generator 없음).
2. 레포: 별도 공개 레포 `flutter-skeleton` (GitHub 공개 레포 생성까지 허락).
3. 카탈로그: flutter 쪽 `backend` 가 정본, kotlin 에는 `siblings.mobile` 한 줄만.
4. Flutter SDK: brew cask 로 설치, Melos 는 `dart pub global activate melos`.
5. (3단계, 2026-11-04) 결제는 토스 결제창만(실물·앱 밖 서비스용), IAP 는 디지털 판매 프로젝트가 생길 때. 재설정은 앱 화면 + 앱 링크 도메인 연결은 프로젝트 몫. 게시판·푸시·결제 화면은 apps/sample(찍을 때 빠짐). 형이 질문을 잘 모르겠다고 해 쉬운 설명 후 추천안으로 진행.
6. (3단계 결제 확정, 2026-11-04) 당분간 실물이 없어 앱 결제는 IAP 가 기본이고 지역 스위치(웹 링크)는 기본 꺼짐 자리만 둔다. 3단계에서 토스 WebView · 샘플 결제 화면 · 카탈로그 payment 항목은 만들지 않는다(시도는 로컬 브랜치 `stage3-toss-payment`). IAP 는 kotlin 영수증 검증 모듈이 생긴 뒤 별도 묶음.
   - 비밀번호 재설정: 앱이 있으면 앱, 없으면 웹 — App Links / Universal Links 로 한다(Firebase Dynamic Links 는 종료되어 쓰지 않는다). 링크 도메인 연결은 프로젝트 몫.

## 13. 인앱결제

서버 계약(정본): kotlin-skeleton `docs/superpowers/specs/2026-11-04-iap-design.md` · `docs/modules/payment-iap.md` · `auth-web-handoff.md` · `payment-http-contract.md` §12.1. 형 결정: 실물이 없으니 앱 결제는 인앱결제(IAP)가 기본이고, 앱 밖 웹 결제 링크는 서버의 지역 스위치가 켤 때만 보인다(기본 꺼짐). 웹으로 넘길 때는 서버가 주는 1회용 자동 로그인 링크를 바깥 브라우저로 연다.

### 13.1 목적 · 패키지 경계

- 새 패키지 `packages/iap`(`skeleton_iap`): `in_app_purchase` 로 상품 조회 · 구매 · 복원, 결과를 서버 검증 API 로 보내고, 서버가 `GRANTED` 를 준 뒤에만 `completePurchase`. 웹 결제 링크 발급과 바깥 브라우저 열기, 탈퇴 전 「스토어에서 해지하세요」 판정.
- `api_client` 만 안다. `auth` 를 import 하지 않는다(로그인 여부는 `push` 처럼 앱이 `iapSignedInProvider` 로 알린다). 패키지는 권한을 열지 않는다 — 결과 사건(`IapOutcome`)을 내보낼 뿐이고, 권한은 서버(`GET /subscriptions/me` · 주문)가 정본이다.
- 화면(상품 목록 · 구매 · 복원 · 내 구독 · 탈퇴 앞 안내)은 `apps/sample`(B1). `starter` 는 건드리지 않는다.

### 13.2 흐름

1. `GET /payments/iap/config?platform=&storefront=` → `channel` · `appAccountToken` · `products`. 상품 id 로 `queryProductDetails`.
2. 구매: `PurchaseParam.applicationUserName` = 서버가 준 `appAccountToken` 그대로(앱이 만들지 않는다). 서버 확인 전에 소비하지 않는다: iOS 는 플러그인이 `autoConsume: true` 를 강제하고 `completePurchase` 때 소비되며, Android 는 `autoConsume: false` 로 사고 서버가 지급(또는 영구 거절)한 뒤 `consumePurchase`(승인 겸함)를 직접 부른다. 단건 판정은 GRANTED 응답의 `kind`, 없으면 상품 지도. `config.store` 가 null 이면 팔지 않고, Android 구독은 `basePlanId` 가 지도와 맞는 제안만 보인다.
3. `purchaseStream`(iOS 는 앱 시작 때 남은 미완료 구매를 listen 때 준다. Android 는 주지 않아 `start()` 가 `queryPastPurchases` 로 미승인 구매만 읽어 같은 경로로 보낸다. 복원 포함)의 `purchased` · `restored` 는 모두 `POST /payments/iap/{store}/purchases`: appstore `{transactionId}` · googleplay `{productId, purchaseToken}`.
4. 응답 → 앱이 할 일(서버 계약 표 그대로):

| 응답 | 완료(`completePurchase`) | 권한 |
|---|---|---|
| `200 GRANTED` | 한다 | 서버가 연 것을 읽는다 |
| `202 PENDING` | 안 한다(기다림) | 없음 |
| `404 IAP_PURCHASE_NOT_FOUND` · `409 ALREADY_SUBSCRIBED` · `422 IAP_*` | 한다(영구 거절) | 없음 |
| `409 IAP_PURCHASE_OWNED_ELSEWHERE` | 안 한다(원래 계정이 다시 보낸다) | 없음 |
| `429` · `503` · 네트워크 · 그 밖 | 안 한다(다음 실행 · `retryUnfinished()` 에 다시) | 없음 |

5. 웹 결제: `config.channel` 이 `IAP_AND_WEB` · `WEB_ONLY` 일 때만 단추를 보인다. 누르면 `POST /payments/iap/web-checkout-link` → `{url}` → `url_launcher` `LaunchMode.externalApplication`(WebView 금지).
6. 탈퇴 전: `GET /payments/subscriptions/me` 의 `provider` 가 `appstore` · `googleplay` 이고 `status` 가 이용 중(`ACTIVE` · `CANCELING` · `PAST_DUE`)이면 「스토어에서 해지하세요」(서버는 스토어 구독을 끊지 못한다). 판정만 패키지가 하고 화면은 B1.

### 13.3 막을 진짜 문제

- 서버 확인 전 권한 열기 · 완료: `GRANTED` 외에는 완료하지 않고 `granted` 사건도 내지 않는다.
- 다른 계정 토큰: 토큰은 서버 `/config` 값만 쓴다(캐시한 값을 계정이 바뀐 뒤에 쓰지 않도록 로그인 상태가 바뀌면 서비스를 새로 만든다).
- 같은 구매의 중복 전송 · 중복 완료: 구매 키(`purchaseID`, 없으면 검증 데이터)로 진행 중 · 완료를 기억한다.
- 웹 링크의 1회용 코드가 로그 · 예외 메시지에 남는 것: 링크를 찍지 않고, 열기 실패는 링크 없는 고정 예외로 바꾼다.

### 13.4 시험

실제 스토어 호출 없음: `InAppPurchasePlatform` 을 가짜로 바꾸고 서버는 `FakeAdapter`. 새 회귀 시험은 돈 · 보안에만(서버 확인 전 완료 · 권한, 서버 토큰만 사용, 중복 완료, 링크 무노출). 서버 실물 시험은 B1 이후 kotlin `apps/sample` 에 대고 `--tags backend` 로 따로 둘 수 있다.

### 13.5 작업 목록

| 키 | 내용 |
|---|---|
| A1 | 이 절 |
| A2 | `packages/iap`: API · 서비스 · providers · 가짜 플랫폼 시험 · README |
| B1 | `apps/sample` 화면(상품 목록 · 구매 · 복원 · 내 구독 · 웹 결제 단추 · 탈퇴 앞 안내) · `capabilities.json` · `new-project --packages` 조합 |

### 13.6 확인 못 한 것

- 실제 App Store · Google Play 구매(Xcode · Android SDK · 스토어 계정 없음). `applicationUserName` 이 iOS 에서 `appAccountToken` 이 되는지는 실기기로 확인하지 못했다(안드로이드의 `setObfuscatedAccountId` 는 플러그인 소스 `MethodCallHandlerImpl.java` 로 확인됨).
- 스토어 나라(`storefront`)를 읽는 법. (요금제 거름과 Android 재수신은 소스로 확인해 코드에 넣었고, 실기기 동작은 못 봤다.)
- 소모성 · 비소모성 구분: 서버 계약에 없어 단건(`ONE_TIME`)은 소모성, 구독은 비소모성으로 둔다.

## 14. 소셜 로그인

앱은 네이티브 SDK 로 토큰을 받고, 서버가 그 토큰을 확인한 뒤에만 우리 세션을 준다(업계 관행). 설계 정본은 kotlin-skeleton `docs/superpowers/specs/2026-11-04-social-native-design.md` 의 「flutter 절」이다. 서버 계약은 같은 레포 `docs/account-http-contract.md`(`POST /auth/social/{provider}/token`, `GET /auth/methods` 의 `nativeToken`, 연결 · `socialReauth` 의 `idToken`/`accessToken`).

- 패키지 다섯: `social_login`(코어: `SocialCredential` · `SocialProvider` · nonce · `SocialAuthApi` · 컨트롤러 · `nativeToken` 으로 단추 거르기, 취소는 오류가 아니다) + 제공자별 `social_login_google` · `social_login_apple` · `social_login_kakao` · `social_login_naver`. 프로젝트는 쓰는 SDK 만 들인다(`--packages`).
- 애플은 iOS 앱에만 둔다(심사 4.8). 네이버는 SDK 액세스 토큰을 서버가 프로필 API 로 확인하는 관행을 따른다.
- `auth` 는 `social_login` 을 import 하지 않는다. 소셜 전용 계정의 탈퇴는 `deleteAccount` 가 앱이 넘긴 다시 인증 함수(`socialReauth`)를 부른다.
- 키는 `env/*.json` 과 git 밖 설정 파일(`Social.xcconfig` · `social.properties`)에 두고 레포에는 `.example` 만 둔다. 실제 SDK · 콘솔 · 실기기는 시험하지 못한다.
- 작업: F1 코어 · F2 `auth` 탈퇴 · F3 구글 · 애플 · F4 카카오 · 네이버 · F5 sample 화면 · 플랫폼 설정 · 카탈로그.

## 15. 알림함 · 푸시 연동 · 광고 알림

「광고」는 **광고성 알림(마케팅 푸시)과 그 수신 동의**로 읽었다(정보통신망법 §50 관행). 서버(kotlin-skeleton)에 알림함 · SSE · 광고 동의 · 야간 · 2년 재확인이 이미 있어 서버 작업은 없다(kotlin-skeleton 의 `docs/modules/notification*.md` · `legal.md` 가 계약).

- 범위: 알림 탭(배지 · 목록 · 쪽 넘김 · 당겨서 새로고침 · 안 읽음 · 묶인 수 · 모두 읽음) · 앞 창 실시간(SSE) · 푸시 탭 이동(`link` 없으면 알림 탭) · 설정 > 알림에 광고 수신 · 야간 수신 동의 · 철회 · 2년 재확인.
- 비목표: 앱 안 배너 · 전면 광고(AdMob), 광고를 보내는 화면, 「모든 채널 끄기」 화면, 푸시 클릭 열람 보고, 앱 아이콘 숫자 배지, 앞 창 시스템 알림, WebSocket(STOMP). 스타터에는 넣지 않는다.
- 패키지:

| id | 새/넓힘 | 하는 일 |
|---|---|---|
| `notifications` | 새 | `NotificationsApi` · `unreadCountProvider` · 목록 · `notificationsChanged` · `NotificationListView` · `UnreadBadge` · 안전 링크 · `notificationOpenProvider` |
| `realtime` | 새 | SSE 하나(`SseConnection`): Bearer · 토큰 갱신은 앱 `Dio` 를 탄다, 끊기면 다시 붙기 |
| `push` | 넓힘 | `pushFallbackLinkProvider`, `advertising.dart`(`AdvertisingApi` · `AdvertisingSettingsView`) |
| `legal` | 넓힘 | `LegalApi.withdraw(type)` |
| `apps/sample` | 넓힘 | 「알림」 탭 · `/notifications` · `/settings/notifications` · 잇기 |

- 정한 것: 경계는 `notifications` 가 `push` · `realtime` 을 모르고 `push` 가 `notifications` 를 모른다(앱이 잇는다). 푸시를 눌러도 읽음 처리하지 않는다(서버가 「눌러 연 것」과 「읽은 것」을 따로 센다). 읽음은 줄의 `eventId`. 계정이 바뀌면 목록 · 안 읽은 수가 새로 생기고 로그아웃이면 호출하지 않는다. 쪽 넘김은 줄 `id` 로 중복을 거른다. SSE 는 앞 창 + 로그인일 때만, 사건이 오면 숫자를 더하지 않고 서버에서 다시 읽는다, 404 면 그만 붙는다. 광고 동의는 문서를 보고 체크를 직접 켠 판으로만 기록한다(스위치 한 번 · 일괄 동의 없음). 앱 라우트는 웹과 같은 경로, `link` 는 `/` 로 시작하는 앱 안 경로만 따른다.
- 작업: F1 `notifications` · F2 `realtime` · F3 `legal.withdraw` + `push` 넓히기 · F4 `apps/sample` · 카탈로그.
