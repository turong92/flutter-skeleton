import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';
import 'support/pump.dart';

void main() {
  testWidgets('the keys the attachment field holds are sent with the post', (
    tester,
  ) async {
    final server = FakeBoard();
    await pumpBoard(
      tester,
      server,
      PostEditor(
        board: 'general',
        onSaved: (_) {},
        attachmentField: (context, keys, onChanged, onBusy) => TextButton(
          key: const ValueKey('fake-add'),
          onPressed: () => onChanged([...keys, 'u/1/a.png']),
          child: Text('photos: ${keys.length}'),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('editor-title')), 'T');
    await tester.enterText(find.byKey(const ValueKey('editor-body')), 'B');
    await tester.tap(find.byKey(const ValueKey('fake-add')));
    await tester.pump();
    expect(find.text('photos: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor-submit')));
    await tester.pumpAndSettle();

    expect(server.where('POST', '/boards/general/posts').single.data, {
      'title': 'T',
      'body': 'B',
      'attachments': ['u/1/a.png'],
    });
  });

  testWidgets('submit is off while the field says a photo is going up', (
    tester,
  ) async {
    await pumpBoard(
      tester,
      FakeBoard(),
      PostEditor(
        board: 'general',
        onSaved: (_) {},
        attachmentField: (context, keys, onChanged, onBusy) => TextButton(
          key: const ValueKey('fake-busy'),
          onPressed: () => onBusy(true),
          onLongPress: () => onBusy(false),
          child: const Text('busy'),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('editor-title')), 'T');
    await tester.enterText(find.byKey(const ValueKey('editor-body')), 'B');
    FilledButton submit() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('editor-submit')),
    );
    await tester.pump();
    expect(submit().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('fake-busy')));
    await tester.pump();
    expect(submit().onPressed, isNull);

    await tester.longPress(find.byKey(const ValueKey('fake-busy')));
    await tester.pump();
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('editing starts from the post keys and patches them', (
    tester,
  ) async {
    final server = FakeBoard();
    final post = PostDetail.fromJson(
      postJson(1, body: 'b', mine: true, attachments: ['k/old']),
    );
    await pumpBoard(
      tester,
      server,
      PostEditor(
        board: 'general',
        post: post,
        onSaved: (_) {},
        attachmentField: (context, keys, onChanged, onBusy) => TextButton(
          key: const ValueKey('fake-add'),
          onPressed: () => onChanged([...keys, 'k/new']),
          child: Text('photos: ${keys.join(',')}'),
        ),
      ),
    );
    expect(find.text('photos: k/old'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fake-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-submit')));
    await tester.pumpAndSettle();

    expect(
      server.where('PATCH', '/boards/general/posts/1').single.data,
      containsPair('attachments', ['k/old', 'k/new']),
    );
  });

  testWidgets('without an attachment field no attachments are sent', (
    tester,
  ) async {
    final server = FakeBoard();
    await pumpBoard(
      tester,
      server,
      PostEditor(board: 'general', onSaved: (_) {}),
    );

    await tester.enterText(find.byKey(const ValueKey('editor-title')), 'T');
    await tester.enterText(find.byKey(const ValueKey('editor-body')), 'B');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-submit')));
    await tester.pumpAndSettle();

    expect(
      server.where('POST', '/boards/general/posts').single.data,
      isNot(contains('attachments')),
    );
  });

  testWidgets('the detail hands each photo, in order, to the app to draw', (
    tester,
  ) async {
    final server = FakeBoard()
      ..detail = postJson(
        1,
        body: 'Hello',
        attachments: ['k/a', 'k/b', 'k/c'],
        attachmentUrls: {'k/a': 'https://cdn.example.com/a.jpg'},
        attachmentImages: {
          'k/b': {
            'width': 800,
            'height': 600,
            'thumb': 'https://cdn.example.com/b-thumb.webp',
            'display': 'https://cdn.example.com/b.webp',
          },
        },
        attachmentsPending: ['k/c'],
      );
    await pumpBoard(
      tester,
      server,
      PostDetailView(
        board: 'general',
        postId: 1,
        onEdit: (_) {},
        onDeleted: () {},
        attachmentBuilder: (context, a) => Text(
          'photo ${a.index} ${a.key} url=${a.url} display=${a.image?.display} '
          'pending=${a.pending}',
        ),
      ),
    );

    expect(
      find.text(
        'photo 0 k/a url=https://cdn.example.com/a.jpg display=null pending=false',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'photo 1 k/b url=null display=https://cdn.example.com/b.webp pending=false',
      ),
      findsOneWidget,
    );
    expect(
      find.text('photo 2 k/c url=null display=null pending=true'),
      findsOneWidget,
    );
  });
}
