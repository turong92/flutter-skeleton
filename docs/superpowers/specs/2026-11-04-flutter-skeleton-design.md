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

## 결정됨 (2026-11-04, 형)

1. 상태관리: Riverpod 3 (손으로 쓴 provider, generator 없음).
2. 레포: 별도 공개 레포 `flutter-skeleton` (GitHub 공개 레포 생성까지 허락).
3. 카탈로그: flutter 쪽 `backend` 가 정본, kotlin 에는 `siblings.mobile` 한 줄만.
4. Flutter SDK: brew cask 로 설치, Melos 는 `dart pub global activate melos`.
