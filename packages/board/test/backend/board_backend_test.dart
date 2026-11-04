@Tags(['backend'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_board/skeleton_board.dart';

// Runs the board calls against a real kotlin-skeleton `apps/sample` (local
// profile: seed account, `general` board, author profiles): config, list,
// write (the same key sent twice), comment and reply, reactions, delete.
//
//   API_BASE_URL=http://localhost:8080/api/v1 \
//   API_SEED_EMAIL=user@example.com API_SEED_PASSWORD=password \
//   flutter test --tags backend test/backend/board_backend_test.dart
//
// API_BOARD_CODE (default `general`) picks the board. The test leaves its
// post deleted and its comments deleted; the list is not otherwise touched.
final _env = Platform.environment;
final _baseUrl = _env['API_BASE_URL'];
final _board = _env['API_BOARD_CODE'] ?? 'general';

void main() {
  final skip = _baseUrl == null
      ? 'Set API_BASE_URL, API_SEED_EMAIL and API_SEED_PASSWORD to run against a backend'
      : null;

  Future<ApiClient> signedIn() async {
    final login = await Dio(BaseOptions(baseUrl: _baseUrl!)).post<Map<String, Object?>>(
      '/auth/login',
      data: {
        'email': _env['API_SEED_EMAIL'] ?? 'user@example.com',
        'password': _env['API_SEED_PASSWORD'] ?? 'password',
      },
    );
    final token = (login.data!['value']! as Map)['accessToken']! as String;
    return ApiClient(
      baseUrl: _baseUrl!,
      headerProviders: [() => {'Authorization': 'Bearer $token'}],
    );
  }

  test('write, read, comment, react and delete on the real board', () async {
    final client = await signedIn();
    final api = BoardApi(client);

    final config = await api.config();
    expect(config.reactionTypes, contains('LIKE'));
    expect(config.titleMaxLength, greaterThan(0));
    expect(config.maxCommentDepth, greaterThanOrEqualTo(1));

    // the author id the server wants (sample: the first author profile)
    String? authorId;
    if (config.authorRequired) {
      final profiles = await client.list(
        '/author-profiles',
        decode: (json) => json['id']! as String,
      );
      authorId = profiles.first;
    }

    final firstPage = await api.posts(_board);
    expect(firstPage.pagination.page, 0);

    // a post: the same key and body twice is one post
    final key = newIdempotencyKey();
    final title = 'contract ${DateTime.now().microsecondsSinceEpoch}';
    final created = await api.createPost(
      _board,
      title: title,
      body: 'plain <b>text</b>',
      idempotencyKey: key,
      authorId: authorId,
    );
    final again = await api.createPost(
      _board,
      title: title,
      body: 'plain <b>text</b>',
      idempotencyKey: key,
      authorId: authorId,
    );
    expect(again.id, created.id);
    expect(created.mine, isTrue);

    final read = await api.post(_board, created.id);
    expect(read.body, 'plain <b>text</b>');
    expect(read.mine, isTrue);

    final edited = await api.updatePost(
      _board,
      created.id,
      title: '$title (edited)',
      body: 'changed',
    );
    expect(edited.body, 'changed');

    // comments: a top-level comment and a reply under it
    final top = await api.createComment(
      _board,
      created.id,
      body: 'first',
      idempotencyKey: newIdempotencyKey(),
      authorId: authorId,
    );
    final reply = await api.createComment(
      _board,
      created.id,
      body: 'second',
      parentId: top.id,
      idempotencyKey: newIdempotencyKey(),
      authorId: authorId,
    );
    expect(reply.depth, 1);
    final threads = await api.comments(_board, created.id);
    expect(threads.items.single.id, top.id);
    expect(threads.items.single.replies.single.id, reply.id);
    expect(threads.items.single.replies.single.body, 'second');

    // reactions on the post and on a comment
    final liked = await api.reactToPost(_board, created.id, 'LIKE');
    expect(liked.counts['LIKE'], 1);
    expect(liked.myReactions, contains('LIKE'));
    final unliked = await api.removePostReaction(_board, created.id, 'LIKE');
    expect(unliked.myReactions, isNot(contains('LIKE')));
    final commentLiked = await api.reactToComment(
      _board,
      created.id,
      top.id,
      'LIKE',
    );
    expect(commentLiked.myReactions, contains('LIKE'));

    // a deleted comment keeps its place with a null body
    await api.deleteComment(_board, created.id, reply.id);
    final after = await api.comments(_board, created.id);
    final kept = after.items.single.replies.single;
    expect(kept.id, reply.id);
    expect(kept.body, isNull);
    expect(kept.status, CommentStatus.deleted);

    await api.deletePost(_board, created.id);
    final list = await api.posts(_board);
    expect(list.items.map((p) => p.id), isNot(contains(created.id)));
  }, skip: skip);
}
