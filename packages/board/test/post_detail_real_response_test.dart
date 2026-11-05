import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'support/fake_board.dart';
import 'support/pump.dart';

/// `GET /boards/general/posts/1` as the kotlin sample server answers it.
const _realPost = <String, Object?>{
  'id': 1,
  'boardCode': 'general',
  'authorId': 'prf_01m6nkt5t9gb76zx0972kppemq',
  'title': 'Hello',
  'excerpt': 'First',
  'body': 'First',
  'attachments': <Object?>[],
  'status': 'PUBLISHED',
  'pinned': false,
  'viewCount': 4,
  'commentCount': 0,
  'reactionCounts': {'LIKE': 0, 'DISLIKE': 0, 'EMPATHY': 0},
  'myReactions': <Object?>[],
  'attachmentCount': 0,
  'createdAt': '2026-11-05T10:24:30.556753Z',
  'updatedAt': '2026-11-05T10:24:30.556753Z',
  'authorDeleted': false,
  'authorName': 'QA',
  'authorTag': '9619',
  'mine': false,
  'authorGuest': false,
  'canManageComments': false,
  'commentApproval': null,
  'pendingRevision': null,
};

/// What `skeleton_ui` sets for every filled button: full width.
final _fullWidthButtons = ThemeData(
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  ),
);

void main() {
  testWidgets(
    'the detail screen draws the post under a theme with full-width filled buttons',
    (tester) async {
      final server = FakeBoard()
        ..config = configJson(reactionTypes: ['LIKE', 'DISLIKE', 'EMPATHY'])
        ..detail = {
          ..._realPost,
          'mine': true,
          'myReactions': ['LIKE'],
        }
        ..comments = [commentJson(5, body: 'a comment', mine: true)];
      await pumpBoard(
        tester,
        server,
        PostDetailView(
          board: 'general',
          postId: 1,
          onEdit: (_) {},
          onDeleted: () {},
        ),
        theme: _fullWidthButtons,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.byKey(const ValueKey('comment-send')), findsOneWidget);
    },
  );
}
