import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'board_api.dart';
import 'models.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `boardApiProvider.overrideWith((ref) => BoardApi(ref.watch(apiClientProvider)))`.
final boardApiProvider = Provider<BoardApi>(
  (ref) => throw UnimplementedError(
    'Override boardApiProvider with a BoardApi built on the app\'s ApiClient',
  ),
);

/// Gives the id of the author profile a post or comment is written as. Needed
/// only by servers whose config says `authorRequired` (the sample server has
/// `author-profile`). Null means the user has none to give; the widgets then
/// refuse to write.
typedef BoardAuthorResolver = Future<String?> Function();

/// Null (the default) is for servers without author profiles. When the server
/// requires an author and this is null, the write button, the editor and the
/// comment box are replaced by the reason.
final boardAuthorResolverProvider = Provider<BoardAuthorResolver?>(
  (ref) => null,
);

final boardConfigProvider = FutureProvider<BoardConfig>(
  (ref) => ref.watch(boardApiProvider).config(),
  retry: (_, _) => null,
);

/// Whether this app can write at all: false when the server wants an author id
/// and there is no resolver. Loading and a failed config read count as
/// "can write" so the widgets do not flash a wrong reason; the write itself
/// reports a real failure.
final boardCanWriteProvider = Provider<bool>((ref) {
  final config = ref.watch(boardConfigProvider).value;
  return !(config != null &&
      config.authorRequired &&
      ref.watch(boardAuthorResolverProvider) == null);
});

/// Pages loaded so far.
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.nextPage,
    required this.hasNext,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  factory PagedState.first(Page<T> page) => PagedState(
    items: page.items,
    nextPage: 1,
    hasNext: page.pagination.hasNext,
  );

  final List<T> items;
  final int nextPage;
  final bool hasNext;
  final bool loadingMore;
  final bool loadMoreFailed;

  PagedState<T> copyWith({
    List<T>? items,
    int? nextPage,
    bool? hasNext,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => PagedState(
    items: items ?? this.items,
    nextPage: nextPage ?? this.nextPage,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// First page on build, [loadMore] for the next ones. A failed next page keeps
/// what is on screen and shows a retry (`loadMoreFailed`).
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  Future<Page<T>> fetch(int page);

  @override
  Future<PagedState<T>> build() async => PagedState.first(await fetch(0));

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await fetch(current.nextPage);
      state = AsyncData(
        PagedState(
          items: [...current.items, ...page.items],
          nextPage: current.nextPage + 1,
          hasNext: page.pagination.hasNext,
        ),
      );
    } on ApiRequestError {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

class PostListNotifier extends PagedNotifier<PostSummary> {
  PostListNotifier(this.board);

  final String board;

  @override
  Future<Page<PostSummary>> fetch(int page) =>
      ref.read(boardApiProvider).posts(board, page: page);
}

/// The posts of a board, page by page. `ref.invalidate` it after a post was
/// written, edited or deleted (the widgets do).
final boardPostListProvider = AsyncNotifierProvider.autoDispose
    .family<PostListNotifier, PagedState<PostSummary>, String>(
      PostListNotifier.new,
      retry: (_, _) => null,
    );

typedef BoardPostRef = ({String board, int postId});

class PostNotifier extends AsyncNotifier<PostDetail> {
  PostNotifier(this.key);

  final BoardPostRef key;

  /// Reading counts a view on the server: this runs once per open screen, and
  /// reactions and comments never call it again.
  @override
  Future<PostDetail> build() =>
      ref.read(boardApiProvider).post(key.board, key.postId);

  void setReactions(ReactionState reactions) {
    final post = state.value;
    if (post != null) state = AsyncData(post.withReactions(reactions));
  }

  /// The edited post, as the server answered the edit.
  void replace(PostDetail saved) => state = AsyncData(saved);
}

final boardPostProvider = AsyncNotifierProvider.autoDispose
    .family<PostNotifier, PostDetail, BoardPostRef>(
      PostNotifier.new,
      retry: (_, _) => null,
    );

class CommentsNotifier extends PagedNotifier<Comment> {
  CommentsNotifier(this.key);

  final BoardPostRef key;

  @override
  Future<Page<Comment>> fetch(int page) =>
      ref.read(boardApiProvider).comments(key.board, key.postId, page: page);
}

/// The comment threads of a post. After a comment or a reaction,
/// `ref.invalidate` reads this part again and leaves the post alone.
final boardCommentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsNotifier, PagedState<Comment>, BoardPostRef>(
      CommentsNotifier.new,
      retry: (_, _) => null,
    );
