import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_ads/skeleton_ads.dart';
import 'package:skeleton_board/skeleton_board.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

import '../l10n/l10n.dart';
import '../config.dart';
import '../email_gate.dart';
import 'email_screen.dart';

/// The posts of the board. The push prompt sits on top: it only appears when
/// push can work and the person has not been asked yet.
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps one interstitial loaded for when a post is left.
    ref.watch(interstitialAdProvider(_interstitialUnit));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.boardTitle)),
      body: Column(
        children: [
          PushPrompt(
            labels: context.byLocale(const PushLabels.ko(), const PushLabels()),
          ),
          const EmailWriteNotice(),
          Expanded(
            child: PostListView(
              labels: context.byLocale(
                const BoardLabels.ko(),
                const BoardLabels(),
              ),
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

/// The unit of the interstitial shown when a post is left.
String get _interstitialUnit => AdUnitIds.interstitial(
  android: AppConfig.adsInterstitialAndroid,
  ios: AppConfig.adsInterstitialIos,
);

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leaving a post for the list is a natural break; the list screen keeps
    // the interstitial loaded, and the minimum interval keeps it rare.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(interstitialAdProvider(_interstitialUnit)).showIfAllowed();
        }
      },
      child: _detail(context),
    );
  }

  Widget _detail(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.postTitle)),
      body: Column(
        children: [
          // Comments and reactions are writes too: tell before they are typed.
          const EmailWriteNotice(),
          Expanded(
            child: PostDetailView(
              reactionStyles: context.byLocale(
                koBoardReactionStyles,
                defaultBoardReactionStyles,
              ),
              labels: context.byLocale(
                const BoardLabels.ko(),
                const BoardLabels(),
              ),
              board: AppConfig.board,
              postId: postId,
              onEdit: (post) =>
                  context.push('/board/${post.id}/edit', extra: post),
              onDeleted: () => context.go('/board'),
              attachmentBuilder: (context, photo) => _PostPhoto(
                key: ValueKey(photo.key),
                postId: postId,
                photo: photo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        onSaved: (saved) =>
            post == null ? context.go('/board/${saved.id}') : context.pop(),
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
      ),
    );
  }
}
