import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The texts of the board widgets. The package does not translate: the app
/// passes its own (defaults are English). Reaction names are not here: they
/// come with their icon from the reaction style map.
class BoardLabels {
  const BoardLabels({
    this.write = 'Write a post',
    this.authorMissing =
        'Writing needs an author profile, and this app has not set one up yet.',
    this.empty = 'No posts yet.',
    this.loadFailed = 'Could not load.',
    this.retry = 'Try again',
    this.loadMore = 'Load more',
    this.moreComments = 'More comments',
    this.comments = 'comments',
    this.edit = 'Edit',
    this.delete = 'Delete',
    this.cancel = 'Cancel',
    this.confirmDeletePost = 'Delete this post?',
    this.confirmDeleteComment = 'Delete this comment?',
    this.reply = 'Reply',
    this.replyingTo = 'Replying to',
    this.commentHint = 'Write a comment',
    this.send = 'Send',
    this.noComments = 'No comments yet.',
    this.commentDeleted = 'This comment was deleted.',
    this.commentHidden = 'This comment is hidden.',
    this.commentPending = 'This comment is waiting for approval.',
    this.titleHint = 'Title',
    this.bodyHint = 'Body',
    this.publish = 'Post',
    this.save = 'Save',
    this.deletedAuthor = 'Deleted user',
    this.unknownAuthor = 'Unknown',
    this.guest = 'guest',
    this.submitFailed = 'Could not send. Please try again.',
    this.actionFailed = 'That did not work. Please try again.',
    this.emailRequired = 'Add an email address to your account first.',
    this.loginIdRequired = 'Choose a login ID for your account first.',
  });

  /// Korean texts, in the polite 해요 style.
  const BoardLabels.ko()
    : this(
        write: '글쓰기',
        authorMissing: '글을 쓰려면 작성자 프로필이 필요한데, 이 앱에는 아직 정해 두지 않았어요.',
        empty: '아직 글이 없어요.',
        loadFailed: '불러오지 못했어요.',
        retry: '다시 시도',
        loadMore: '더 보기',
        moreComments: '댓글 더 보기',
        comments: '댓글',
        edit: '수정',
        delete: '삭제',
        cancel: '취소',
        confirmDeletePost: '이 글을 삭제할까요?',
        confirmDeleteComment: '이 댓글을 삭제할까요?',
        reply: '답글',
        replyingTo: '답글 대상',
        commentHint: '댓글을 써 주세요',
        send: '보내기',
        noComments: '아직 댓글이 없어요.',
        commentDeleted: '삭제된 댓글이에요.',
        commentHidden: '숨겨진 댓글이에요.',
        commentPending: '승인을 기다리는 댓글이에요.',
        titleHint: '제목',
        bodyHint: '내용',
        publish: '올리기',
        save: '저장',
        deletedAuthor: '탈퇴한 사용자',
        unknownAuthor: '알 수 없음',
        guest: '비회원',
        submitFailed: '보내지 못했어요. 다시 시도해 주세요.',
        actionFailed: '처리하지 못했어요. 다시 시도해 주세요.',
        emailRequired: '먼저 계정에 이메일 주소를 추가해 주세요.',
        loginIdRequired: '먼저 계정의 아이디를 정해 주세요.',
      );

  final String write;

  /// Shown instead of the write button, the editor and the comment box when
  /// the server wants an author id and the app gave no resolver.
  final String authorMissing;
  final String empty;
  final String loadFailed;
  final String retry;
  final String loadMore;
  final String moreComments;

  /// After a comment count in the post list: `3 comments`.
  final String comments;
  final String edit;
  final String delete;
  final String cancel;
  final String confirmDeletePost;
  final String confirmDeleteComment;
  final String reply;

  /// Followed by the author's name.
  final String replyingTo;
  final String commentHint;
  final String send;
  final String noComments;
  final String commentDeleted;
  final String commentHidden;
  final String commentPending;
  final String titleHint;
  final String bodyHint;
  final String publish;
  final String save;
  final String deletedAuthor;
  final String unknownAuthor;

  /// Put in brackets after a guest's name.
  final String guest;

  /// A write that failed for a reason the user cannot fix (network, server).
  final String submitFailed;

  /// A reaction or delete that failed.
  final String actionFailed;
  final String emailRequired;
  final String loginIdRequired;

  /// The sentence for a failed call. `403 ACCOUNT.EMAIL_REQUIRED` and
  /// `LOGIN_ID_REQUIRED` (gates of the sample server) get their own;
  /// [fallback] is for the rest.
  String errorText(Object error, String fallback) {
    final api = error is DioException
        ? ApiRequestError.fromDioException(error)
        : error;
    if (api is ApiRequestError && api.status == 403) {
      if (api.code == BoardErrorCodes.emailRequired) return emailRequired;
      if (api.code == BoardErrorCodes.loginIdRequired) return loginIdRequired;
    }
    return fallback;
  }

  String authorName(BoardAuthor author) {
    if (author.deleted) return deletedAuthor;
    final name = author.name ?? unknownAuthor;
    final tagged = author.tag == null ? name : '$name#${author.tag}';
    return author.guest ? '$tagged ($guest)' : tagged;
  }
}
