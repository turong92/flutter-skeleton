# 광고(AdMob) 패키지 — 설계

2026-11-09 · 상태: 구현됨(작업 1~4) · 기준 main 36fba00

## 목적

다른 앱이 `--packages ads` 로 골라 쓰는 Google AdMob 패키지 `skeleton_ads`(`packages/ads`, 카탈로그 id `ads`). 고르면 동의 확인 → SDK 시작 → 배너 한 칸이 끝에서 끝까지 돈다. 광고 단위 ID 의 기본은 구글 공식 시험 ID 이고, 실제 ID 는 앱이 `env/*.json` → `AppConfig`(dart-define)로 넣는다.

## 비목표 (이번에 안 한다)

- 전면 · 보상형 · 앱 오프닝 · 네이티브 광고, 미디에이션
- 광고 제거 구매(`iap` 연동), 로그인 · 등급별 광고 끄기
- 아동 대상 표시(`tagForChildDirectedTreatment` 등) · 광고 등급 상한 — 기본값은 SDK 그대로, 필요한 앱이 `RequestConfiguration` 을 직접 건다
- 시험 기기 등록 도우미, 빈도 조절, 노출 통계
- `app-ads.txt` 호스팅 · AdMob 콘솔 설정 · Play 「광고 포함」/데이터 보안 신고 — 코드가 아니라 README 체크리스트로만
- 백엔드 짝 없음(`backend: null`), react 짝 없음(`pairsWith.react: []`)
- `NSUserTrackingUsageDescription` 문구 현지화(InfoPlist.strings)

## 범위 — 무엇을 만드나

**패키지 `skeleton_ads`** (의존: `google_mobile_ads ^9.2.0`, `flutter_riverpod`. `api_client` · `auth` 를 부르지 않는다)

| 조각 | 하는 일 |
|---|---|
| `AdsSdk` (경계) | 배너 위젯 하나(`banner(context, unitId)` — 가짜는 빈 상자) · 동의 정보 갱신 · 필요 시 동의 폼 · `canRequestAds` · 개인정보 옵션 필요 여부/폼 · `MobileAds.initialize`. 기본 `GoogleAdsSdk`, 시험용 `FakeAdsSdk`(`package:skeleton_ads/testing.dart`) — `push` 의 `PushTokenSource` 와 같은 모양 |
| `adsControllerProvider` | 앱 루트에서 한 번 watch. 시작마다 UMP `requestConsentInfoUpdate` → `loadAndShowConsentFormIfRequired` → `canRequestAds` 가 참일 때만 `MobileAds.initialize`(한 번). 상태 `starting / ready / unavailable`. 갱신이 실패하면 SDK 가 쥔 지난 동의로 `canRequestAds` 를 읽는다(구글 안내대로) |
| `AdBanner` | 앵커 적응형 배너(구글이 권하는 기본 배너). `ready` 가 아니거나 로드 실패면 아무것도 그리지 않는다(빈 높이 0). 폭은 화면 폭으로 `AdSize.getLargeAnchoredAdaptiveBannerAdSize`(전자의 `getCurrentOrientation…` 는 9.x 에서 deprecated) |
| `AdsPrivacyOptionsButton` | `getPrivacyOptionsRequirementStatus() == required` 일 때만 보이고, 누르면 `showPrivacyOptionsForm`. 아니면 그리지 않는다 — EEA 등에서 구글 동의 정책이 요구하는 「동의 바꾸기」 입구 |
| `AdUnitIds.banner(android:, ios:)` | 플랫폼 값 고르기. **릴리스 빌드(`kReleaseMode`)이고 값이 있을 때만 실제 ID**, 그 밖(디버그 · 프로필 · 빈 값)은 구글 시험 ID(Android `…/9214589741`, iOS `…/2435281174`) |
| `AdsLabels` | 개인정보 옵션 버튼 문구 하나. 영어 기본 + `AdsLabels.ko()`(해요체) |

**네이티브 값 (앱 쪽 파일, 마커 `ads`)**

- Android `AndroidManifest.xml`: `com.google.android.gms.ads.APPLICATION_ID` meta-data = 시험 앱 ID `ca-app-pub-3940256099942544~3347511713`. 없으면 SDK 가 시작에서 앱을 죽이므로 `ads` 를 고르면 반드시 남는다.
- iOS `Info.plist` · `Info-Debug.plist`(둘 다): `GADApplicationIdentifier` = 시험 앱 ID `ca-app-pub-3940256099942544~1458002511`, `SKAdNetworkItems` = `cstr6suwn9.skadnetwork` 하나(google_mobile_ads 9.2.0 example 에 있는 값; 구글 빠른 시작의 긴 목록은 확인하지 못해 넣지 않았다 — 필요한 앱이 더한다). ATT 키는 「정해야 할 것」 1 에 따른다.
- `AD_ID` 권한은 SDK 가 manifest 병합으로 넣으므로 따로 적지 않는다. minSdk(flutter 기본) · iOS 15.0 은 SDK 요구(iOS 13+)를 이미 넘는다.

**붙이는 곳 (최소)**

- starter: `MeScreen` 아래쪽(`bottomNavigationBar` 칸, `SafeArea`)에 `AdBanner` 하나, `AccountScreen` 에 `AdsPrivacyOptionsButton` 하나, 루트에서 `adsControllerProvider` watch, `AppConfig.adsBannerAndroid` / `adsBannerIos`(`ADS_BANNER_ANDROID` · `ADS_BANNER_IOS`, 기본 빈 값). 모두 `// #if ads` 마커. 앱 문구가 없어 ARB 키는 만들지 않는다(버튼 문구는 `AdsLabels.ko()` 를 `context.byLocale` 로 고른다).
- sample: `shell_screen` 의 탭바 위에 `AdBanner` 하나, `settings_screen` 에 `AdsPrivacyOptionsButton`, 같은 네이티브 값.

## 확장 지점 (이것만 만든다)

- `AdsSdk` 교체 — 시험 가짜와 다른 SDK 구현을 위해. 이유: 플랫폼 뷰 광고는 `flutter test` 에서 못 띄우므로 경계가 있어야 starter · sample 위젯 시험이 돈다.
- 광고 단위 ID 를 위젯 인자로 받는다(`AdBanner(unitId: …)`). 이유: 앱마다 · 화면마다 단위가 달라 패키지가 provider 로 쥘 이유가 없다.
- 앱 ID 는 네이티브 파일의 한 줄을 앱이 바꾼다. 이유: 앱 ID 는 APK/IPA 에 그대로 들어가는 공개 값이라 social 처럼 gitignore 값 파일을 만들 이유가 없고, dart-define 을 Gradle/Xcode 에서 풀어 쓰는 건 관행이 아니다.

## 내 판단 (관행이 있어 묻지 않음)

- **UMP 동의는 넣는다.** 구글 EU 사용자 동의 정책상 EEA · 영국 · 스위스 트래픽에는 구글 인증 CMP 가 필수고, UMP 는 `google_mobile_ads` 에 들어 있다. 한국 사용자는 폼이 안 떠 비용이 없다.
- **실제 단위 ID 는 릴리스 빌드에서만 쓴다.** 개발 중 자기 실제 광고를 보고 누르는 것이 AdMob 계정 정지의 대표 원인이라, 막을 진짜 문제는 이것 하나로 본다. 실제 ID 를 디버그에서 꼭 봐야 하면 AdMob 콘솔의 시험 기기 등록을 쓴다(README).
- 광고는 로그인과 무관하게 보인다. 실패 · 미준비는 조용히 빈칸 — 오류 화면을 띄우지 않는다.

## 검증

- `packages/ads`: `flutter analyze` · `flutter test` — 가짜 SDK 로 ① 동의 갱신 → 폼 → `canRequestAds` 참이면 초기화 한 번, ② 거짓이면 초기화 안 하고 배너가 빈칸, ③ 갱신 실패 시 지난 동의로 판단, ④ 개인정보 버튼은 `required` 일 때만 보임, ⑤ `AdUnitIds` 가 디버그에서 실제 값을 무시, ⑥ `AdsLabels.ko()` 가 모든 필드를 채움.
- `dart tool/build_capabilities.dart --check` 통과(새 항목 · `app-sample.needs`).
- starter · sample: `flutter analyze` · `flutter test`(가짜 SDK override).
- `tool/test/stamp_test.dart` 「the real starter」: `ads` 를 고르면 manifest meta-data · plist 두 파일의 키 · pubspec 의존 · `AppConfig` 두 줄 가 남고, 안 고르면 모두 사라진다.
- `scripts/test-new-project.sh` 를 `--packages ads` 있음/없음 두 번(stamp 가 바뀌므로).
- 기기 확인은 여기서 못 한다(Android SDK · Xcode 없음): 실제 배너 표시, `DebugGeography.debugGeographyEea` 로 동의 폼과 개인정보 옵션 폼, iOS ATT 알림. 기기가 생기면 QA 로 넘긴다 — README 에 「확인 안 된 것」으로 적는다.

## 작업 목록

1. **`packages/ads` 패키지** — 위 표의 조각, `testing.dart`, README(배선 · 앱 ID 바꾸기 · 출시 체크리스트: 실제 앱 ID, `env/prod.json` 단위 ID, AdMob 콘솔 GDPR(+IDFA) 메시지, `app-ads.txt`, Play 광고 신고), 시험. 루트 `pubspec.yaml` workspace 한 줄, `CHANGELOG.md`.
2. **카탈로그** — `capabilities.json` 에 `ads`(`stampFlag: flag`, `needs: []`, `backend: null`, `notFor` 에 비목표), `app-sample.needs` 에 `ads`, `dart tool/build_capabilities.dart` 로 `docs/capabilities.md` · `llms.txt` 재생성. `AGENTS.md` 「현재 범위」 · 「starter 의 선택 화면」 목록에 `ads` 한 마디.
3. **starter + stamp** — 마커로 감싼 의존 · `AppConfig` · 루트 watch · `MeScreen` 배너 · `AccountScreen` 버튼 · AndroidManifest · `Info.plist` · `Info-Debug.plist`, starter 위젯 시험 override, `stamp_test` 기대 추가, `test-new-project.sh` 두 번.
4. **sample** — 의존, 탭바 위 배너, 설정의 개인정보 버튼, 네이티브 값(manifest · plist 두 개), 시험 override(ARB 키 없음).

## 다음에 넓힐 것

전면 · 보상형 광고(같은 `AdsSdk` 경계에 load/show 추가), 광고 제거 구매와 `iap` 연동, 앱 오프닝 광고, 네이티브 광고, 미디에이션, `NSUserTrackingUsageDescription` 한국어 문구.

## 정해야 할 것

1. **iOS 맞춤 광고(ATT) 를 켜 둘까** — 답에 따라 plist 키와 README 가 바뀐다.
   - (추천) 켠다: `Info.plist` · `Info-Debug.plist` 에 `NSUserTrackingUsageDescription`(영어 기본 문구)을 넣고, ATT 알림은 UMP 가 AdMob 콘솔의 IDFA 설명 메시지로 띄운다(별도 ATT 패키지 없음). AdMob 앱의 관행이고 iOS 수익이 크게 갈린다. 대신 앱이 콘솔에서 IDFA 메시지를 안 만들면 「키는 있는데 요청이 안 보인다」로 심사 반려될 수 있어 README 체크리스트에 굵게 적는다.
   - 끈다: 키를 넣지 않고 iOS 는 비맞춤 광고만. 심사 걱정은 없지만 콘솔에 IDFA 메시지를 만들면 앱이 문구 없이 ATT 를 불러 실패하므로, 켜려는 앱이 키를 직접 더해야 한다.
2. **1차 광고 형식** — 패키지 크기와 시험이 바뀐다.
   - (추천) 배너만: 끝에서 끝까지 도는 최소판. 전면 · 보상형은 같은 경계에 얹으면 된다.
   - 배너 + 전면: 화면 전환형 앱이 바로 쓴다. starter · sample 에 띄울 자리가 하나 더 필요하다.
   - 배너 + 전면 + 보상형: 흔한 3종 한 번에. 조각이 커져 리뷰 회차가 늘어난다.
