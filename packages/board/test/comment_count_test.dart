import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_board/skeleton_board.dart';

void main() {
  test('the comment count reads 3 comments in English and 댓글 3 in Korean', () {
    expect(const BoardLabels().commentCount(3), '3 comments');
    expect(const BoardLabels.ko().commentCount(3), '댓글 3');
  });

  test('the Korean reaction names cover the same types as the default', () {
    expect(koBoardReactionStyles.keys, defaultBoardReactionStyles.keys);
  });
}
