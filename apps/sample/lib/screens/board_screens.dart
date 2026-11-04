import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_push/skeleton_push.dart';

import '../config.dart';

/// The posts of the board. The push prompt sits on top: it only appears when
/// push can work and the person has not been asked yet.
class BoardListScreen extends StatelessWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Board')),
      body: Column(
        children: [
          const PushPrompt(),
          Expanded(
            child: PostListView(
              board: AppConfig.board,
              onOpen: (post) => context.go('/board/${post.id}'),
              onCompose: () => context.go('/board/new'),
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
