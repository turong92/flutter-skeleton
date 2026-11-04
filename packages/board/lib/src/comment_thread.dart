import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_labels.dart';
import 'board_parts.dart';
import 'board_providers.dart';
import 'models.dart';
import 'reaction_bar.dart';

/// The comment threads of a post (a page of top-level comments, replies
/// nested). A removed or hidden comment (`body == null`) keeps its place so
/// the thread keeps its shape.
class CommentThreads extends ConsumerWidget {
  const CommentThreads({
    super.key,
    required this.post,
    required this.labels,
    required this.reactionStyles,
    required this.reactionTypes,
    required this.maxDepth,
    required this.busy,
    required this.onReply,
    required this.onToggleReaction,
    required this.onDelete,
  });

  final BoardPostRef post;
  final BoardLabels labels;
  final Map<String, BoardReactionStyle> reactionStyles;
  final List<String> reactionTypes;

  /// A comment at this depth takes no reply.
  final int maxDepth;
  final bool busy;
  final void Function(Comment comment) onReply;
  final Future<void> Function(
    Comment comment,
    String type, {
    required bool picked,
  })
  onToggleReaction;
  final void Function(Comment comment) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = boardCommentsProvider(post);
    final comments = ref.watch(provider);
    return switch (comments) {
      AsyncValue(:final value?) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value.items.isEmpty) Text(labels.noComments),
          for (final comment in value.items) _node(comment),
          if (value.hasNext)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: value.loadingMore
                    ? null
                    : ref.read(provider.notifier).loadMore,
                child: Text(labels.moreComments),
              ),
            ),
        ],
      ),
      AsyncError() => LoadError(
        labels: labels,
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _node(Comment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: comment,
          labels: labels,
          reactionStyles: reactionStyles,
          reactionTypes: reactionTypes,
          canReply: comment.depth < maxDepth,
          busy: busy,
          onReply: () => onReply(comment),
          onToggleReaction: (type, {required picked}) =>
              onToggleReaction(comment, type, picked: picked),
          onDelete: () => onDelete(comment),
        ),
        for (final reply in comment.replies)
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.black26, width: 2)),
            ),
            child: _node(reply),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.labels,
    required this.reactionStyles,
    required this.reactionTypes,
    required this.canReply,
    required this.busy,
    required this.onReply,
    required this.onToggleReaction,
    required this.onDelete,
  });

  final Comment comment;
  final BoardLabels labels;
  final Map<String, BoardReactionStyle> reactionStyles;
  final List<String> reactionTypes;
  final bool canReply;
  final bool busy;
  final VoidCallback onReply;
  final void Function(String type, {required bool picked}) onToggleReaction;
  final VoidCallback onDelete;

  String get _text =>
      comment.body ??
      switch (comment.status) {
        CommentStatus.deleted => labels.commentDeleted,
        CommentStatus.pending => labels.commentPending,
        _ => labels.commentHidden,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = comment.status == CommentStatus.published;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${labels.authorName(comment.author)} · ${formatDate(comment.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            _text,
            style: comment.body == null
                ? const TextStyle(fontStyle: FontStyle.italic)
                : null,
          ),
          if (shown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ReactionBar(
                    keyPrefix: 'comment-${comment.id}-react',
                    types: reactionTypes,
                    styles: reactionStyles,
                    state: comment.reactions,
                    onToggle: busy ? null : onToggleReaction,
                  ),
                  if (canReply)
                    OutlinedButton(
                      key: ValueKey('reply-${comment.id}'),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onReply,
                      child: Text(labels.reply),
                    ),
                  if (comment.mine)
                    OutlinedButton(
                      key: ValueKey('delete-comment-${comment.id}'),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: busy ? null : onDelete,
                      child: Text(labels.delete),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
