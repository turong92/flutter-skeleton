import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';
import 'support/pump.dart';

void main() {
  testWidgets('shows the posts and opens one on tap', (tester) async {
    final server = FakeBoard();
    PostSummary? opened;
    await pumpBoard(
      tester,
      server,
      PostListView(board: 'general', onOpen: (p) => opened = p),
    );

    expect(find.text('excerpt 1'), findsOneWidget);
    expect(find.text('excerpt 2'), findsOneWidget);

    await tester.tap(find.text('excerpt 2'));

    expect(opened?.id, 2);
  });

  testWidgets('reaching the end asks for the next page and appends it', (
    tester,
  ) async {
    final server = FakeBoard()
      ..postPages = [
        [postJson(1), postJson(2)],
        [postJson(3)],
      ];
    await pumpBoard(
      tester,
      server,
      PostListView(board: 'general', onOpen: (_) {}),
    );

    final pages = [
      for (final r in server.where('GET', '/boards/general/posts'))
        r.queryParameters['page'],
    ];
    expect(pages, [0, 1]);
    expect(find.text('excerpt 3'), findsOneWidget);
    expect(find.text('excerpt 1'), findsOneWidget);
  });

  testWidgets('pulling down reads the first page again', (tester) async {
    final server = FakeBoard();
    await pumpBoard(
      tester,
      server,
      PostListView(board: 'general', onOpen: (_) {}),
    );

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(server.where('GET', '/boards/general/posts'), hasLength(2));
  });

  testWidgets('a failed first page shows the message and a retry button', (
    tester,
  ) async {
    var failing = true;
    final server = FakeBoard()
      ..respond = (o) => o.path == '/boards/general/posts' && failing
          ? errorBody(500, 'COMMON.INTERNAL')
          : null;
    await pumpBoard(
      tester,
      server,
      PostListView(board: 'general', onOpen: (_) {}),
    );

    expect(find.text('Could not load.'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('excerpt 1'), findsOneWidget);
  });

  group('write button', () {
    testWidgets('is shown and calls onCompose', (tester) async {
      var composed = 0;
      await pumpBoard(
        tester,
        FakeBoard(),
        PostListView(
          board: 'general',
          onOpen: (_) {},
          onCompose: () => composed++,
        ),
      );

      await tester.tap(find.text('Write a post'));

      expect(composed, 1);
    });

    testWidgets(
      'authorRequired without a resolver: no button, the reason instead',
      (tester) async {
        final server = FakeBoard()..config = configJson(authorRequired: true);
        await pumpBoard(
          tester,
          server,
          PostListView(board: 'general', onOpen: (_) {}, onCompose: () {}),
        );

        expect(find.text('Write a post'), findsNothing);
        expect(find.textContaining('author profile'), findsOneWidget);
        // the list itself still works
        expect(find.text('excerpt 1'), findsOneWidget);
      },
    );

    testWidgets('authorRequired with a resolver: the button is back', (
      tester,
    ) async {
      final server = FakeBoard()..config = configJson(authorRequired: true);
      await pumpBoard(
        tester,
        server,
        PostListView(board: 'general', onOpen: (_) {}, onCompose: () {}),
        resolver: () async => 'prf_1',
      );

      expect(find.text('Write a post'), findsOneWidget);
    });
  });
}
