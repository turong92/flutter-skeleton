import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_labels.dart';
import 'board_parts.dart';
import 'board_providers.dart';
import 'models.dart';
import 'submit_key.dart';

/// Writes a post, or edits [post]. [onSaved] gets the saved post; moving on is
/// the app's job. Length limits come from the server config. One submit sends
/// one `Idempotency-Key` and the button is locked while it is out.
class PostEditor extends ConsumerStatefulWidget {
  const PostEditor({
    super.key,
    required this.board,
    required this.onSaved,
    this.post,
    this.labels = const BoardLabels(),
  });

  final String board;

  /// Null: a new post.
  final PostDetail? post;
  final void Function(PostDetail saved) onSaved;
  final BoardLabels labels;

  @override
  ConsumerState<PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends ConsumerState<PostEditor> {
  late final _title = TextEditingController(text: widget.post?.title);
  late final _body = TextEditingController(text: widget.post?.body);
  final _key = SubmitKey();
  bool _sending = false;
  String? _error;

  BoardLabels get labels => widget.labels;

  String _lastText = '';

  // Only a change of the text ends the submit (a controller also notifies on
  // cursor moves).
  void _onText() {
    final now = '${_title.text}\u0000${_body.text}';
    if (now != _lastText) {
      _lastText = now;
      _key.reset();
    }
  }

  @override
  void initState() {
    super.initState();
    _lastText = '${_title.text}\u0000${_body.text}';
    _title.addListener(_onText);
    _body.addListener(_onText);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _filled =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  Future<void> _submit(BoardConfig config) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(boardApiProvider);
      final PostDetail saved;
      final existing = widget.post;
      if (existing == null) {
        String? authorId;
        if (config.authorRequired) {
          authorId = await ref.read(boardAuthorResolverProvider)?.call();
          if (authorId == null) {
            if (mounted) setState(() => _error = labels.authorMissing);
            return;
          }
        }
        saved = await api.createPost(
          widget.board,
          title: _title.text,
          body: _body.text,
          idempotencyKey: _key.take(),
          authorId: authorId,
        );
      } else {
        saved = await api.updatePost(
          widget.board,
          existing.id,
          title: _title.text,
          body: _body.text,
        );
        final open = boardPostProvider((
          board: widget.board,
          postId: existing.id,
        ));
        // an open detail screen shows the new text without counting a view
        if (ref.exists(open)) ref.read(open.notifier).replace(saved);
      }
      _key.reset();
      ref.invalidate(boardPostListProvider(widget.board));
      widget.onSaved(saved);
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
    if (widget.post == null && !ref.watch(boardCanWriteProvider)) {
      return AuthorMissingNotice(labels: labels);
    }
    final config = ref.watch(boardConfigProvider);
    return switch (config) {
      AsyncValue(:final value?) => _form(value),
      AsyncError() => LoadError(
        labels: labels,
        onRetry: () => ref.invalidate(boardConfigProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _form(BoardConfig config) {
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _body]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('editor-title'),
            controller: _title,
            maxLength: config.titleMaxLength,
            decoration: InputDecoration(
              labelText: labels.titleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('editor-body'),
            controller: _body,
            maxLength: config.bodyMaxLength,
            minLines: 6,
            maxLines: null,
            decoration: InputDecoration(
              labelText: labels.bodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('editor-submit'),
              onPressed: _sending || !_filled ? null : () => _submit(config),
              child: Text(widget.post == null ? labels.publish : labels.save),
            ),
          ),
        ],
      ),
    );
  }
}
