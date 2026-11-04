import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';
import 'notifications_labels.dart';
import 'notifications_providers.dart';

/// The inbox: pull down to read again, the next page loads when the end comes
/// into view, unread rows are marked, a folded row says how many it holds.
/// A tap marks the row read (by its `eventId`) and hands it to
/// `notificationOpenProvider`; the app's router decides where it goes.
class NotificationListView extends ConsumerWidget {
  const NotificationListView({
    super.key,
    this.labels = const NotificationsLabels(),
  });

  final NotificationsLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(notificationsAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final provider = notificationListProvider(account);
    final rows = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async {
        notificationsChanged(ref);
        await ref.read(provider.future);
      },
      child: switch (rows) {
        AsyncValue(:final value?) => _list(context, ref, account, value),
        AsyncError() => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(labels.loadFailed),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(provider),
                    child: Text(labels.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    String account,
    NotificationListState s,
  ) {
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
    final notifier = ref.read(notificationListProvider(account).notifier);
    final anyUnread = s.items.any((item) => item.unread);
    final header = anyUnread ? 1 : 0;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: header + s.items.length + (s.hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < header) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _markAllRead(context, ref),
                child: Text(labels.markAllRead),
              ),
            ),
          );
        }
        final row = index - header;
        if (row < s.items.length) {
          final item = s.items[row];
          return _Tile(
            item: item,
            labels: labels,
            onTap: () => _open(context, ref, item),
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

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final api = ref.read(notificationsApiProvider);
    final container = ProviderScope.containerOf(context);
    try {
      await api.markAllRead();
    } on ApiRequestError {
      // the list is read again below and shows what the server still has
    }
    notificationsChanged(container);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
  ) async {
    final api = ref.read(notificationsApiProvider);
    final open = ref.read(notificationOpenProvider);
    final container = ProviderScope.containerOf(context);
    // Going there does not wait for the mark.
    final marked = item.unread ? api.markRead(item.eventId) : null;
    open(item);
    if (marked == null) return;
    try {
      await marked;
    } on ApiRequestError {
      // it stays unread and the next read of the list shows that
    }
    notificationsChanged(container);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.labels, required this.onTap});

  final NotificationItem item;
  final NotificationsLabels labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.title ?? item.message ?? '';
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.unread)
                Semantics(
                  label: labels.unread,
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: item.unread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.title != null && item.message != null)
                      Text(
                        item.message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _format(item.createdAt),
                        if (item.collapsedCount > 1)
                          labels.collapsed(item.collapsedCount),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
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
