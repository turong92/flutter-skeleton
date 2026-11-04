import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_labels.dart';
import 'board_parts.dart';
import 'board_providers.dart';
import 'comment_composer.dart';
import 'comment_thread.dart';
import 'models.dart';
import 'reaction_bar.dart';

/// One post with its reactions and comment threads, and the comment box.
///
/// Opening it reads the post once (the server counts a view). A reaction on
/// the post puts the server's answer in place; a comment or a reaction on a
/// comment reads the comment list again. Neither reads the post again.
/// Navigation is the app's: [onEdit] (my post only) gets the post, [onDeleted]
/// is called after the delete went through.
class PostDetailView extends ConsumerStatefulWidget {
  const PostDetailView({
    super.key,
    required this.board,
    required this.postId,
    required this.onEdit,
    required this.onDeleted,
    this.labels = const BoardLabels(),
    this.reactionStyles = defaultBoardReactionStyles,
  });

  final String board;
  final int postId;
  final void Function(PostDetail post) onEdit;
  final VoidCallback onDeleted;
  final BoardLabels labels;

  /// Name and icon per reaction type code.
  final Map<String, BoardReactionStyle> reactionStyles;

  @override
  ConsumerState<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends ConsumerState<PostDetailView> {
  bool _busy = false;
  Comment? _replyTo;

  BoardLabels get labels => widget.labels;
  BoardPostRef get _ref => (board: widget.board, postId: widget.postId);

  /// One reaction or delete at a time; a failure is said in a snack bar.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        showMessage(context, labels.errorText(e, labels.actionFailed));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePostReaction(String type, {required bool picked}) =>
      _run(() async {
        final api = ref.read(boardApiProvider);
        final state = picked
            ? await api.removePostReaction(widget.board, widget.postId, type)
            : await api.reactToPost(widget.board, widget.postId, type);
        ref.read(boardPostProvider(_ref).notifier).setReactions(state);
      });

  Future<void> _toggleCommentReaction(
    Comment comment,
    String type, {
    required bool picked,
  }) => _run(() async {
    final api = ref.read(boardApiProvider);
    if (picked) {
      await api.removeCommentReaction(
        widget.board,
        widget.postId,
        comment.id,
        type,
      );
    } else {
      await api.reactToComment(widget.board, widget.postId, comment.id, type);
    }
    ref.invalidate(boardCommentsProvider(_ref));
  });

  Future<void> _deleteComment(Comment comment) async {
    if (!await confirmDelete(context, labels, labels.confirmDeleteComment)) {
      return;
    }
    await _run(() async {
      await ref
          .read(boardApiProvider)
          .deleteComment(widget.board, widget.postId, comment.id);
      ref.invalidate(boardCommentsProvider(_ref));
    });
  }

  Future<void> _deletePost() async {
    if (!await confirmDelete(context, labels, labels.confirmDeletePost)) return;
    var deleted = false;
    await _run(() async {
      await ref
          .read(boardApiProvider)
          .deletePost(widget.board, widget.postId);
      ref.invalidate(boardPostListProvider(widget.board));
      deleted = true;
    });
    if (deleted && mounted) widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(boardPostProvider(_ref));
    return switch (post) {
      AsyncValue(:final value?) => _content(context, value),
      AsyncError() => LoadError(
        labels: labels,
        onRetry: () => ref.invalidate(boardPostProvider(_ref)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _content(BuildContext context, PostDetail post) {
    final theme = Theme.of(context);
    final config = ref.watch(boardConfigProvider).value;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(post.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${labels.authorName(post.author)} · ${formatDate(post.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              // plain text on purpose: no HTML, no Markdown
              Text(post.body),
              const SizedBox(height: 16),
              if (config != null)
                ReactionBar(
                  keyPrefix: 'post-react',
                  types: config.reactionTypes,
                  styles: widget.reactionStyles,
                  state: post.reactions,
                  onToggle: _busy ? null : _togglePostReaction,
                ),
              if (post.mine)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onEdit(post),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(labels.edit),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _deletePost,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(labels.delete),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              CommentThreads(
                post: _ref,
                labels: labels,
                reactionStyles: widget.reactionStyles,
                reactionTypes: config?.reactionTypes ?? const [],
                maxDepth: config?.maxCommentDepth ?? 0,
                busy: _busy,
                onReply: (c) => setState(() => _replyTo = c),
                onToggleReaction: _toggleCommentReaction,
                onDelete: _deleteComment,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: CommentComposer(
            post: _ref,
            labels: labels,
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            onPosted: () => setState(() => _replyTo = null),
          ),
        ),
      ],
    );
  }
}
