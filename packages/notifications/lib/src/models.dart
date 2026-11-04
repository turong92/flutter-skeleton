import 'notification_link.dart';

/// One inbox row, as `GET /notifications` lists it.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.eventId,
    required this.topic,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.payload,
    required this.createdAt,
    required this.readAt,
    required this.link,
    required this.collapsedCount,
  });

  factory NotificationItem.fromJson(Map<String, Object?> json) =>
      NotificationItem(
        id: json['id']! as String,
        eventId: json['eventId']! as String,
        topic: json['topic']! as String,
        type: json['type']! as String,
        severity: json['severity']! as String,
        title: json['title'] as String?,
        message: json['message'] as String?,
        payload: Map<String, Object?>.from(
          (json['payload'] as Map?) ?? const {},
        ),
        createdAt: DateTime.parse(json['createdAt']! as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt']! as String),
        link: json['link'] as String?,
        collapsedCount: (json['collapsedCount'] as num?)?.toInt() ?? 1,
      );

  /// `{recipientId}:{eventId}`: the row's own key (unique in a list).
  final String id;

  /// The address of the read mark. Not the id of an SSE event or a push of a
  /// folded row: those can differ from this one.
  final String eventId;
  final String topic;
  final String type;
  final String severity;
  final String? title;
  final String? message;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  /// What the server sent. Use [safeLink] to navigate.
  final String? link;

  /// How many notifications were folded into this row (1 = not folded).
  final int collapsedCount;

  bool get unread => readAt == null;

  /// [link] when it is a path inside the app, else null.
  String? get safeLink => safeNotificationLink(link);
}
