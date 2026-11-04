# flutter-skeleton — Claude Code 컨텍스트

Flutter 모바일 앱 스켈레톤. Pub Workspaces + Melos. 캡슐화된 패키지(`packages/`)와 스타터 앱(`apps/starter`)을 모아 두고, 프로젝트가 필요한 것만 골라 쓴다. 짝 백엔드는 kotlin-skeleton, 웹판은 react-skeleton(같은 id 의 패키지가 같은 일을 한다).

## 규칙

- **패키지 경계**: 서로를 `skeleton_<id>` 이름으로만 부르고 `package:x/src/...` 를 import 하지 않는다. 선언한 의존 = 실제 import. 린트(`implementation_imports` · `depend_on_referenced_packages`)가 막는다.
- **상태관리는 Riverpod 3(`flutter_riverpod`), provider 는 손으로 쓴다.** `riverpod_generator` · `build_runner` 는 쓰지 않는다. DTO 가 많은 패키지가 생기면 그 패키지에만 `json_serializable` 을 들인다.
- **workspace 목록(루트 `pubspec.yaml`)은 glob 을 못 받는다.** 패키지를 더하면 경로를 한 줄 적는다. 패키지 pubspec 에는 `resolution: workspace`.
- **의존은 캐럿(`^x.y.z`)으로 적고 `pubspec.lock` 을 커밋한다.**
- **SDK 버전은 루트 `environment.flutter` 한 곳.** CI 가 여기서 읽는다.
- **토큰은 로그에 남기지 않는다.** `Authorization` 을 찍지 않고, `TokenStore` 구현의 `toString` 에 값이 나오면 안 된다.
- **개발용 HTTP 허용은 디버그 빌드에만 둔다**(Android `src/debug`, iOS `NSAllowsLocalNetworking`). 릴리스에 들어가면 안 된다.
- **공개 레포다.** 개인 도메인 · 이메일 · 특정 서비스 이름을 코드 · 문서 · 커밋에 남기지 않는다. 예시 주소는 `example.com`.
- 기본값은 중립이다. 선택은 앱 설정(`env/*.json`, 앱 코드)에서 덮어쓴다.

## 명령

- 의존 해석: `flutter pub get` (루트)
- 분석 · 시험: 바뀐 패키지 폴더에서 `flutter analyze` · `flutter test`(`api_client` 는 `dart test`). 전체는 `melos run analyze` · `melos run test` 를 조각이 끝날 때 한 번.
- 포맷: `dart format .`

## 백엔드 계약

kotlin-skeleton `docs/account-http-contract.md`, `docs/modules/auth.md`, `docs/modules/auth-session.md` 가 정본이다. 패키지 README 에는 「어느 모듈 수준 계약을 겨냥하는지」만 적는다.

## 현재 범위

1단계(로그인 → 내 정보 → 로그아웃, 조용한 갱신). 가입 · 재설정 · 소셜 · 푸시 · 실시간 · 다국어 · 카탈로그 · `new-project.sh` 는 아직 없다.
