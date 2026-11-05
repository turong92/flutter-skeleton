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
    required this.commentMaxLength,
    required this.busy,
    required this.onReply,
    required this.onToggleReaction,
    required this.onEdit,
    required this.onDelete,
  });

  final BoardPostRef post;
  final BoardLabels labels;
  final Map<String, BoardReactionStyle> reactionStyles;
  final List<String> reactionTypes;

  /// A comment at this depth takes no reply.
  final int maxDepth;
  final int? commentMaxLength;
  final bool busy;
  final void Function(Comment comment) onReply;
  final Future<void> Function(
    Comment comment,
    String type, {
    required bool picked,
  })
  onToggleReaction;

  /// Answers true when the server took the new text.
  final Future<bool> Function(Comment comment, String body) onEdit;
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
          key: ValueKey(comment.id),
          comment: comment,
          labels: labels,
          reactionStyles: reactionStyles,
          reactionTypes: reactionTypes,
          canReply: comment.depth < maxDepth,
          maxLength: commentMaxLength,
          busy: busy,
          onReply: () => onReply(comment),
          onToggleReaction: (type, {required picked}) =>
              onToggleReaction(comment, type, picked: picked),
          onEdit: (body) => onEdit(comment, body),
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

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.labels,
    required this.reactionStyles,
    required this.reactionTypes,
    required this.canReply,
    required this.maxLength,
    required this.busy,
    required this.onReply,
    required this.onToggleReaction,
    required this.onEdit,
    required this.onDelete,
  });

  final Comment comment;
  final BoardLabels labels;
  final Map<String, BoardReactionStyle> reactionStyles;
  final List<String> reactionTypes;
  final bool canReply;
  final int? maxLength;
  final bool busy;
  final VoidCallback onReply;
  final void Function(String type, {required bool picked}) onToggleReaction;
  final Future<bool> Function(String body) onEdit;
  final VoidCallback onDelete;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _editing = false;
  late final _text = TextEditingController();

  Comment get comment => widget.comment;
  BoardLabels get labels => widget.labels;

  String get _shownText =>
      comment.body ??
      switch (comment.status) {
        CommentStatus.deleted => labels.commentDeleted,
        CommentStatus.pending => labels.commentPending,
        _ => labels.commentHidden,
      };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _startEdit() {
    _text.text = comment.body ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (await widget.onEdit(_text.text) && mounted) {
      setState(() => _editing = false);
    }
  }

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
          if (_editing)
            _editor()
          else
            Text(
              _shownText,
              style: comment.body == null
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : null,
            ),
          if (shown && !_editing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ReactionBar(
                    keyPrefix: 'comment-${comment.id}-react',
                    types: widget.reactionTypes,
                    styles: widget.reactionStyles,
                    state: comment.reactions,
                    onToggle: widget.busy ? null : widget.onToggleReaction,
                  ),
                  if (widget.canReply)
                    OutlinedButton(
                      key: ValueKey('reply-${comment.id}'),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.onReply,
                      child: Text(labels.reply),
                    ),
                  if (comment.mine)
                    OutlinedButton(
                      key: ValueKey('edit-comment-${comment.id}'),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.busy ? null : _startEdit,
                      child: Text(labels.edit),
                    ),
                  if (comment.mine)
                    OutlinedButton(
                      key: ValueKey('delete-comment-${comment.id}'),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.busy ? null : widget.onDelete,
                      child: Text(labels.delete),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _editor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: ValueKey('edit-field-${comment.id}'),
          controller: _text,
          maxLength: widget.maxLength,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        Wrap(
          spacing: 8,
          children: [
            ListenableBuilder(
              listenable: _text,
              builder: (context, _) => FilledButton(
                key: ValueKey('edit-save-${comment.id}'),
                style: inlineFilledStyle,
                onPressed: widget.busy || _text.text.trim().isEmpty
                    ? null
                    : _save,
                child: Text(labels.save),
              ),
            ),
            OutlinedButton(
              key: ValueKey('edit-cancel-${comment.id}'),
              onPressed: widget.busy
                  ? null
                  : () => setState(() => _editing = false),
              child: Text(labels.cancel),
            ),
          ],
        ),
      ],
    );
  }
}
