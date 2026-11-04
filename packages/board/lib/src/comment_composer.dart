import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_labels.dart';
import 'board_parts.dart';
import 'board_providers.dart';
import 'models.dart';
import 'submit_key.dart';

/// The box under a post: a new comment, or a reply when [replyTo] is set.
/// One submit sends one `Idempotency-Key`; the button is locked while it is
/// out. A posted comment makes the comment list read again (the post is left
/// alone).
class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({
    super.key,
    required this.post,
    required this.labels,
    required this.onPosted,
    this.replyTo,
    this.onCancelReply,
  });

  final BoardPostRef post;
  final BoardLabels labels;
  final Comment? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback onPosted;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _text = TextEditingController();
  final _key = SubmitKey();
  String _lastText = '';
  int? _lastParent;
  bool _sending = false;
  String? _error;

  BoardLabels get labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      // only a change of the text ends the submit, not a cursor move
      if (_text.text != _lastText) {
        _lastText = _text.text;
        _key.reset();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommentComposer old) {
    super.didUpdateWidget(old);
    // a comment for another parent is another submit
    if (widget.replyTo?.id != _lastParent) {
      _lastParent = widget.replyTo?.id;
      _key.reset();
    }
  }

  Future<void> _send(BoardConfig config) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      String? authorId;
      if (config.authorRequired) {
        authorId = await ref.read(boardAuthorResolverProvider)?.call();
        if (authorId == null) {
          if (mounted) setState(() => _error = labels.authorMissing);
          return;
        }
      }
      await ref
          .read(boardApiProvider)
          .createComment(
            widget.post.board,
            widget.post.postId,
            body: _text.text,
            parentId: widget.replyTo?.id,
            authorId: authorId,
            idempotencyKey: _key.take(),
          );
      _key.reset();
      _text.clear();
      ref.invalidate(boardCommentsProvider(widget.post));
      widget.onPosted();
    } catch (e) {
      if (mounted) {
        setState(() => _error = labels.errorText(e, labels.submitFailed));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(boardCanWriteProvider)) {
      return AuthorMissingNotice(labels: labels);
    }
    final config = ref.watch(boardConfigProvider).value;
    if (config == null) return const SizedBox.shrink();
    final replyTo = widget.replyTo;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${labels.replyingTo} ${labels.authorName(replyTo.author)}',
                  ),
                ),
                OutlinedButton(
                  onPressed: widget.onCancelReply,
                  child: Text(labels.cancel),
                ),
              ],
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('comment-field'),
                  controller: _text,
                  maxLength: config.commentMaxLength,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: labels.commentHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => FilledButton(
                    key: const ValueKey('comment-send'),
                    onPressed: _sending || _text.text.trim().isEmpty
                        ? null
                        : () => _send(config),
                    child: Text(labels.send),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
