# skeleton_iap

In-app purchase (App Store / Google Play through `in_app_purchase`) for the kotlin-skeleton `payment-iap` + `payment-appstore` / `payment-googleplay` modules. The store sells, the server checks the purchase with the store, and only the server's answer opens anything. Contract: kotlin-skeleton `docs/modules/payment-iap.md`, `docs/payment-http-contract.md` §12.1, `docs/modules/auth-web-handoff.md`.

| Piece | What it is |
|---|---|
| `IapApi` | `config` · `confirmPurchase` · `webCheckoutLink` · `mySubscription` · `storeSubscriptionToCancel` |
| `IapService` | `loadCatalog` · `buy` · `restore` · `retryUnfinished` · `openWebCheckout` · `outcomes` |
| `iapServiceProvider` | One service per signed-in account; listens to the store's purchase stream from the moment it is watched |
| `iapCatalogProvider` | The server's products that the store lists, with the account token |
| `iapOutcomesProvider` | What the server said to each purchase: `IapGranted` · `IapRejected` · `IapNotConfirmed` · `IapStoreError` |
| `IapConfig.showsWebCheckout` | `channel` is `IAP_AND_WEB` or `WEB_ONLY`; show the web checkout button only then |
| `iapStoreSubscriptionToCancelProvider` | `appstore` / `googleplay` when a store subscription is still in use, else null |

## Wiring

The package does not import `auth`. It has no screens.

```dart
ProviderScope(overrides: [
  iapApiProvider.overrideWith((ref) => IapApi(ref.watch(apiClientProvider))),
  // true only once the session is restored
  iapSignedInProvider.overrideWith((ref) => ref.watch(sessionProvider) is SignedIn),
])
```

- Watch `iapServiceProvider` once at the app root. StoreKit hands over purchases left from the last run when someone listens, so listen early. Google Play does not: on Android `start()` reads the purchases that were never acknowledged (`queryPastPurchases`, no screen) and sends them like any other. The sample does not retry on app resume; call `retryUnfinished()` yourself if you want that.
- Products: `ref.watch(iapCatalogProvider)`, then `service.buy(offer)`. The result arrives on `iapOutcomesProvider`, not as a return value.
- Restore: `service.restore(catalog)`; the restored purchases go to the server like any other.
- After `IapGranted`, read the entitlement from the server (`mySubscription`, orders). The package opens nothing itself.

## What is guaranteed

- The account token in a purchase (`PurchaseParam.applicationUserName`, also on restore) is the `appAccountToken` of `GET /iap/config`. The app never makes one. A new service, so a new token, comes with every sign-in.
- `completePurchase` runs only after `200 GRANTED`, or after an answer that refuses the purchase for good (`404 IAP_PURCHASE_NOT_FOUND`, `409 ALREADY_SUBSCRIBED`, `422 IAP_PRODUCT_UNKNOWN` / `IAP_PURCHASE_REVOKED` / `IAP_PURCHASE_NOT_ELIGIBLE`). `202 PENDING`, `409 IAP_PURCHASE_OWNED_ELSEWHERE`, `429`, `503`, no network and any answer this table does not know leave it open, so it is sent again at the next start (StoreKit hands it back; on Android `start()` reads it as unacknowledged); `retryUnfinished()` sends the retryable ones again now.
- A one-time product is not consumed before the server has checked it. `ONE_TIME` is bought as consumable, a subscription as non-consumable (the contract does not tell them apart). On iOS the plugin requires `autoConsume: true` and consumes only at `completePurchase`. On Android it is `false`, and once the server granted the purchase (or refused it for good) the package calls `consumePurchase`, which also acknowledges it; without that the person could not buy the same product again. The kind comes from the `GRANTED` answer, else from the products of the last `loadCatalog()`.
- Nothing is for sale when `config.store` is null (the server has no store for this platform and would answer `503` to a paid purchase). On Google Play a subscription is offered only for the base plan the server maps (`basePlanId`); other plans of the same product are hidden.
- The same purchase is sent once and completed once, however often the stream delivers it.

## Web checkout

Only when `config.showsWebCheckout`. `service.openWebCheckout()` asks `POST /iap/web-checkout-link` for a one-time sign-in address and opens it with `LaunchMode.externalApplication` (the outside browser; never a web view). The address holds a sign-in code: it is not logged or stored, and a failure throws `IapWebLinkException` without it. Only `http` / `https` addresses are opened. In an `IAP_ONLY` channel the server answers `404` (`ApiRequestError`).

## Before deleting the account

The server cannot end a store subscription; deleting the account only ends the use on our side. Before the delete screen, `ref.watch(iapStoreSubscriptionToCancelProvider)`: `appstore` / `googleplay` means show "cancel the subscription in the store first". If the lookup fails, the app decides (the package does not guess).

## Not here

Refunds (the person asks the store), family sharing, offer codes, price changes, a screen. `storefront` is read from `InAppPurchase.countryCode()` and sent to the server as is.

## Tests

No store and no server: the store platform is a fake, the server a scripted `FakeAdapter`.

```
cd packages/iap && flutter test
```
