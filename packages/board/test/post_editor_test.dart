import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';
import 'support/pump.dart';

const _title = ValueKey('editor-title');
const _body = ValueKey('editor-body');
const _submit = ValueKey('editor-submit');

Future<void> fill(WidgetTester tester, {String title = 'T', String body = 'B'}) async {
  await tester.enterText(find.byKey(_title), title);
  await tester.enterText(find.byKey(_body), body);
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byKey(_submit));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('writing sends a key, the author id, and hands the post back', (
    tester,
  ) async {
    final server = FakeBoard()..config = configJson(authorRequired: true);
    PostDetail? saved;
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (p) => saved = p),
      resolver: () async => 'prf_3',
    );

    await fill(tester, title: 'Hello', body: 'World');
    await submit(tester);

    final request = server.where('POST', '/boards/general/posts').single;
    expect(request.data, {'title': 'Hello', 'body': 'World', 'authorId': 'prf_3'});
    expect(request.headers['Idempotency-Key'], isNotEmpty);
    expect(saved?.title, 'Hello');
  });

  testWidgets('the fields are capped by the config', (tester) async {
    final server = FakeBoard()
      ..config = configJson(titleMaxLength: 11, bodyMaxLength: 33);
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (_) {}),
    );

    expect(tester.widget<TextField>(find.byKey(_title)).maxLength, 11);
    expect(tester.widget<TextField>(find.byKey(_body)).maxLength, 33);
  });

  testWidgets('submit is off until both fields have text', (tester) async {
    await pumpBoard(
      tester,
      FakeBoard(),
      PostEditor(board: 'general', onSaved: (_) {}),
    );
    FilledButton button() => tester.widget<FilledButton>(find.byKey(_submit));

    expect(button().onPressed, isNull);
    await fill(tester, title: 'T', body: '');
    expect(button().onPressed, isNull);
    await fill(tester);
    expect(button().onPressed, isNotNull);
  });

  testWidgets('while sending the button is locked: one request', (
    tester,
  ) async {
    final server = FakeBoard()..holdPosts = Completer<void>();
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (_) {}),
    );
    await fill(tester);

    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.tap(find.byKey(_submit), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));

    expect(server.where('POST', '/boards/general/posts'), hasLength(1));
    server.holdPosts!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a retry of the same text reuses the key; changed text takes a new one',
    (tester) async {
      var failing = true;
      final server = FakeBoard()
        ..respond = (o) => o.method == 'POST' && failing
            ? errorBody(500, 'COMMON.INTERNAL')
            : null;
      await pumpBoard(
        tester,
        server,
        PostEditor(board: 'general', onSaved: (_) {}),
      );
      await fill(tester);

      await submit(tester);
      expect(find.text('Could not send. Please try again.'), findsOneWidget);
      await submit(tester);
      failing = false;
      await fill(tester, title: 'T2');
      await submit(tester);

      final keys = [
        for (final r in server.where('POST', '/boards/general/posts'))
          r.headers['Idempotency-Key'],
      ];
      expect(keys, hasLength(3));
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[0]));
    },
  );

  testWidgets('authorRequired without a resolver: no form, the reason', (
    tester,
  ) async {
    final server = FakeBoard()..config = configJson(authorRequired: true);
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (_) {}),
    );

    expect(find.byKey(_title), findsNothing);
    expect(find.textContaining('author profile'), findsOneWidget);
  });

  testWidgets('403 ACCOUNT.LOGIN_ID_REQUIRED shows its own message', (
    tester,
  ) async {
    final server = FakeBoard()
      ..respond = (o) => o.method == 'POST'
          ? errorBody(403, BoardErrorCodes.loginIdRequired)
          : null;
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (_) {}),
    );
    await fill(tester);

    await submit(tester);

    expect(
      find.text('Choose a login ID for your account first.'),
      findsOneWidget,
    );
  });

  testWidgets('editing starts from the post and patches it', (tester) async {
    final server = FakeBoard();
    final post = PostDetail.fromJson(
      postJson(1, title: 'Old', body: 'old body', mine: true),
    );
    PostDetail? saved;
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', post: post, onSaved: (p) => saved = p),
    );
    expect(find.text('Old'), findsOneWidget);

    await fill(tester, title: 'New', body: 'new body');
    await submit(tester);

    final request = server.where('PATCH', '/boards/general/posts/1').single;
    expect(request.data, {'title': 'New', 'body': 'new body'});
    expect(request.headers.containsKey('Idempotency-Key'), isFalse);
    expect(saved?.body, 'new body');
  });

  testWidgets('an open detail screen gets the edit without a second read', (
    tester,
  ) async {
    final server = FakeBoard();
    final post = PostDetail.fromJson(postJson(1, title: 'Old', body: 'old'));
    final container = await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', post: post, onSaved: (_) {}),
    );
    const key = (board: 'general', postId: 1);
    final sub = container.listen(boardPostProvider(key), (_, _) {});
    await tester.pumpAndSettle();

    await fill(tester, title: 'New', body: 'new body');
    await submit(tester);

    expect(sub.read().value?.title, 'New');
    expect(server.where('GET', '/boards/general/posts/1'), hasLength(1));
  });
}
