import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';
import 'notifications_api.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `notificationsApiProvider.overrideWith((ref) => NotificationsApi(ref.watch(apiClientProvider)))`.
final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => throw UnimplementedError(
    'Override notificationsApiProvider with a NotificationsApi built on the '
    'app\'s ApiClient',
  ),
);

/// The id of the signed-in account, null when signed out. The app overrides it
/// (`ref.watch(authControllerProvider)`'s account id): the package does not
/// know `auth`. Everything below is keyed by it, so another account never sees
/// the previous one's rows, and signed out nothing is called.
final notificationsAccountProvider = Provider<String?>(
  (ref) => throw UnimplementedError(
    'Override notificationsAccountProvider with the signed-in account id',
  ),
);

/// Where a tapped row goes. The app's router is the only one that knows: a
/// row's `safeLink`, or a path made from `payload` for a row without a link.
/// Default: nothing happens.
final notificationOpenProvider = Provider<void Function(NotificationItem item)>(
  (ref) => (_) {},
);

final _unreadFor = FutureProvider.autoDispose.family<int, String>(
  (ref, account) => ref.watch(notificationsApiProvider).unreadCount(),
  retry: (_, _) => null,
);

/// How many rows are unread (a folded row counts once), read from the server.
/// Signed out: 0, and no call.
final unreadCountProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  final account = ref.watch(notificationsAccountProvider);
  if (account == null) return const AsyncData(0);
  return ref.watch(_unreadFor(account));
});

/// Pages loaded so far.
class NotificationListState {
  const NotificationListState({
    required this.items,
    required this.nextPage,
    required this.hasNext,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<NotificationItem> items;
  final int nextPage;
  final bool hasNext;
  final bool loadingMore;
  final bool loadMoreFailed;

  NotificationListState copyWith({bool? loadingMore, bool? loadMoreFailed}) =>
      NotificationListState(
        items: items,
        nextPage: nextPage,
        hasNext: hasNext,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// First page on build, [loadMore] for the next ones. A failed next page keeps
/// what is on screen and shows a retry.
class NotificationListNotifier extends AsyncNotifier<NotificationListState> {
  // The account is the family key: nothing of another account is kept.
  NotificationListNotifier(this.account);

  final String account;

  @override
  Future<NotificationListState> build() async {
    final page = await ref.read(notificationsApiProvider).list();
    return NotificationListState(
      items: page.items,
      nextPage: 1,
      hasNext: page.pagination.hasNext,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.loadingMore) return;
    // The list may be read again (or dropped) while the page is on its way;
    // this ref is the one of the build that asked for it.
    final mine = ref;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(notificationsApiProvider)
          .list(page: current.nextPage);
      if (!mine.mounted) return;
      // A new notification pushes rows down a page: the same row can come
      // twice. The row's id is the key.
      final seen = {for (final item in current.items) item.id};
      state = AsyncData(
        NotificationListState(
          items: [
            ...current.items,
            for (final item in page.items)
              if (seen.add(item.id)) item,
          ],
          nextPage: current.nextPage + 1,
          hasNext: page.pagination.hasNext,
        ),
      );
    } on ApiRequestError {
      if (!mine.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

/// The inbox rows of one account, page by page.
final notificationListProvider = AsyncNotifierProvider.autoDispose
    .family<NotificationListNotifier, NotificationListState, String>(
      NotificationListNotifier.new,
      retry: (_, _) => null,
    );

/// "Read it again": the one call for a realtime event, a push that arrived in
/// the foreground and the app coming back. The unread count is read from the
/// server (a folded row makes +1 wrong) and an open list reads its first page
/// again. Takes a `Ref`, a `WidgetRef` or a `ProviderContainer`.
void notificationsChanged(Object ref) {
  switch (ref) {
    case Ref():
      ref.invalidate(_unreadFor);
      ref.invalidate(notificationListProvider);
    case WidgetRef():
      ref.invalidate(_unreadFor);
      ref.invalidate(notificationListProvider);
    case ProviderContainer():
      ref.invalidate(_unreadFor);
      ref.invalidate(notificationListProvider);
    default:
      throw ArgumentError.value(
        ref,
        'ref',
        'expected a Ref, a WidgetRef or a ProviderContainer',
      );
  }
}
