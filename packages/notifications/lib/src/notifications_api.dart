import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The calls of the `notification` module's inbox. Stores nothing.
class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  /// `GET /notifications`: my rows, newest first. [page] counts from 0.
  Future<Page<NotificationItem>> list({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) => _client.page(
    '/notifications',
    query: {'page': page, 'size': size, if (unreadOnly) 'unreadOnly': true},
    decode: NotificationItem.fromJson,
  );

  /// `GET /notifications/unread-count`: a folded row counts once.
  Future<int> unreadCount() => _client.value(
    '/notifications/unread-count',
    decode: (json) => (json['count']! as num).toInt(),
  );

  /// `PATCH /notifications/{eventId}/read`. Pass the row's `eventId`.
  Future<void> markRead(String eventId) => _client.noContent(
    '/notifications/${Uri.encodeComponent(eventId)}/read',
    method: 'PATCH',
  );

  /// `PATCH /notifications/read-all`: how many rows it marked.
  Future<int> markAllRead() => _client.value(
    '/notifications/read-all',
    method: 'PATCH',
    decode: (json) => (json['updated']! as num).toInt(),
  );
}
