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
