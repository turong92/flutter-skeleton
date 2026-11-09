# flutter-skeleton — 에이전트 지침

Flutter 모바일 앱 스켈레톤. Pub Workspaces + Melos. 캡슐화된 패키지(`packages/`)와 스타터 앱(`apps/starter`)과 참조 앱(`apps/sample`, 찍을 때 빠진다)을 모아 두고, 프로젝트가 필요한 것만 골라 쓴다. 짝 백엔드는 kotlin-skeleton, 웹판은 react-skeleton(같은 id 의 패키지가 같은 일을 한다).

## 규칙

- **패키지 경계**: 서로를 `skeleton_<id>` 이름으로만 부르고 `package:x/src/...` 를 import 하지 않는다. 선언한 의존 = 실제 import. 린트(`implementation_imports` · `depend_on_referenced_packages`)가 막는다.
- **상태관리는 Riverpod 3(`flutter_riverpod`), provider 는 손으로 쓴다.** `riverpod_generator` · `build_runner` 는 쓰지 않는다. DTO 가 많은 패키지가 생기면 그 패키지에만 `json_serializable` 을 들인다.
- **workspace 목록(루트 `pubspec.yaml`)은 glob 을 못 받는다.** 패키지를 더하면 경로를 한 줄 적는다. 패키지 pubspec 에는 `resolution: workspace`.
- **의존은 캐럿(`^x.y.z`)으로 적고 `pubspec.lock` 을 커밋한다.**
- **SDK 버전은 루트 `environment.flutter` 한 곳.** CI 가 여기서 읽는다.
- **토큰은 로그에 남기지 않는다.** `Authorization` 을 찍지 않고, `TokenStore` 구현의 `toString` 에 값이 나오면 안 된다.
- **개발용 HTTP 허용은 디버그 빌드에만 둔다**(Android `src/debug`, iOS `NSAllowsLocalNetworking`). 릴리스에 들어가면 안 된다.
- iOS Debug 설정은 `Runner/Info-Debug.plist`(= `Info.plist` + ATS 예외)를 쓴다. 한쪽을 고치면 다른 쪽도 고친다.
- **공개 레포다.** 개인 도메인 · 이메일 · 특정 서비스 이름을 코드 · 문서 · 커밋에 남기지 않는다. 예시 주소는 `example.com`.
- 기본값은 중립이다. 선택은 앱 설정(`env/*.json`, 앱 코드)에서 덮어쓴다.

## 명령

- 의존 해석: `flutter pub get` (루트)
- 분석 · 시험: 바뀐 패키지 폴더에서 `flutter analyze` · `flutter test`(`api_client` 는 `dart test`). 전체는 `melos run analyze` · `melos run test` 를 조각이 끝날 때 한 번.
- 포맷: `dart format .`

## 백엔드 계약

kotlin-skeleton `docs/account-http-contract.md`, `docs/modules/auth.md`, `docs/modules/auth-session.md` 가 정본이다. 패키지 README 에는 「어느 모듈 수준 계약을 겨냥하는지」만 적는다.

## 현재 범위

1~2단계(로그인 → 내 정보 → 로그아웃, 조용한 갱신) + 카탈로그 + `new-project.sh`. 3단계: 가입 · 메일 인증 · 비밀번호 재설정 · 탈퇴(`auth`), 약관 동의와 재동의(`legal`, 스타터가 쓴다), 게시판(`board`) · 푸시(`push`, 광고성 푸시 수신 동의 `skeleton_push/advertising.dart` 포함) · 알림함(`notifications`) · 실시간 SSE(`realtime`, 앞 창 + 로그인일 때만 연결)(모두 `--packages` 로 고른다), 이들을 연결해 보여 주는 참조 앱 `apps/sample`(찍을 때 늘 지워진다). 소셜 로그인(`social-login` 코어 + `social-login-google|apple|kakao|naver`, `--packages` 로 고른다): 제공자 앱 SDK 의 토큰을 kotlin `auth-social` 이 확인한 뒤에만 세션을 연다. 값 파일(`apps/sample/ios/Flutter/Social.xcconfig` · `android/social.properties`)은 gitignore 이고 `.example` 만 커밋한다. 다국어(한/영): 문구는 앱의 ARB(`lib/l10n/app_ko.arb` 템플릿 · `app_en.arb`, gen_l10n — 생성 파일은 `flutter pub get` 이 만들고 gitignore) 이고, 패키지는 `*Labels`(영어 기본)로 문구를 받는다. `auth` · `push` · `notifications` · `board` · `legal` · `storage` 는 한국어 묶음 `XxxLabels.ko()`(해요체, react 와 같은 말)를 더 낸다. 언어 고르기(고른 것 → 기기 언어 → `ko`, 기기에만 저장)와 언어 메뉴는 `i18n`(`--packages i18n`). 실시간은 알림 SSE 하나뿐, WebSocket 없음.

결제: 인앱결제(`iap`, `--packages` 로 고른다) — 스토어 구매를 kotlin `payment-iap` 이 검증한 뒤에만 권한이 열린다. 앱 밖 웹 결제는 서버 지역 스위치가 켤 때만 1회용 링크를 바깥 브라우저로 연다(기본 꺼짐). 앱 안 WebView 결제는 두지 않는다. Firebase 설정 파일(`google-services.json` · `GoogleService-Info.plist`)은 gitignore 이고 프로젝트가 갖는다.

## 카탈로그

- `capabilities.json` 이 정본이고 `docs/capabilities.md` · `llms.txt` 는 거기서 만든다: `dart tool/build_capabilities.dart`(쓰고 검사) · `--check`(CI). 패키지나 앱을 더하면 항목을 붙인다(안 붙이면 검사가 막는다).
- 백엔드 짝은 이 카탈로그의 `backend` 가 정본이다(kotlin 쪽에는 `siblings.mobile` 한 줄뿐). 옆에 `../kotlin-skeleton` · `../react-skeleton` 이 클론돼 있으면 모듈 이름 · 문서 경로 · `pairsWith.react` id 를 읽어 맞춰 본다(옆 레포는 고치지 않는다).
- `tool/` 은 워크스페이스 패키지(`skeleton_tool`)라 `melos run test` 가 시험도 돌린다.

## new-project

- `scripts/new-project.sh` 가 순서를 정하고 문자열 작업은 `tool/new_project/stamp.dart`. **바꿀 문자열이나 파일을 못 찾으면 조용히 넘기지 않고 멈춘다** — 스타터의 android/ios 파일을 고치면 stamp.dart 의 바꾸는 목록도 같이 본다.
- **starter 의 선택 화면**: `apps/starter` 는 board · storage(사진 칸) · push · notifications · realtime · iap · i18n(언어 저장 · 메뉴) · social-login*(로그인 화면 버튼 · 계정 삭제 증명 · 네이티브 설정) 의 기본 화면을 전부 갖고 있고(분석 · 시험이 다 덮는다), stamp 가 `--packages` 로 고르지 않은 것을 지운다. 그 패키지 것은 마커 줄(`// #if board storage` … `// #endif`, yaml `# #if`, xml `<!-- #if -->`, 파일 통째는 첫 줄 `// #file board`)로 감싼다. 규칙: 중첩 금지, 「고르지 않음」 조건 없음(스켈레톤에서는 모든 블록이 함께 컴파일돼야 한다), id 는 카탈로그 id(소문자, 폴더 이름의 `_` 를 `-` 로, 예 `social-login`)이고 `a|b` 는 둘 중 하나. 마커의 id 가 패키지가 아니거나 열림/닫힘이 안 맞으면 stamp 가 멈춘다. 블록을 지운 뒤 빈 줄은 `dart format` 과 같게 정리된다. ARB 는 주석이 없어서 키의 메타에 `"@key": {"x-feature": "board"}` 로 id 를 적는다(같은 규칙, gen_l10n 은 무시) — stamp 가 고르지 않은 패키지의 키를 ko · en 둘 다에서 지운다. starter 에 화면을 더하면 마커로 감싸고 `tool/test/stamp_test.dart` 의 「the real starter」 시험에 기대를 더한다.
- 패키지를 더하면 `stampFlag.included`(스타터가 쓰면 `always`, 아니면 `flag` + `--packages <id>`)를 맞춘다. 검사가 어긋남을 막는다.
- 확인: `scripts/test-new-project.sh`(몇 분, 네트워크). 바뀐 파일이 stamp 와 관계없으면 돌리지 않는다.
