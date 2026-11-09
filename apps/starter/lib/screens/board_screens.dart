// #file board
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_board/skeleton_board.dart';
// #if storage
import 'package:skeleton_storage/skeleton_storage.dart';
// #endif

import '../l10n/l10n.dart';
import '../config.dart';

/// The posts of the board.
class BoardListScreen extends StatelessWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.boardTitle)),
      body: PostListView(
        labels: context.byLocale(const BoardLabels.ko(), const BoardLabels()),
        board: AppConfig.board,
        onOpen: (post) => context.push('/board/${post.id}'),
        onCompose: () => context.push('/board/new'),
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
      appBar: AppBar(title: Text(context.l10n.postTitle)),
      body: PostDetailView(
        reactionStyles: context.byLocale(
          koBoardReactionStyles,
          defaultBoardReactionStyles,
        ),
        labels: context.byLocale(const BoardLabels.ko(), const BoardLabels()),
        board: AppConfig.board,
        postId: postId,
        onEdit: (post) => context.push('/board/${post.id}/edit', extra: post),
        onDeleted: () => context.pop(),
        // #if storage
        attachmentBuilder: (context, photo) =>
            _PostPhoto(key: ValueKey(photo.key), postId: postId, photo: photo),
        // #endif
      ),
    );
  }
}

/// Write (`post` null) or edit.
class PostEditorScreen extends ConsumerWidget {
  const PostEditorScreen({super.key, this.post});

  final PostDetail? post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          post == null ? context.l10n.newPost : context.l10n.editPost,
        ),
      ),
      body: PostEditor(
        labels: context.byLocale(const BoardLabels.ko(), const BoardLabels()),
        board: AppConfig.board,
        post: post,
        onSaved: (saved) => post == null
            ? context.pushReplacement('/board/${saved.id}')
            : context.pop(),
        // #if storage
        attachmentField: (context, keys, onChanged, onBusy) => ImageUploadField(
          labels: context.byLocale(
            const ImageUploadLabels.ko(),
            const ImageUploadLabels(),
          ),
          uploader: ref.watch(uploaderProvider),
          value: keys,
          onChanged: onChanged,
          onBusyChanged: onBusy,
          // a photo of the post being edited: its converted copy or address
          keyPreview: (context, key) {
            final url =
                post?.attachmentImages[key]?.thumb ?? post?.attachmentUrls[key];
            return url == null
                ? const Icon(Icons.image_outlined)
                : StoredImage(url: _abs(url));
          },
        ),
        // #endif
      ),
    );
  }
}

// #if storage
/// A server whose public base is a path gives addresses without a host.
String _abs(String url) => resolveStoredUrl(url, AppConfig.apiBaseUrl);

/// One photo of a post. The address comes with the post when the server has
/// the public area (converted copy first); a post without one (waiting,
/// hidden) asks the server for a short-lived address. A photo still being
/// converted shows a note.
class _PostPhoto extends ConsumerStatefulWidget {
  const _PostPhoto({super.key, required this.postId, required this.photo});

  final int postId;
  final PostAttachment photo;

  @override
  ConsumerState<_PostPhoto> createState() => _PostPhotoState();
}

class _PostPhotoState extends ConsumerState<_PostPhoto> {
  Future<AttachmentAccess>? _access;

  @override
  void initState() {
    super.initState();
    final photo = widget.photo;
    if (photo.url == null && photo.image == null && !photo.pending) {
      _access = ref
          .read(boardApiProvider)
          .attachmentAccess(AppConfig.board, widget.postId, photo.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final image = photo.image;
    if (image != null) {
      return StoredImage(
        url: _abs(image.display),
        width: image.width,
        height: image.height,
        fit: BoxFit.contain,
      );
    }
    final url = photo.url;
    if (url != null) {
      return StoredImage(url: _abs(url), fit: BoxFit.contain);
    }
    if (photo.pending) return Text(context.l10n.photoBeingPrepared);
    return FutureBuilder(
      future: _access,
      builder: (context, snapshot) {
        final access = snapshot.data;
        if (access != null) {
          return StoredImage(url: _abs(access.url), fit: BoxFit.contain);
        }
        return snapshot.hasError
            ? Text(context.l10n.photoCannotBeShown)
            : const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
      },
    );
  }
}
// #endif
