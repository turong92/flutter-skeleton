import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

const _idempotencyKeyHeader = 'Idempotency-Key';

/// The backend calls of the `board` module. Stores nothing. The board code is
/// a parameter of every call (`general` in the sample server).
///
/// `createPost` and `createComment` need a fresh key per submit
/// (`newIdempotencyKey()`): the server refuses them without one, and a retry of
/// the same submit sends the same key.
class BoardApi {
  BoardApi(this._client);

  final ApiClient _client;

  /// `GET /boards/config`.
  Future<BoardConfig> config() =>
      _client.value('/boards/config', decode: BoardConfig.fromJson);

  /// `GET /boards/{board}/posts`: pinned first, then newest.
  Future<Page<PostSummary>> posts(String board, {int page = 0, int? size}) =>
      _client.page(
        '/boards/$board/posts',
        query: {'page': page, 'size': ?size},
        decode: PostSummary.fromJson,
      );

  /// `GET /boards/{board}/posts/{id}`. The server counts a view per call.
  Future<PostDetail> post(String board, int id) =>
      _client.value('/boards/$board/posts/$id', decode: PostDetail.fromJson);

  /// `POST /boards/{board}/posts`. [authorId] is required by servers with
  /// `authorRequired`.
  Future<PostDetail> createPost(
    String board, {
    required String title,
    required String body,
    required String idempotencyKey,
    String? authorId,
    List<String>? attachments,
  }) => _client.value(
    '/boards/$board/posts',
    method: 'POST',
    json: {
      'title': title,
      'body': body,
      'authorId': ?authorId,
      'attachments': ?attachments,
    },
    headers: {_idempotencyKeyHeader: idempotencyKey},
    decode: PostDetail.fromJson,
  );

  /// `PATCH /boards/{board}/posts/{id}`: author or moderator.
  Future<PostDetail> updatePost(
    String board,
    int id, {
    required String title,
    required String body,
    List<String>? attachments,
  }) => _client.value(
    '/boards/$board/posts/$id',
    method: 'PATCH',
    json: {'title': title, 'body': body, 'attachments': ?attachments},
    decode: PostDetail.fromJson,
  );

  /// `GET /boards/{board}/posts/{id}/attachments?index=N`: a short-lived
  /// address for a photo that has no public one (a post that is waiting or
  /// hidden). Author and moderators only.
  Future<AttachmentAccess> attachmentAccess(String board, int id, int index) =>
      _client.value(
        '/boards/$board/posts/$id/attachments',
        query: {'index': index},
        decode: AttachmentAccess.fromJson,
      );

  /// `DELETE /boards/{board}/posts/{id}` (soft delete, 204).
  Future<void> deletePost(String board, int id) =>
      _client.noContent('/boards/$board/posts/$id', method: 'DELETE');

  /// `GET /boards/{board}/posts/{id}/comments`: a page of top-level comments,
  /// each with its replies nested.
  Future<Page<Comment>> comments(
    String board,
    int postId, {
    int page = 0,
    int? size,
  }) => _client.page(
    '/boards/$board/posts/$postId/comments',
    query: {'page': page, 'size': ?size},
    decode: Comment.thread,
  );

  /// `POST .../comments`; [parentId] makes it a reply.
  Future<Comment> createComment(
    String board,
    int postId, {
    required String body,
    required String idempotencyKey,
    int? parentId,
    String? authorId,
  }) => _client.value(
    '/boards/$board/posts/$postId/comments',
    method: 'POST',
    json: {'body': body, 'parentId': ?parentId, 'authorId': ?authorId},
    headers: {_idempotencyKeyHeader: idempotencyKey},
    decode: Comment.fromJson,
  );

  /// `PATCH .../comments/{id}`: the author changes the text.
  Future<Comment> updateComment(
    String board,
    int postId,
    int commentId, {
    required String body,
  }) => _client.value(
    '/boards/$board/posts/$postId/comments/$commentId',
    method: 'PATCH',
    json: {'body': body},
    decode: Comment.fromJson,
  );

  /// `DELETE .../comments/{id}`: the thread keeps the place.
  Future<void> deleteComment(String board, int postId, int commentId) =>
      _client.noContent(
        '/boards/$board/posts/$postId/comments/$commentId',
        method: 'DELETE',
      );

  /// `PUT .../reactions`: the new counts. With a single-choice server this
  /// replaces the caller's earlier pick.
  Future<ReactionState> reactToPost(String board, int postId, String type) =>
      _client.value(
        '/boards/$board/posts/$postId/reactions',
        method: 'PUT',
        json: {'type': type},
        decode: ReactionState.fromJson,
      );

  Future<ReactionState> removePostReaction(
    String board,
    int postId,
    String type,
  ) => _client.value(
    '/boards/$board/posts/$postId/reactions',
    method: 'DELETE',
    query: {'type': type},
    decode: ReactionState.fromJson,
  );

  Future<ReactionState> reactToComment(
    String board,
    int postId,
    int commentId,
    String type,
  ) => _client.value(
    '/boards/$board/posts/$postId/comments/$commentId/reactions',
    method: 'PUT',
    json: {'type': type},
    decode: ReactionState.fromJson,
  );

  Future<ReactionState> removeCommentReaction(
    String board,
    int postId,
    int commentId,
    String type,
  ) => _client.value(
    '/boards/$board/posts/$postId/comments/$commentId/reactions',
    method: 'DELETE',
    query: {'type': type},
    decode: ReactionState.fromJson,
  );
}
