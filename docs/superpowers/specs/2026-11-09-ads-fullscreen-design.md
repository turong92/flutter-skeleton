# 광고 2차 — 전면 · 보상형 (+ 보상형 서버 확인) — 설계

2026-11-09 · 상태: 초안 · 기준 flutter main 7860bb0(1차 배너: [2026-11-09-ads-design.md](2026-11-09-ads-design.md)) · kotlin main a938f266

## 목적

`skeleton_ads` 의 같은 `AdsSdk` 경계에 **전면(interstitial)** 과 **보상형(rewarded)** 을 얹는다. 둘 다 미리 불러 두고, 전면은 빈도 제한으로 정책 위반을 막고, 보상형은 보상을 넘긴다. 보상을 서버 포인트로 줄 때는 클라이언트가 「줘」라고 부르는 길을 만들지 않고, AdMob 이 서버로 직접 보내는 **서버 측 확인(SSV) 콜백**만 포인트를 쌓게 한다 — 받는 쪽은 kotlin-skeleton 의 새 모듈 하나.

## 비목표

- 앱 오프닝 · 네이티브 · 보상형 전면(rewarded interstitial), 미디에이션
- SDK 의 미리 불러 두기 API(preloader) — 슬롯 하나를 직접 채운다
- 광고 제거 구매(`iap`), 하루 보상 상한 · 계정별 시청 횟수 제한(AdMob 콘솔의 빈도 제한으로), 노출 통계
- 보상 종류를 쿠폰 · 배지로 넓히기(`reward` 허리 경유) — 이번엔 포인트만
- kotlin `apps/sample` 에 새 모듈 붙이기, react 짝 · react 쪽 화면
- flutter 의 포인트 잔액 화면(flutter 에 points 패키지가 없다)
- **starter 에는 붙이지 않는다**(아래 내 판단)

## 범위 — flutter `skeleton_ads`

| 조각 | 하는 일 |
|---|---|
| `AdsSdk` 확장 | `loadInterstitial(unitId)` · `loadRewarded(unitId, {ssvUserId, ssvCustomData})` → 불러 둔 광고 하나(`show()` · `dispose()`; 보상형의 `show` 는 받은 보상 `AdReward{type, amount}` 또는 null). `FakeAdsSdk` 도 같이 늘려 불러오기 성공/실패 · 보상 있음/없음을 시험이 고른다 |
| `interstitialAdProvider(unitId)` | `ready` 가 된 뒤 하나를 미리 불러 둔다. `showIfAllowed()` → 보였으면 true. **빈도 제한**: 마지막으로 닫힌 때(처음엔 광고가 `ready` 된 때)부터 `minInterval`(기본 60초) 안이면 보이지 않는다 — 앱을 켜자마자 뜨는 전면도 같은 규칙으로 막힌다. 닫히거나 보여 주지 못하면 다음 것을 다시 불러 둔다. 불러 둔 게 없으면 그냥 false(기다리지 않는다) |
| `rewardedAdProvider(unitId, ssvUserId?)` | 미리 불러 두고 상태 `loading / ready / unavailable` 를 낸다 — 앱은 `ready` 일 때만 「광고 보고 ○○ 받기」 버튼을 켠다(보상형은 사람이 고를 때만 보여야 한다는 정책). `show()` → `AdReward?`. 보상은 SDK 의 `onUserEarnedReward` 로만 판정. `ssvUserId` 가 있으면 `ServerSideVerificationOptions(userId)` 를 실어 보낸다. 끝나면 다시 불러 둔다 |
| `AdUnitIds.interstitial` · `.rewarded` | 배너와 같은 규칙(릴리스 + 값 있음일 때만 실제). 시험 ID: 전면 Android `…/1033173712` · iOS `…/4411468910`, 보상형 Android `…/5224354917` · iOS `…/1712485313` |

- 패키지는 여전히 `auth` · `api_client` 를 모른다. `ssvUserId` 는 앱이 넘긴다(로그인한 `AccountMe.accountId`).
- README: 「서버 재화는 SSV 로만 준다. `onUserEarnedReward` 를 받고 서버에 적립을 부르는 API 를 만들지 마라(누구나 부를 수 있다)」, 전면을 두면 안 되는 곳(앱 시작 · 종료 시점, 내용이 뜨기 전, 매 동작마다), AdMob 콘솔 빈도 제한, 보상형 단위의 SSV 콜백 주소 설정.
- 카탈로그 `ads`: 요약 · `notFor` 갱신, `backend` 를 `null` 에서 `optionalModules: ["ads-admob"]` 로(SSV 를 쓸 때만).

## 범위 — kotlin `modules/ads-admob` (새 모듈, 최소)

AdMob SSV 콜백을 받아 확인하고 포인트를 쌓는다. 의존: `point`(`PointWallet`), `platform`.

- **경로** `GET /api/v1/ads/admob/ssv`(공개, 로그인 없음 — 결제 웹훅 수신과 같은 방식으로 익명 허용). 스위치 `skeleton.ads-admob.enabled`, 기본 꺼짐(꺼지면 404).
- **서명 확인**: 받은 쿼리 문자열을 고치지 않고 `&signature=` 앞까지 UTF-8 로, ECDSA-SHA256(DER, URL-safe base64) 을 `key_id` 의 공개키로 확인. 키는 `https://gstatic.com/admob/reward/verifier-keys.json` 에서 읽어 **24시간 넘게 쥐지 않고**, 모르는 `key_id` 면 한 번 다시 읽는다. 키 출처는 교체 지점(시험은 자기 키 쌍).
- **허용 광고 단위**: `skeleton.ads-admob.ad-units`(목록, 비면 모든 콜백 거절). 서명은 「구글이 보냈다」만 증명하므로, 남의 AdMob 계정 광고 단위가 이 주소를 콜백으로 지정해 포인트를 쌓는 것을 이 목록이 막는다.
- **적립**: `PointWallet.earn(user_id, reward_amount, 유효기간, "ADMOB_SSV", transaction_id)`. 유효기간은 `skeleton.ads-admob.expires-in-days`(기본 없음 = 안 사라짐, point 와 같은 규칙). 양은 콘솔에서 정해 서명된 `reward_amount` 그대로.
- **응답**: 적립 · 이미 적립(같은 `transaction_id` — 구글은 200 이 아니면 1초 간격 5번까지 다시 보낸다) → 200. 서명 불일치 · 허용 밖 단위 · `user_id` 없음/모르는 계정 → 400(지급 없음, 값은 로그에 남기지 않고 사유 코드만). 키를 못 읽음 · DB 오류 → 503.
- 모듈 문서 `docs/modules/ads-admob.md`, `docs/config/modules/ads-admob.yml`, `capabilities.json` 항목(`--modules ads-admob`, `autoIncludes: point`, 모바일 짝은 flutter `ads`), `CapabilitiesCatalogTest` · `ModuleDocumentationTest` 통과.

## 붙이는 곳 — sample 만

- 전면: 게시글 상세에서 목록으로 돌아올 때 `showIfAllowed()` 한 번(자연스러운 전환점).
- 보상형: 설정 화면에 「광고 보고 보상 받기」 버튼 하나(`ready` 일 때만 켜짐), 받으면 SnackBar. 로그인했으면 `ssvUserId` 를 싣는다. 문구는 ARB.
- 시험 단위는 SSV 콜백을 서버로 보내지 않으므로 sample 에서 포인트가 쌓이는 모습은 볼 수 없다 — 서버 쪽은 kotlin 시험과 AdMob 콘솔의 콜백 시험 도구로 본다.

## 내 판단 (관행이 있어 묻지 않음)

- **보상형 서버 재화에는 SSV 가 국룰**이다(구글이 클라 콜백만으로 재화를 주지 말라고 권하고, 서버에 「적립해 줘」 경로가 생기면 누구나 부른다). kotlin 에 `point` 가 이미 있으니 받는 쪽이 없으면 앱마다 위조 가능한 경로를 만들 것이다 → 이번에 최소 모듈로 넣는다(정해야 할 것 1).
- **`reward` 허리 대신 `PointWallet` 직접**: 광고 보상은 잦고 작은데 `reward` 는 지급마다 받은편지함 「받았어요」를 보내고 그 스위치(`skeleton.reward.notify.enabled`)가 이벤트 보상까지 함께 끈다. `PointWallet.earn` 은 `(sourceType, sourceRef)` 로 이미 멱등이라 `transaction_id` 중복이 공짜로 막힌다.
- **전면 빈도 제한 기본 60초, 앱 시작도 같은 시계**: 정책 필수(내용 흐름을 끊는 전면 · 시작 직후 전면 금지)를 한 규칙으로 막는다. 값은 앱이 `minInterval` 로 바꾼다. 콘솔 빈도 제한과 겹쳐도 해가 없다.
- **starter 에는 안 붙인다**: 전면 · 보상형의 자리는 제품이 정하는 것이라 스타터에 두면 모든 앱이 지울 코드가 된다. stamp · starter 시험도 그대로다.
- 보상형 버튼 위젯 · `AdsLabels` 문구는 만들지 않는다 — 보상 이름이 앱 것이라 버튼은 앱이 만든다.

## 검증

- `packages/ads` `flutter test`(가짜 SDK): 전면 ① `ready` 전엔 불러오지 않음 ② 시작 직후 · 닫힌 뒤 60초 안 `showIfAllowed` 는 false, 지나면 true ③ 닫힌 뒤 · 보여 주기 실패 뒤 다시 불러 둠 ④ 불러오기 실패면 false. 보상형 ⑤ 불러 둔 뒤에만 `ready` ⑥ 보상 콜백이 있을 때만 `AdReward`, 중간에 닫으면 null ⑦ `ssvUserId` 가 SDK 로 넘어감 ⑧ `AdUnitIds` 새 두 형식.
- `dart tool/build_capabilities.dart --check`(옆에 kotlin 클론이 있으면 `ads-admob` 이름도 맞춰 본다), sample `flutter analyze` · `flutter test`.
- kotlin `./gradlew :modules:ads-admob:test` — 시험 키 쌍으로 서명한 콜백: 맞는 서명 → 적립, 같은 `transaction_id` 두 번 → 한 번만 · 둘 다 200, 한 글자 바꾼 쿼리 · 다른 키 · 허용 밖 단위 · `user_id` 없음 → 400 · 적립 없음, 모르는 `key_id` → 키 다시 읽기 한 번, 키 24시간 지나면 다시 읽음, 꺼짐 → 404. 그리고 `:modules:platform:test`(카탈로그 · 문서 가드).
- 기기 · 실서버는 여기서 못 한다: 실제 전면 · 보상형 표시, 콘솔 콜백 시험 도구 → 배포된 서버. QA 로 넘기고 README · 모듈 문서에 「확인 안 된 것」으로 적는다.

## 작업 목록

1. **flutter `skeleton_ads` 전면 · 보상형** — `AdsSdk`/`GoogleAdsSdk`/`FakeAdsSdk` 확장, 두 provider, `AdUnitIds` 두 형식, 시험, README(정책 · SSV 안내), 카탈로그 `ads` 갱신 + 재생성, CHANGELOG.
2. **kotlin `modules/ads-admob`** — SSV 수신 · 서명 확인 · 허용 단위 · `PointWallet.earn`, 모듈 문서 · 설정 yml · 카탈로그 항목, 모듈 시험(kotlin 레포, 별도 커밋).
3. **flutter sample** — 전면 한 곳 · 보상형 버튼 한 곳, `AppConfig` 의 단위 ID 네 줄(`ADS_INTERSTITIAL_*` · `ADS_REWARDED_*`), ARB, 시험 override.

1 과 2 는 서로 기다리지 않는다(계약은 이 문서의 경로 · 쿼리 · `user_id` = 계정 id).

## 다음에 넓힐 것

`reward` 허리 경유(쿠폰 · 배지 보상, 지급 알림 선택), 하루 보상 상한, 앱 오프닝 광고, 광고 제거 구매, kotlin `apps/sample` 에 `ads-admob` 연결, flutter 포인트 잔액 화면.

## 정해야 할 것

1. **kotlin SSV 받는 쪽을 이번에 만들까** — 조각이 하나 더(kotlin 레포) 생기는지가 갈린다.
   - (추천) 이번에 만든다: 보상형을 서버 포인트로 쓰는 앱이 생기면 바로 안전하게 쓸 수 있고, 위조 가능한 「적립해 줘」 경로가 앱마다 생기는 걸 미리 막는다.
   - 미룬다: 이번엔 flutter 만(보상은 앱 안의 비재화 — 기능 잠금 해제 같은 것). README 에 「서버 재화는 SSV 가 생길 때까지 쓰지 마라」라고 적고, 서버 포인트가 필요한 앱이 생길 때 만든다.
