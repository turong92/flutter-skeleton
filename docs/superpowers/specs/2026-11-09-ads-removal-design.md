# 광고 3차 — 광고 제거 구매 — 설계

2026-11-09 · 상태: 초안 · 기준 flutter main f4dad8c · kotlin main 57fdecb3 · 앞 단계: [1차 배너](2026-11-09-ads-design.md) · [2차 전면 · 보상형](2026-11-09-ads-fullscreen-design.md)

## 목적

「광고 제거」를 **비소모성 1회 구매**로 판다. 사는 길은 기존 `skeleton_iap` → kotlin `payment-iap`(+ `-appstore` / `-googleplay`) 그대로이고, 광고는 **서버가 확인한 권리(entitlement)** 가 있을 때만 꺼진다. 권리는 계정에 붙으므로 다른 기기 · 재설치에서는 로그인만 하면 유지되고, 스토어 복원(restore)은 기존 구매 확인 경로로 같은 권리에 닿는다. `skeleton_ads` 는 `skeleton_iap` 를 모른다 — 앱이 「광고 꺼짐」 한 값을 override 로 넘긴다.

## 지금 레포에 없는 것 (그래서 만드는 것)

- **비소모성 구분이 없다.** `skeleton_iap` 는 `ONE_TIME` 을 소모성으로 사고 Android 에서 지급 뒤 `consumePurchase` 한다(계약이 둘을 가르지 않아서). 광고 제거를 이렇게 사면 Play 구매가 소모돼 같은 상품을 **또 살 수 있고**(이중 결제) 스토어 복원에도 안 나온다.
- **단건 권리 조회가 없다.** kotlin 의 권리는 앱의 `PaymentOrderListener.onPaid` 몫이고, 사용자 경로는 내 결제 내역(`GET /orders`, 쪽매김) · 구독(`/subscriptions/me`)뿐이다.

## 비목표

- 광고 제거를 웹 결제(토스)로 팔기, 구독형 광고 제거, 기간제 제거
- 계정 없이(로그인 전) 사기 · 기기에만 붙는 권리 — 기존 iap 처럼 로그인한 계정에만 붙는다(다른 계정으로 복원하면 기존 규칙대로 `409 OWNED_ELSEWHERE`)
- 보상형 광고 끄기 — 사람이 골라 보는 광고라 그대로 둔다(내 판단)
- 권리의 기기 캐시(오프라인에서도 꺼짐 유지), 가족 공유(기존 iap 가 거절)
- sample 앱 · kotlin `apps/sample` 상품 지도 연결, react 쪽
- `PaymentOrderListener` 로 앱 표에 권리를 따로 쓰는 방식 — 주문 장부에서 바로 읽는다

## 범위 — kotlin (`payment-iap` + 장부 조회 한 개)

- **상품 지도 한 칸** `consumable`(단건 줄에만, 기본 `true` = 지금 동작). `GET /config` 의 `products[]` 에 `consumable` 이 실린다. 구독 줄에 적으면 기동 실패.
- **`GET /api/v1/payments/iap/entitlements`**(로그인, `payment-iap` 가 켜졌을 때만) → `{ values: [{ itemType, itemRef }] }` = 상품 지도의 `consumable: false` 줄 가운데 **부른 계정에게 `status = PAID` 인 `ONE_TIME` 주문이 있는 것**. 결제사는 가리지 않는다(같은 품목이면 어디서 샀든). 환불이 하나라도 확정되면(`PARTIALLY_REFUNDED` · `REFUNDED`) 권리가 없다 — 스토어 환불 알림(애플 `REFUND`, 구글 `voidedPurchaseNotification`)이 이미 장부를 그렇게 바꾸므로 회수는 따로 만들지 않는다. 탈퇴로 지워진 주문은 당연히 빠진다.
- 장부 포트 한 메서드(예: `PaymentLedgerStore.paidItems(accountId, items)`) — `payment-jdbc`(PostgreSQL · MySQL) 구현과 시험용 메모리 장부.
- `docs/modules/payment-iap.md` · `docs/payment-http-contract.md`(§ iap) · `docs/config/modules/payment-iap.yml` 예시에 광고 제거 줄 하나(`item-type: ads-removal`, `consumable: false` — 예시일 뿐 기본값 아님).

## 범위 — flutter

**`skeleton_iap`**
- `IapProduct.consumable`(없으면 `true`). `consumable: false` 인 단건은 `buyNonConsumable` 로 사고, Android 에서 **소모하지 않는다**(승인 통지는 서버의 `afterGrant` 가 이미 한다). 복원 · 시작 때 남은 구매 재전송은 기존 그대로.
- `iapEntitlementsProvider` — `GET /iap/entitlements`, 계정(세션)마다 하나, `IapGranted` 뒤 다시 읽는다. `IapEntitlements.owns(itemType, itemRef)`.

**`skeleton_ads`**
- `adsRemovedProvider`(`Provider<bool>`, 기본 `false`) 하나. 참이면 `AdBanner` 는 그리지 않고, 전면은 미리 불러 두지도 보이지도 않는다(`showIfAllowed` → false). 보상형 · 동의 흐름 · 개인정보 옵션 버튼은 그대로(동의는 보상형에도 필요하고, 정책상 동의 바꾸기 입구는 남아야 한다).

**starter** (`ads` 와 `iap` 를 둘 다 골랐을 때만 — 마커 `// #if ads iap`)
- `AppConfig.adsRemovalItemType` / `adsRemovalItemRef`(`ADS_REMOVAL_ITEM_TYPE` · `ADS_REMOVAL_ITEM_REF`, 비면 기능 꺼짐).
- 루트 override: `adsRemovedProvider` = 로그인했고 권리에 그 품목이 있음. **권리를 읽는 동안은 참**(산 사람에게 시작마다 광고가 번쩍 뜨지 않게), 읽기 실패는 거짓.
- 상점 화면(`#if iap`): 권리가 있는 비소모성 상품은 구매 버튼 대신 「구매함」(starter ARB, `x-feature: iap`). 복원 버튼은 이미 있다.
- `stamp_test` 「the real starter」 기대: `ads,iap` 이면 남고 하나만 고르면 빠진다.

## 내 판단 (관행이 있어 묻지 않음)

- **권리는 주문 장부에서 읽는다**: 스토어 확인 · 환불 회수 · 이중 지급 방지가 이미 장부에 있어, 권리 표를 따로 두면 같은 사실을 두 곳에 쓰게 된다. 비소모성이라는 사실은 Google 이 구매 정보로 알려 주지 않으므로 상품 지도의 한 칸이 정본이다.
- **보상형은 광고 제거 뒤에도 남긴다**: 광고 제거 구매는 강제로 보이는 광고(배너 · 전면)를 끄는 것이 관행이고, 보상형은 사람이 보상을 위해 고르는 것이다.
- **권리를 읽는 동안 광고를 끈다**: 산 사람이 시작마다 광고를 보는 게 실제 불만거리다. 안 산 사람에게는 광고가 요청 한 번만큼 늦게 뜰 뿐이다.
- **완전 환불이 아니어도 환불이 있으면 권리를 없앤다**: 비소모성 하나에 부분 환불은 드물고, 애플은 환불 때 접근을 회수(revocation)하는 모델이라 같게 둔다.
- **starter 에만 붙인다**: starter 는 이미 상점 화면과 배너를 둘 다 갖고 있다. sample 은 서버 상품 지도까지 바꿔야 보여서 다음으로 미룬다.

## 검증

- kotlin `./gradlew :modules:payment-iap:test` · `:modules:payment-jdbc:test`(두 DB) · `:modules:platform:test`: `PAID` 주문 → 목록에 있음 · 부분/전체 환불 → 없음 · `consumable: true` 줄은 절대 없음 · 다른 계정 주문 → 없음 · 다른 결제사로 산 같은 품목 → 있음 · 꺼짐 → 경로 없음 · 구독 줄에 `consumable` → 기동 실패 · `/config` 에 `consumable` 실림.
- flutter `packages/iap` `flutter test`(가짜 스토어 + `FakeAdapter`): 비소모성 → `buyNonConsumable`, `GRANTED` 뒤 `completePurchase` 만 · `consumePurchase` 없음, 소모성은 지금처럼 소모, 복원 → 서버로 보냄 → 권리 다시 읽음, 계정이 바뀌면 권리도 새로.
- `packages/ads` `flutter test`: `adsRemovedProvider` 참이면 배너 빈칸 · 전면 불러오기 없음 · `showIfAllowed` false, 보상형은 그대로.
- starter `flutter analyze` · `flutter test`(읽는 중 → 광고 없음, 권리 있음 → 없음, 실패 → 있음, 상점의 「구매함」), `dart tool/build_capabilities.dart --check`, `scripts/test-new-project.sh` 를 `--packages ads,iap` · `--packages ads` 두 번.
- 실기기 · 실스토어는 못 한다(Play Console · Xcode 없음): 실제 구매 · 복원 · 재설치 · 다른 기기. README 에 「확인 안 된 것」으로 적는다.

## 작업 목록

1. **kotlin `payment-iap` 권리 조회** — 상품 지도 `consumable`, `/config` 칸, `GET /iap/entitlements`, 장부 포트 메서드(`payment-jdbc` 두 방언 + 메모리), 문서 · 계약 · yml · 시험(kotlin 레포, 별도 커밋).
2. **flutter `skeleton_iap` 비소모성 + 권리** — `consumable` 읽기, 비소모성 구매 · Android 소모 안 함, `iapEntitlementsProvider`, 시험, README, CHANGELOG.
3. **flutter `skeleton_ads` 끄기 신호** — `adsRemovedProvider` 와 배너 · 전면 반영, 시험, README, 카탈로그 `ads` · `iap` 요약 / `notFor` 갱신과 재생성.
4. **starter 연결** — `#if ads iap` 블록(AppConfig · 루트 override), 상점의 「구매함」, ARB, 위젯 시험, `stamp_test`, `test-new-project.sh` 두 번.

1 은 2~4 와 나란히 간다(계약: 위 경로와 `consumable` 칸). 3 은 2 를 기다리지 않는다. 4 는 2 · 3 뒤.

## 다음에 넓힐 것

sample 연결(kotlin `apps/sample` 상품 지도에 광고 제거 줄), 권리의 기기 캐시, 웹 결제로 광고 제거 팔기, 다른 비소모성 상품(테마 · 기능 잠금 해제)에 같은 권리 조회 쓰기.

## 정해야 할 것

없음 — 남은 선택(보상형 유지, 읽는 동안 끄기, 부분 환불 처리, starter 만)은 관행대로 「내 판단」에 적었다.
