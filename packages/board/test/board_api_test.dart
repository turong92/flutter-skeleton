import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';

BoardApi apiWith(FakeAdapter adapter) => BoardApi(clientWith(adapter));

void main() {
  test('config reads the limits and the author flag', () async {
    final adapter = FakeAdapter(
      (_) => valueBody(configJson(authorRequired: true, maxCommentDepth: 3)),
    );

    final config = await apiWith(adapter).config();

    expect(adapter.requests.single.path, '/boards/config');
    expect(config.authorRequired, isTrue);
    expect(config.maxCommentDepth, 3);
    expect(config.titleMaxLength, 40);
    expect(config.bodyMaxLength, 200);
    expect(config.commentMaxLength, 100);
    expect(config.reactionTypes, ['LIKE', 'DISLIKE']);
  });

  test('posts asks for a page of the board and reads the page info', () async {
    final adapter = FakeAdapter(
      (_) => pageBody([postJson(1), postJson(2, mine: true)], hasNext: true),
    );

    final page = await apiWith(adapter).posts('general', page: 2, size: 10);

    final request = adapter.requests.single;
    expect(request.path, '/boards/general/posts');
    expect(request.queryParameters, {'page': 2, 'size': 10});
    expect(page.items.map((p) => p.id), [1, 2]);
    expect(page.items[1].mine, isTrue);
    expect(page.pagination.hasNext, isTrue);
  });

  test('createPost sends the idempotency key and the author id', () async {
    final adapter = FakeAdapter(
      (_) => valueBody(postJson(9, body: 'hello'), status: 201),
    );

    final post = await apiWith(adapter).createPost(
      'general',
      title: 'T',
      body: 'hello',
      idempotencyKey: 'key-1',
      authorId: 'prf_1',
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.headers['Idempotency-Key'], 'key-1');
    expect(request.data, {'title': 'T', 'body': 'hello', 'authorId': 'prf_1'});
    expect(post.id, 9);
    expect(post.body, 'hello');
  });

  test('createPost leaves authorId out when there is none', () async {
    final adapter = FakeAdapter(
      (_) => valueBody(postJson(9, body: 'b'), status: 201),
    );

    await apiWith(adapter)
        .createPost('general', title: 'T', body: 'b', idempotencyKey: 'k');

    expect(adapter.requests.single.data, {'title': 'T', 'body': 'b'});
  });

  test('updatePost patches and deletePost deletes', () async {
    final adapter = FakeAdapter(
      (o) => o.method == 'DELETE'
          ? FakeAdapter.empty(204)
          : valueBody(postJson(4, body: 'new')),
    );
    final api = apiWith(adapter);

    await api.updatePost('general', 4, title: 'T2', body: 'new');
    await api.deletePost('general', 4);

    expect(adapter.requests[0].method, 'PATCH');
    expect(adapter.requests[0].path, '/boards/general/posts/4');
    expect(adapter.requests[0].data, {'title': 'T2', 'body': 'new'});
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].path, '/boards/general/posts/4');
  });

  test('comments nests the flat replies by parent id', () async {
    final adapter = FakeAdapter(
      (_) => pageBody([
        commentJson(
          10,
          replies: [
            commentJson(11, depth: 1, parentId: 10, rootId: 10),
            commentJson(12, depth: 2, parentId: 11, rootId: 10),
            commentJson(13, depth: 1, parentId: 10, rootId: 10),
          ],
        ),
      ]),
    );

    final page = await apiWith(adapter).comments('general', 1, size: 50);

    expect(adapter.requests.single.path, '/boards/general/posts/1/comments');
    final top = page.items.single;
    expect(top.replies.map((c) => c.id), [11, 13]);
    expect(top.replies.first.replies.map((c) => c.id), [12]);
    expect(top.replies.first.replies.single.depth, 2);
  });

  test('a removed comment keeps its place with a null body', () async {
    final adapter = FakeAdapter(
      (_) => pageBody([
        commentJson(
          10,
          body: null,
          status: 'DELETED',
          replies: [commentJson(11, depth: 1, parentId: 10, rootId: 10)],
        ),
      ]),
    );

    final top = (await apiWith(adapter).comments('general', 1)).items.single;

    expect(top.body, isNull);
    expect(top.status, CommentStatus.deleted);
    expect(top.replies.single.body, 'comment');
  });

  test('createComment sends parent, author and the key', () async {
    final adapter = FakeAdapter(
      (_) => valueBody(commentJson(20, depth: 1, parentId: 10), status: 201),
    );

    await apiWith(adapter).createComment(
      'general',
      1,
      body: 'hi',
      parentId: 10,
      authorId: 'prf_1',
      idempotencyKey: 'k2',
    );

    final request = adapter.requests.single;
    expect(request.path, '/boards/general/posts/1/comments');
    expect(request.headers['Idempotency-Key'], 'k2');
    expect(request.data, {'body': 'hi', 'parentId': 10, 'authorId': 'prf_1'});
  });

  test('reactions: PUT with the type, DELETE with a query', () async {
    final adapter = FakeAdapter(
      (_) => valueBody({
        'counts': {'LIKE': 1},
        'myReactions': ['LIKE'],
      }),
    );
    final api = apiWith(adapter);

    final state = await api.reactToPost('general', 1, 'LIKE');
    await api.removePostReaction('general', 1, 'LIKE');
    await api.reactToComment('general', 1, 10, 'LIKE');
    await api.removeCommentReaction('general', 1, 10, 'LIKE');

    expect(state.counts, {'LIKE': 1});
    expect(state.myReactions, {'LIKE'});
    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].path, '/boards/general/posts/1/reactions');
    expect(adapter.requests[0].data, {'type': 'LIKE'});
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].queryParameters, {'type': 'LIKE'});
    expect(
      adapter.requests[2].path,
      '/boards/general/posts/1/comments/10/reactions',
    );
    expect(adapter.requests[3].method, 'DELETE');
  });

  test('a server error comes out as ApiRequestError with its code', () async {
    final adapter = FakeAdapter(
      (_) => errorBody(403, BoardErrorCodes.emailRequired),
    );

    await expectLater(
      apiWith(adapter).config(),
      throwsA(
        isA<ApiRequestError>().having(
          (e) => e.code,
          'code',
          'ACCOUNT.EMAIL_REQUIRED',
        ),
      ),
    );
  });
}
