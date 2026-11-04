# skeleton_board

Board posts, reactions and comment threads for the kotlin-skeleton `board` module (`board` + `board-jdbc`; optional `author-profile` and `idempotency`). Flutter + Riverpod 3. Web counterpart: react-skeleton `@skeleton/board`. Knows nothing of the `auth` package: the app gives it the `ApiClient` it signs in with.

```dart
boardApiProvider.overrideWith((ref) => BoardApi(ref.watch(apiClientProvider))),
// only for servers with `authorRequired` (the sample server has author profiles):
boardAuthorResolverProvider.overrideWithValue(() async => firstProfileId),
```

| Export | Meaning |
|---|---|
| `BoardApi` | `config` · `posts(board, page:)` · `post` · `createPost` · `updatePost` · `deletePost` · `comments` (replies nested) · `createComment` · `deleteComment` · `reactToPost` / `removePostReaction` / `reactToComment` / `removeCommentReaction`. The board code is a parameter. `createPost` and `createComment` need an `idempotencyKey` (`newIdempotencyKey()` from `skeleton_api_client`). Stores nothing. |
| `PostListView(board:, onOpen:, onCompose:)` | Pull down to read again, the next page loads when the end comes into view. `onCompose` null: no write button. |
| `PostDetailView(board:, postId:, onEdit:, onDeleted:, reactionStyles:)` | Plain-text body, reaction buttons, comment threads, the comment box. Edit and delete show only when the server says `mine` (never compare account ids: with author profiles they differ). |
| `PostEditor(board:, post:, onSaved:)` | Write (`post` null) or edit. Title, body and comment lengths come from `GET /boards/config`. |
| `boardAuthorResolverProvider` | `Future<String?> Function()?`, null by default. When the server config says `authorRequired` and it is null, the write button, the editor and the comment box are replaced by the reason (`labels.authorMissing`); the list and the detail still work. |
| `BoardReactionStyle` · `defaultBoardReactionStyles` | Label and icon per reaction type code (`LIKE`, `DISLIKE`, `EMPATHY`). A type that is not in the map shows its code. Pass your own map to `PostDetailView`. |
| `BoardLabels` | Every text; defaults are English. |
| `boardPostListProvider(board)` · `boardPostProvider((board:, postId:))` · `boardCommentsProvider((board:, postId:))` | The read state. `ref.invalidate` one of them to read only that part again. |

What it guards
- Opening a post counts a view on the server, so the post is read once. A reaction on the post puts the server's answer in place; a comment, a reply or a reaction on a comment reads only the comment list again.
- One submit is one `Idempotency-Key`; the button is locked while it is out. A retry of the same text sends the same key (one post even if the first request got through); changed text takes a new one.
- A deleted or hidden comment has `body: null`; it keeps its place with a line saying why, so the thread keeps its shape. A comment at `maxCommentDepth` has no reply button.
- `403 ACCOUNT.EMAIL_REQUIRED` and `ACCOUNT.LOGIN_ID_REQUIRED` (gates of the sample server) show their own sentences (`labels.emailRequired`, `labels.loginIdRequired`). The screens that fix them are the app's.
- Buttons are outlined or filled even at rest.

Not here (kept out on purpose): guest posts, attachments and photos, moderation (hide, pin, approve), search and sort, drafts, picking an author profile.

## Tests

```bash
cd packages/board && flutter test      # unit + widget (fake backend); backend test skips itself
```

**Backend contract test** (`test/backend/`, tag `backend`): config, list, a post written twice with the same key (one post), edit, comment and reply, reactions, a deleted comment keeping its place, delete, against a real `apps/sample` (local profile, seed `user@example.com` / `password`, board `general`). Runs only when `API_BASE_URL` is set:

```bash
API_BASE_URL=http://localhost:8080/api/v1 API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
  flutter test --tags backend test/backend
```
