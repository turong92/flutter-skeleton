# skeleton_payment

Orders and the Toss payment window for the kotlin-skeleton payment modules
(`payment`, `payment-jdbc`, `payment-toss`).

## Read this before you ship

- **For physical goods and services used outside the app.** Digital goods sold
  and used inside the app (passes, items, creator support) must go through the
  store's in-app purchase (Apple 3.1.1, Google Play Billing). In-app purchase is
  not in this skeleton yet.
- The `cheer` item of the sample server is a demo borrowed from the kotlin
  sample. Shipped as it is, an app that sells it would be rejected in review.
- Card and bank app lists are native settings of the app (Android `<queries>`,
  iOS `LSApplicationQueriesSchemes`), not of this package. The sample app
  carries them (Toss's list).
- Payments here run on Toss **test keys** until the server holds live keys. The
  server tells (`config.testMode`); `PaymentGate` keeps a strip on while it is on.

## Parts

| Part | What it is |
|---|---|
| `PaymentApi` | `config`, `createOrder` (needs an `Idempotency-Key`), `confirm`, `order`, `myOrders` (cursor) |
| `purchase()` | order, window, confirm, asking again on `202 CONFIRMING`; returns a `PurchaseResult` |
| `TossCheckoutPage`, `showTossCheckout` | the window in a `flutter_inappwebview` WebView, loaded from a small HTML string with Toss's JS SDK v2 |
| `classifyCheckoutNavigation`, `intentToLaunch` | pure functions: what to do with each address the window is about to open |
| `PaymentGate` | `available: false` shows the unavailable text; `testMode` keeps the test strip |
| `OrderListView` | my payments, newest first |
| `PaymentResultView` | the words for a `PurchaseResult` (decline text by `data.category`) |
| `PaymentLabels` | every text; the package does not translate |

## Wiring

```dart
ProviderScope(overrides: [
  paymentApiProvider.overrideWith((ref) => PaymentApi(ref.watch(apiClientProvider))),
]);

final result = await purchase(
  api: ref.read(paymentApiProvider),
  itemType: 'cheer',
  itemRef: 'cheer-3000',
  launch: (checkout) => showTossCheckout(
    context,
    checkout,
    successUrl: Uri.parse('https://checkout.example.com/pay/success'),
    failUrl: Uri.parse('https://checkout.example.com/pay/fail'),
  ),
);
```

`successUrl` and `failUrl` are yours to choose. They are never opened: the
window is stopped on the way there and the values are read off the address.

## What it guards

- The amount sent to confirm is the amount of the server's order. A returned
  address whose order id or amount differs from the order is not confirmed.
- One `Idempotency-Key` per purchase. Pass `idempotencyKey:` to retry the same
  attempt; the server then answers with the same order.
- `202 CONFIRMING` is asked again with growing waits (`defaultPollSchedule`,
  five tries). After that the result is `PurchaseConfirming`: money may have
  moved, point the buyer to the payment history. A confirm that got no answer
  ends the same way, not as a failure.
- Closing the window is a cancel. The order stays `PENDING` and the server's
  expiry job closes it.
- `intent://` is turned into its app scheme (market address for the package as
  the fallback); other non-http schemes go to the system; `file:` and `content:`
  are dropped.
- Tokens and payment keys are never logged.

## Tests

```
flutter test --exclude-tags backend
API_BASE_URL=http://localhost:8080/api/v1 \
API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
flutter test --tags backend
```

The backend tests need a kotlin-skeleton `apps/sample` with Toss test keys; they
open no payment window.

## Not checked on a device

- That the payment window shows when the SDK page is loaded from a string
  (`loadHtmlString`-style) under the origin of `successUrl`, and that Toss accepts
  a return address that is never opened. If it does not, the page has to be served
  from a real address.
- That card and bank apps open from the WebView, and that Toss's warning about
  newer `webview_flutter_android` does not apply to `flutter_inappwebview`.
