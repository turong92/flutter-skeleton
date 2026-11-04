import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_labels.dart';
import 'board_parts.dart';
import 'board_providers.dart';
import 'models.dart';

/// The posts of one board: pull down to read again, the next page loads when
/// the end comes into view. Navigation is the app's: [onOpen] gets the tapped
/// post, [onCompose] the write button (left out: no button).
class PostListView extends ConsumerWidget {
  const PostListView({
    super.key,
    required this.board,
    required this.onOpen,
    this.onCompose,
    this.labels = const BoardLabels(),
  });

  final String board;
  final void Function(PostSummary post) onOpen;
  final VoidCallback? onCompose;
  final BoardLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = boardPostListProvider(board);
    final posts = ref.watch(provider);
    final canWrite = ref.watch(boardCanWriteProvider);

    return Column(
      children: [
        if (onCompose != null)
          canWrite
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onCompose,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(labels.write),
                    ),
                  ),
                )
              : AuthorMissingNotice(labels: labels),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(provider.future),
            child: switch (posts) {
              AsyncValue(:final value?) => _list(context, ref, value),
              AsyncError() => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  LoadError(
                    labels: labels,
                    onRetry: () => ref.invalidate(provider),
                  ),
                ],
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, PagedState<PostSummary> s) {
    if (s.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(labels.empty)),
          ),
        ],
      );
    }
    final notifier = ref.read(boardPostListProvider(board).notifier);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: s.items.length + (s.hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < s.items.length) {
          return _PostTile(
            post: s.items[index],
            labels: labels,
            onTap: () => onOpen(s.items[index]),
          );
        }
        return s.loadMoreFailed
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: OutlinedButton(
                    onPressed: notifier.loadMore,
                    child: Text(labels.loadMore),
                  ),
                ),
              )
            : _LoadMoreOnShow(onShown: notifier.loadMore);
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.post,
    required this.labels,
    required this.onTap,
  });

  final PostSummary post;
  final BoardLabels labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.pinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin_outlined, size: 16),
                    ),
                  Expanded(
                    child: Text(
                      post.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(post.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                '${labels.authorName(post.author)} · ${formatDate(post.createdAt)}'
                ' · ${post.commentCount} ${labels.comments}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The end of the list: asks for the next page once it is built (the list
/// builds it only when it scrolls into view).
class _LoadMoreOnShow extends StatefulWidget {
  const _LoadMoreOnShow({required this.onShown});

  final Future<void> Function() onShown;

  @override
  State<_LoadMoreOnShow> createState() => _LoadMoreOnShowState();
}

class _LoadMoreOnShowState extends State<_LoadMoreOnShow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onShown());
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}
