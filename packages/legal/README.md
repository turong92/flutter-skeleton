# skeleton_legal

Legal documents and consents for the kotlin-skeleton `legal` module: the sign-up consent boxes, a document page, the re-consent screen and the `403 LEGAL.RECONSENT_REQUIRED` handling. Flutter + Riverpod 3. Web counterpart: react-skeleton `@skeleton/legal`. Knows nothing of the `auth` package (it only uses it in its tests); the starter joins them.

The app overrides one provider with the `ApiClient` it uses for everything:

```dart
legalApiProvider.overrideWith((ref) => LegalApi(ref.watch(apiClientProvider)))
```

| Export | Meaning |
|---|---|
| `LegalApi` | `documents()` · `document(type, version:, locale:)` (public) · `status()` · `agree(claims, source:)`. Stores nothing. |
| `SignUpConsents(onChanged:, locale:, labels:)` | One box per document required at sign-up, plus one per optional document, all unchecked. `onChanged(SignUpConsentsValue)`: `complete` (every required box checked; use it to enable submit) and `toJson()` (the sign-up request's `consents`: `type`, `version`, `locale` of what was shown). |
| `legalDocumentsProvider` | After a `400 LEGAL.CONSENT_REQUIRED`, `ref.invalidate(legalDocumentsProvider)`: a document whose version changed comes back unchecked. |
| `LegalDocumentPage(type:, version:, locale:)` | The markdown source as plain selectable text (no renderer yet). |
| `ReconsentInterceptor(onRequired:)` | Dio interceptor: a `403 LEGAL.RECONSENT_REQUIRED` calls `onRequired(missing)` and the error goes on to the caller. No sign-out, no refresh, the blocked call is not sent again. Add it to `client.dio.interceptors`. |
| `reconsentProvider` | `Reconsent` notifier, state `List<MissingConsent>` (empty = nothing to agree to). Wire: `ReconsentInterceptor(onRequired: ref.read(reconsentProvider.notifier).require)`. |
| `reconsentRedirect(ref)` · `reconsentRefreshListenable(ref)` · `reconsentRedirectFor(missing, uri)` | go_router: something missing sends every route to `/consent?from=<where>`; when it is done the consent route returns to `from` (an app path only, else `/`). Chain after the auth redirect: `authRedirect(c, s) ?? reconsentRedirect(ref)(c, s)`. |
| `ReconsentScreen(locale:, labels:)` | The `/consent` route: a box per missing document, one button that posts `POST /legal/consents` with `source: re-consent`. A newer version in between shows the new list; a refused version reads the status again. |
| `LegalLabels` | Every text. The package does not translate; defaults are English. |

Notes
- Clear `reconsentProvider` when the user signs out, or the next sign-in is sent to `/consent` first.
- A missing document without a `version` is not shown (nothing to agree to); the backend always names one for a document that exists.
- Buttons are outlined or filled even at rest; links are not bare text.

## Tests

```bash
cd packages/legal && flutter test      # unit + widget (fake backend); backend tests skip themselves
```

**Backend contract test** (`test/backend/`, tag `backend`): the document list, a sign-up without consents (`400 LEGAL.CONSENT_REQUIRED`), and agree/status for a seed account, against a real `apps/api`. Runs only when `API_BASE_URL` is set (start the starter as in `packages/auth/README.md`):

```bash
API_BASE_URL=http://localhost:8080/api/v1 API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
  flutter test --tags backend test/backend
```
