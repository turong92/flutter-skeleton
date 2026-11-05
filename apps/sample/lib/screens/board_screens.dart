import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_push/skeleton_push.dart';

import '../config.dart';
import '../email_gate.dart';
import 'email_screen.dart';

/// The posts of the board. The push prompt sits on top: it only appears when
/// push can work and the person has not been asked yet.
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Board')),
      body: Column(
        children: [
          const PushPrompt(),
          const EmailWriteNotice(),
          Expanded(
            child: PostListView(
              board: AppConfig.board,
              onOpen: (post) => context.go('/board/${post.id}'),
              // An account that must add an address to write is told now, not
              // after the post is typed.
              onCompose: () {
                if (ref.read(emailGateProvider.notifier).ensure()) {
                  context.go('/board/new');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: PostDetailView(
        board: AppConfig.board,
        postId: postId,
        onEdit: (post) => context.push('/board/${post.id}/edit', extra: post),
        onDeleted: () => context.go('/board'),
      ),
    );
  }
}

/// Write (`post` null) or edit.
class PostEditorScreen extends StatelessWidget {
  const PostEditorScreen({super.key, this.post});

  final PostDetail? post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post == null ? 'New post' : 'Edit post')),
      body: PostEditor(
        board: AppConfig.board,
        post: post,
        onSaved: (saved) =>
            post == null ? context.go('/board/${saved.id}') : context.pop(),
      ),
    );
  }
}
