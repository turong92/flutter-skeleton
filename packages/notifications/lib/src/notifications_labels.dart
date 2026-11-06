/// The texts of the notification widgets. The package does not translate: the
/// app passes its own (defaults are English).
class NotificationsLabels {
  const NotificationsLabels({
    this.empty = 'No notifications yet.',
    this.markAllRead = 'Mark all as read',
    this.loadFailed = 'Could not load.',
    this.retry = 'Try again',
    this.loadMore = 'Load more',
    this.unread = 'Unread',
    this.collapsed = _grouped,
  });

  /// Korean texts, in the polite 해요 style.
  const NotificationsLabels.ko()
    : this(
        empty: '아직 알림이 없어요.',
        markAllRead: '모두 읽음으로 표시',
        loadFailed: '불러오지 못했어요.',
        retry: '다시 시도',
        loadMore: '더 보기',
        unread: '읽지 않음',
        collapsed: _koGrouped,
      );

  final String empty;
  final String markAllRead;
  final String loadFailed;
  final String retry;
  final String loadMore;

  /// Read by screen readers next to the dot of an unread row.
  final String unread;

  /// The line under a row that stands for [count] (> 1) notifications.
  final String Function(int count) collapsed;

  static String _grouped(int count) => '$count notifications';
}

String _koGrouped(int count) => '알림 $count개';
