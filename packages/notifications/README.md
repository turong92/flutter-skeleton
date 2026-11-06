# skeleton_notifications

The notification inbox for the kotlin-skeleton `notification` module: the list, the unread badge, read marks. Flutter + Riverpod 3. Web counterpart: react-skeleton `@skeleton/notifications`. Knows nothing of `auth`, `push` or `realtime`; the app joins them (a realtime event, a push that arrived in the foreground and the app coming back all call `notificationsChanged`).

The app overrides three providers:

```dart
notificationsApiProvider.overrideWith((ref) => NotificationsApi(ref.watch(apiClientProvider)))
notificationsAccountProvider.overrideWith((ref) => /* signed-in account id, or null */)
notificationOpenProvider.overrideWithValue((item) => router.go(item.safeLink ?? '/notifications'))
```

| Export | Meaning |
|---|---|
| `NotificationsApi` | `list(page:, size:, unreadOnly:)` · `unreadCount()` · `markRead(eventId)` · `markAllRead()`. Stores nothing. |
| `notificationsAccountProvider` | The signed-in account id. The list and the count are keyed by it: another account never sees the previous one's rows, and signed out (null) nothing is called. |
| `unreadCountProvider` | `AsyncValue<int>` from the server (a folded row counts once). |
| `notificationListProvider(account)` | Rows page by page; `loadMore()`; the same row (`id`) is never listed twice. |
| `notificationsChanged(ref)` | "Read it again": the count is read from the server (never `+1`: a folded row makes that wrong) and an open list reads its first page again. Takes a `Ref`, a `WidgetRef` or a `ProviderContainer`. |
| `NotificationListView(labels:)` | Pull to refresh, next page when the end is in view, unread dot, folded count, "mark all read", empty state. A tap marks the row read **by its `eventId`** (not by the id of an SSE event or push: they differ for a folded row) and calls `notificationOpenProvider`. |
| `UnreadBadge(child:)` | The count on a tab icon, `99+` above 99, none at 0. |
| `NotificationItem.safeLink` · `safeNotificationLink(raw)` | The `link` only when it is an app path (`/…`; not `//`, a scheme, `\` or control characters). Same rule as `skeleton_push`'s `safePushLink`. |
| `notificationOpenProvider` | Where a tapped row goes. Only the app's router knows; a row without a `link` (a board comment has only `payload.postId`) is joined to a path here. Default: nothing. |
| `NotificationsLabels` | Every text. The package does not translate; defaults are English. |

Notes
- A push tap does not mark the inbox row read: the server counts "opened from a push" and "read in the inbox" apart.
- Buttons and rows are outlined or filled even at rest.

Not here: realtime (`skeleton_realtime`), per-kind mute screen, app icon badge.

## Tests

```bash
cd packages/notifications && flutter test      # unit + widget (fake backend); backend test skips itself
```

**Backend contract test** (`test/backend/`, tag `backend`): list, unread count and "mark all read" against a real `apps/sample` (seed `user@example.com` / `password`). Runs only when `API_BASE_URL` is set:

```bash
API_BASE_URL=http://localhost:8080/api/v1 API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
  flutter test --tags backend test/backend
```

## Korean

English is the default. Korean (polite 해요 style, the same words as the web twin) is `NotificationsLabels.ko()`; the app picks it by the chosen language (see `skeleton_i18n`). `test/ko_labels_test.dart` checks that a Korean set names every field.
