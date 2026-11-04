/// `ApiError.code` values the board screens branch on. The first two come from
/// the `account` module's gates (the sample server turns them on); the rest
/// are `BoardErrorCode`.
abstract final class BoardErrorCodes {
  static const emailRequired = 'ACCOUNT.EMAIL_REQUIRED';
  static const loginIdRequired = 'ACCOUNT.LOGIN_ID_REQUIRED';
  static const commentTooDeep = 'BOARD.COMMENT_TOO_DEEP';
  static const postNotCommentable = 'BOARD.POST_NOT_COMMENTABLE';
}

/// `GET /boards/config`: what the screens need to know about the server.
class BoardConfig {
  const BoardConfig({
    required this.reactionTypes,
    required this.maxCommentDepth,
    required this.titleMaxLength,
    required this.bodyMaxLength,
    required this.commentMaxLength,
    required this.maxPageSize,
    required this.authorRequired,
  });

  factory BoardConfig.fromJson(Map<String, Object?> json) => BoardConfig(
    reactionTypes: [
      for (final t in json['reactionTypes']! as List) t as String,
    ],
    maxCommentDepth: json['maxCommentDepth']! as int,
    titleMaxLength: json['titleMaxLength']! as int,
    bodyMaxLength: json['bodyMaxLength']! as int,
    commentMaxLength: json['commentMaxLength']! as int,
    maxPageSize: json['maxPageSize']! as int,
    authorRequired: json['authorRequired']! as bool,
  );

  final List<String> reactionTypes;

  /// A reply is refused (422) below this depth: a comment at this depth has no
  /// reply button. Top-level comments are depth 0.
  final int maxCommentDepth;
  final int titleMaxLength;
  final int bodyMaxLength;
  final int commentMaxLength;
  final int maxPageSize;

  /// When true a post or comment needs an `authorId` (an author profile id)
  /// that the app has to supply: see `boardAuthorResolverProvider`.
  final bool authorRequired;
}

/// Counts per reaction type and the types the caller has picked.
class ReactionState {
  const ReactionState({required this.counts, required this.myReactions});

  factory ReactionState.fromJson(Map<String, Object?> json) => ReactionState(
    counts: _counts(json['counts']),
    myReactions: {for (final t in json['myReactions']! as List) t as String},
  );

  final Map<String, int> counts;
  final Set<String> myReactions;
}

/// Who wrote it, as the server shows it.
class BoardAuthor {
  const BoardAuthor({
    required this.id,
    this.name,
    this.tag,
    this.deleted = false,
    this.guest = false,
  });

  final String id;
  final String? name;
  final String? tag;
  final bool deleted;
  final bool guest;
}

BoardAuthor _author(Map<String, Object?> json) => BoardAuthor(
  id: json['authorId']! as String,
  name: json['authorName'] as String?,
  tag: json['authorTag'] as String?,
  deleted: json['authorDeleted'] as bool? ?? false,
  guest: json['authorGuest'] as bool? ?? false,
);

Map<String, int> _counts(Object? raw) => {
  for (final e in (raw! as Map).entries)
    e.key as String: (e.value as num).toInt(),
};

/// A row of the post list.
class PostSummary {
  const PostSummary({
    required this.id,
    required this.boardCode,
    required this.title,
    required this.excerpt,
    required this.author,
    required this.viewCount,
    required this.commentCount,
    required this.reactions,
    required this.pinned,
    required this.mine,
    required this.createdAt,
  });

  factory PostSummary.fromJson(Map<String, Object?> json) => PostSummary(
    id: json['id']! as int,
    boardCode: json['boardCode']! as String,
    title: json['title']! as String,
    excerpt: json['excerpt']! as String,
    author: _author(json),
    viewCount: json['viewCount']! as int,
    commentCount: json['commentCount']! as int,
    reactions: ReactionState(
      counts: _counts(json['reactionCounts']),
      myReactions: {for (final t in json['myReactions']! as List) t as String},
    ),
    pinned: json['pinned']! as bool,
    mine: json['mine']! as bool,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final int id;
  final String boardCode;
  final String title;
  final String excerpt;
  final BoardAuthor author;
  final int viewCount;
  final int commentCount;
  final ReactionState reactions;
  final bool pinned;

  /// The server's verdict on "I wrote this" (never compare account ids: with
  /// author profiles they differ).
  final bool mine;
  final DateTime createdAt;
}

/// One post with its text. Reading it counts a view on the server.
class PostDetail extends PostSummary {
  const PostDetail({
    required super.id,
    required super.boardCode,
    required super.title,
    required super.excerpt,
    required super.author,
    required super.viewCount,
    required super.commentCount,
    required super.reactions,
    required super.pinned,
    required super.mine,
    required super.createdAt,
    required this.body,
  });

  factory PostDetail.fromJson(Map<String, Object?> json) {
    final s = PostSummary.fromJson(json);
    return PostDetail(
      id: s.id,
      boardCode: s.boardCode,
      title: s.title,
      excerpt: s.excerpt,
      author: s.author,
      viewCount: s.viewCount,
      commentCount: s.commentCount,
      reactions: s.reactions,
      pinned: s.pinned,
      mine: s.mine,
      createdAt: s.createdAt,
      body: json['body']! as String,
    );
  }

  /// Plain text. The screens draw it as text, never as HTML or Markdown.
  final String body;

  PostDetail withReactions(ReactionState reactions) => PostDetail(
    id: id,
    boardCode: boardCode,
    title: title,
    excerpt: excerpt,
    author: author,
    viewCount: viewCount,
    commentCount: commentCount,
    reactions: reactions,
    pinned: pinned,
    mine: mine,
    createdAt: createdAt,
    body: body,
  );
}

enum CommentStatus {
  pending,
  published,
  hidden,
  deleted;

  static CommentStatus parse(String raw) => values.firstWhere(
    (s) => s.name.toUpperCase() == raw,
    orElse: () => CommentStatus.hidden,
  );
}

/// A comment with its direct replies nested under [replies].
class Comment {
  const Comment({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.body,
    required this.status,
    required this.author,
    required this.reactions,
    required this.mine,
    required this.createdAt,
    this.replies = const [],
  });

  factory Comment.fromJson(
    Map<String, Object?> json, {
    List<Comment> replies = const [],
  }) => Comment(
    id: json['id']! as int,
    parentId: json['parentId'] as int?,
    depth: json['depth']! as int,
    body: json['body'] as String?,
    status: CommentStatus.parse(json['status']! as String),
    author: _author(json),
    reactions: ReactionState(
      counts: _counts(json['reactionCounts']),
      myReactions: {for (final t in json['myReactions']! as List) t as String},
    ),
    mine: json['mine']! as bool,
    createdAt: DateTime.parse(json['createdAt']! as String),
    replies: replies,
  );

  /// Turns the server's "top-level comment + every descendant flat, oldest
  /// first" into a tree. A reply whose parent is not in the list goes directly
  /// under the top-level comment instead of vanishing.
  factory Comment.thread(Map<String, Object?> json) {
    final flat = [
      for (final r in (json['replies'] as List? ?? const []))
        r as Map<String, Object?>,
    ];
    final topId = json['id']! as int;
    final known = {topId, for (final r in flat) r['id']! as int};
    final children = <int, List<Map<String, Object?>>>{};
    for (final r in flat) {
      final parent = r['parentId'] as int?;
      (children[parent != null && known.contains(parent) ? parent : topId] ??=
              [])
          .add(r);
    }
    Comment build(Map<String, Object?> node) => Comment.fromJson(
      node,
      replies: [
        for (final child in children[node['id']! as int] ?? const [])
          build(child),
      ],
    );
    return build(json);
  }

  final int id;
  final int? parentId;
  final int depth;

  /// Null when the comment is waiting, hidden or deleted: the status says why.
  /// The place in the thread stays.
  final String? body;
  final CommentStatus status;
  final BoardAuthor author;
  final ReactionState reactions;
  final bool mine;
  final DateTime createdAt;
  final List<Comment> replies;
}
