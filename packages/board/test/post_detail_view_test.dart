import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';
import 'support/pump.dart';

Widget detail({void Function(PostDetail)? onEdit, VoidCallback? onDeleted}) =>
    PostDetailView(
      board: 'general',
      postId: 1,
      onEdit: onEdit ?? (_) {},
      onDeleted: onDeleted ?? () {},
    );

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('comment-field')), text);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('comment-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the body is drawn as plain text, not as markup', (tester) async {
    final server = FakeBoard()
      ..detail = postJson(
        1,
        body: '<b>bold</b> **x** <script>alert(1)</script>',
      );
    await pumpBoard(tester, server, detail());

    expect(
      find.text('<b>bold</b> **x** <script>alert(1)</script>'),
      findsOneWidget,
    );
  });

  group('comments', () {
    testWidgets(
      'a removed comment keeps its place and its replies; levels indent',
      (tester) async {
        final server = FakeBoard()
          ..comments = [
            commentJson(
              10,
              body: null,
              status: 'DELETED',
              replies: [
                commentJson(
                  11,
                  body: 'still here',
                  depth: 1,
                  parentId: 10,
                  rootId: 10,
                ),
              ],
            ),
            commentJson(20, body: null, status: 'HIDDEN'),
          ];
        await pumpBoard(tester, server, detail());

        expect(find.text('This comment was deleted.'), findsOneWidget);
        expect(find.text('This comment is hidden.'), findsOneWidget);
        expect(find.text('still here'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('still here')).dx,
          greaterThan(
            tester.getTopLeft(find.text('This comment was deleted.')).dx,
          ),
        );
        // nothing to reply to or react on in a removed comment
        expect(find.byKey(const ValueKey('reply-10')), findsNothing);
        expect(
          find.byKey(const ValueKey('comment-10-react-LIKE')),
          findsNothing,
        );
      },
    );

    testWidgets('a comment at the depth cap has no reply button', (
      tester,
    ) async {
      final server = FakeBoard()
        ..config = configJson(maxCommentDepth: 2)
        ..comments = [
          commentJson(
            10,
            replies: [
              commentJson(11, depth: 1, parentId: 10, rootId: 10),
              commentJson(12, depth: 2, parentId: 11, rootId: 10),
            ],
          ),
        ];
      await pumpBoard(tester, server, detail());

      expect(find.byKey(const ValueKey('reply-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-12')), findsNothing);
    });

    testWidgets('sending posts with a key, then re-reads only the comments', (
      tester,
    ) async {
      final server = FakeBoard();
      await pumpBoard(tester, server, detail());
      expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
      expect(
        server.where('GET', '/boards/general/posts/1/comments'),
        hasLength(1),
      );

      await send(tester, 'first!');

      final post = server.where('POST', '/boards/general/posts/1/comments');
      expect(post, hasLength(1));
      expect(post.single.data, {'body': 'first!'});
      expect(post.single.headers['Idempotency-Key'], isNotEmpty);
      expect(
        server.where('GET', '/boards/general/posts/1/comments'),
        hasLength(2),
      );
      // reading the post again would count another view
      expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-field')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('a reply carries the parent id and can be cancelled', (
      tester,
    ) async {
      final server = FakeBoard()..comments = [commentJson(10)];
      await pumpBoard(tester, server, detail());

      await tester.tap(find.byKey(const ValueKey('reply-10')));
      await tester.pump();
      expect(find.textContaining('Replying to Bob'), findsOneWidget);
      await send(tester, 'answer');

      expect(
        server.where('POST', '/boards/general/posts/1/comments').single.data,
        {'body': 'answer', 'parentId': 10},
      );
      expect(find.textContaining('Replying to'), findsNothing);
    });

    testWidgets(
      'the send button is locked while sending: one request, one key',
      (tester) async {
        final server = FakeBoard()..holdPosts = Completer<void>();
        await pumpBoard(tester, server, detail());

        await tester.enterText(
          find.byKey(const ValueKey('comment-field')),
          'x',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('comment-send')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(
          find.byKey(const ValueKey('comment-send')),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          server.where('POST', '/boards/general/posts/1/comments'),
          hasLength(1),
        );
        server.holdPosts!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('403 ACCOUNT.EMAIL_REQUIRED shows its own message', (
      tester,
    ) async {
      final server = FakeBoard()
        ..respond = (o) => o.method == 'POST'
            ? errorBody(403, BoardErrorCodes.emailRequired)
            : null;
      await pumpBoard(tester, server, detail());

      await send(tester, 'hi');

      expect(
        find.text('Add an email address to your account first.'),
        findsOneWidget,
      );
    });

    testWidgets('authorRequired without a resolver: no composer, the reason', (
      tester,
    ) async {
      final server = FakeBoard()..config = configJson(authorRequired: true);
      await pumpBoard(tester, server, detail());

      expect(find.byKey(const ValueKey('comment-field')), findsNothing);
      expect(find.textContaining('author profile'), findsOneWidget);
    });

    testWidgets('with a resolver the author id goes into the comment', (
      tester,
    ) async {
      final server = FakeBoard()..config = configJson(authorRequired: true);
      await pumpBoard(tester, server, detail(), resolver: () async => 'prf_7');

      await send(tester, 'hello');

      expect(
        server.where('POST', '/boards/general/posts/1/comments').single.data,
        {'body': 'hello', 'authorId': 'prf_7'},
      );
    });

    testWidgets('the comment field is capped by the config', (tester) async {
      final server = FakeBoard()..config = configJson(commentMaxLength: 7);
      await pumpBoard(tester, server, detail());

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-field')))
            .maxLength,
        7,
      );
    });

    testWidgets('only my comment has an edit button', (tester) async {
      final server = FakeBoard()
        ..comments = [commentJson(10, mine: true), commentJson(11)];
      await pumpBoard(tester, server, detail());

      expect(find.byKey(const ValueKey('edit-comment-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-comment-11')), findsNothing);
    });

    testWidgets(
      'editing my comment patches it in place and re-reads the comments',
      (tester) async {
        final server = FakeBoard()
          ..config = configJson(commentMaxLength: 9)
          ..comments = [commentJson(10, body: 'old', mine: true)];
        server.respond = (o) =>
            o.method == 'PATCH' && o.path.endsWith('/comments/10')
            ? valueBody(commentJson(10, body: 'new', mine: true))
            : null;
        await pumpBoard(tester, server, detail());

        await tester.tap(find.byKey(const ValueKey('edit-comment-10')));
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('edit-field-10'));
        expect(tester.widget<TextField>(field).maxLength, 9);
        expect(tester.widget<TextField>(field).controller!.text, 'old');
        await tester.enterText(field, 'new');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('edit-save-10')));
        await tester.pumpAndSettle();

        expect(
          server
              .where('PATCH', '/boards/general/posts/1/comments/10')
              .single
              .data,
          {'body': 'new'},
        );
        expect(
          server.where('GET', '/boards/general/posts/1/comments'),
          hasLength(2),
        );
        expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
        expect(find.byKey(const ValueKey('edit-field-10')), findsNothing);
      },
    );

    testWidgets('the save button is locked while the edit is out', (
      tester,
    ) async {
      final server = FakeBoard()
        ..holdPosts = Completer<void>()
        ..comments = [commentJson(10, mine: true)];
      server.respond = (o) =>
          o.method == 'PATCH' ? valueBody(commentJson(10, mine: true)) : null;
      await pumpBoard(tester, server, detail());

      await tester.tap(find.byKey(const ValueKey('edit-comment-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-save-10')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey('edit-save-10')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('edit-save-10')))
            .onPressed,
        isNull,
      );
      server.holdPosts!.complete();
      await tester.pumpAndSettle();
      expect(
        server.where('PATCH', '/boards/general/posts/1/comments/10'),
        hasLength(1),
      );
    });

    testWidgets(
      'deleting my comment asks the server and re-reads the comments',
      (tester) async {
        final server = FakeBoard()..comments = [commentJson(10, mine: true)];
        server.respond = (o) =>
            o.method == 'DELETE' && o.path.endsWith('/comments/10')
            ? FakeAdapter.empty(204)
            : null;
        await pumpBoard(tester, server, detail());

        await tester.tap(find.byKey(const ValueKey('delete-comment-10')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(
          server.where('DELETE', '/boards/general/posts/1/comments/10'),
          hasLength(1),
        );
        expect(
          server.where('GET', '/boards/general/posts/1/comments'),
          hasLength(2),
        );
      },
    );
  });

  group('reactions', () {
    testWidgets('on the post: the answer replaces the counts, no re-read', (
      tester,
    ) async {
      final server = FakeBoard();
      await pumpBoard(tester, server, detail());

      await tester.tap(find.byKey(const ValueKey('post-react-LIKE')));
      await tester.pumpAndSettle();

      expect(
        server.where('PUT', '/boards/general/posts/1/reactions').single.data,
        {'type': 'LIKE'},
      );
      expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('post-react-LIKE')),
          matching: find.text('Like 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking the same type again removes it', (tester) async {
      final server = FakeBoard()
        ..detail = postJson(
          1,
          body: 'b',
          reactionCounts: {'LIKE': 1},
          myReactions: ['LIKE'],
        );
      await pumpBoard(tester, server, detail());

      await tester.tap(find.byKey(const ValueKey('post-react-LIKE')));
      await tester.pumpAndSettle();

      final delete = server.where(
        'DELETE',
        '/boards/general/posts/1/reactions',
      );
      expect(delete.single.queryParameters, {'type': 'LIKE'});
    });

    testWidgets('on a comment: only the comments are read again', (
      tester,
    ) async {
      final server = FakeBoard()..comments = [commentJson(10)];
      await pumpBoard(tester, server, detail());

      await tester.tap(find.byKey(const ValueKey('comment-10-react-LIKE')));
      await tester.pumpAndSettle();

      expect(
        server
            .where('PUT', '/boards/general/posts/1/comments/10/reactions')
            .single
            .data,
        {'type': 'LIKE'},
      );
      expect(
        server.where('GET', '/boards/general/posts/1/comments'),
        hasLength(2),
      );
      expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
    });

    testWidgets(
      'labels and icons come from the map; unknown types still show',
      (tester) async {
        final server = FakeBoard()
          ..config = configJson(reactionTypes: ['CHEER', 'MYSTERY']);
        await pumpBoard(
          tester,
          server,
          PostDetailView(
            board: 'general',
            postId: 1,
            onEdit: (_) {},
            onDeleted: () {},
            reactionStyles: const {
              'CHEER': BoardReactionStyle(
                label: 'Cheer!',
                icon: Icons.celebration,
              ),
            },
          ),
        );

        expect(find.text('Cheer!'), findsOneWidget);
        expect(find.byIcon(Icons.celebration), findsOneWidget);
        expect(find.text('MYSTERY'), findsOneWidget);
      },
    );
  });

  group('my post', () {
    testWidgets('edit and delete show only when the server says mine', (
      tester,
    ) async {
      final server = FakeBoard();
      await pumpBoard(tester, server, detail());
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('mine: edit hands the post over', (tester) async {
      final server = FakeBoard()..detail = postJson(1, body: 'b', mine: true);
      PostDetail? edited;
      await pumpBoard(tester, server, detail(onEdit: (p) => edited = p));

      await tester.tap(find.text('Edit'));

      expect(edited?.id, 1);
    });

    testWidgets('mine: delete asks first, then deletes and calls back', (
      tester,
    ) async {
      final server = FakeBoard()..detail = postJson(1, body: 'b', mine: true);
      var deleted = 0;
      await pumpBoard(tester, server, detail(onDeleted: () => deleted++));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(server.where('DELETE', '/boards/general/posts/1'), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.where('DELETE', '/boards/general/posts/1'), hasLength(1));
      expect(deleted, 1);
    });
  });

  testWidgets('a post that cannot be read shows the message and retry', (
    tester,
  ) async {
    final server = FakeBoard()
      ..respond = (o) => o.path == '/boards/general/posts/1'
          ? errorBody(404, 'BOARD.POST_NOT_FOUND')
          : null;
    await pumpBoard(tester, server, detail());

    expect(find.text('Could not load.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
