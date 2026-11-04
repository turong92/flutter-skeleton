import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

const _meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> itemJson(
  String id, {
  String? eventId,
  String? readAt,
  String? link,
  int collapsedCount = 1,
  String? title,
}) => {
  'id': id,
  'eventId': eventId ?? 'ev-$id',
  'recipientId': 'acc_1',
  'topic': 'board',
  'type': 'COMMENT',
  'severity': 'INFO',
  'title': title ?? 'title $id',
  'message': 'message $id',
  'payload': <String, Object?>{'postId': 7},
  'createdAt': '2026-01-01T00:00:00Z',
  'readAt': readAt,
  'link': link,
  'collapsedCount': collapsedCount,
};

/// A scripted inbox server. [pages] is what `GET /notifications` returns per
/// page number, [unread] the unread count.
class FakeInbox {
  List<List<Map<String, Object?>>> pages = [
    [itemJson('a'), itemJson('b')],
  ];
  int unread = 2;

  late final FakeAdapter adapter = FakeAdapter(_handle);

  List<RequestOptions> where(String method, String path) => [
    for (final r in adapter.requests)
      if (r.method == method && r.path == path) r,
  ];

  ResponseBody _handle(RequestOptions o) {
    switch ((o.method, o.path)) {
      case ('GET', '/notifications'):
        final page = (o.queryParameters['page'] as int?) ?? 0;
        return FakeAdapter.json(200, {
          'values': pages[page],
          'pagination': {
            'page': page,
            'size': 20,
            'totalElements': pages.length * 2,
            'totalPages': pages.length,
            'hasNext': page + 1 < pages.length,
            'hasPrevious': page > 0,
          },
          'meta': _meta,
        });
      case ('GET', '/notifications/unread-count'):
        return FakeAdapter.json(200, {
          'value': {'count': unread},
          'meta': _meta,
        });
      case ('PATCH', '/notifications/read-all'):
        return FakeAdapter.json(200, {
          'value': {'updated': unread},
          'meta': _meta,
        });
    }
    if (o.method == 'PATCH' && o.path.endsWith('/read')) {
      return FakeAdapter.json(200, {
        'value': {'eventId': 'x', 'readAt': '2026-01-01T00:00:00Z'},
        'meta': _meta,
      });
    }
    return FakeAdapter.json(404, {
      'code': 'COMMON.NOT_FOUND',
      'title': 'x',
      'status': 404,
    });
  }

  NotificationsApi get api =>
      NotificationsApi(ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter));
}

/// The signed-in account id the app would give; change it to sign in as
/// someone else (null = signed out).
class TestAccount extends Notifier<String?> {
  TestAccount(this.initial);

  final String? initial;

  @override
  String? build() => initial;

  void set(String? id) => state = id;
}

final testAccountProvider =
    NotifierProvider.family<TestAccount, String?, String?>(TestAccount.new);

/// Mounts [child] with the fake server behind `notificationsApiProvider`.
Future<ProviderContainer> pumpInbox(
  WidgetTester tester,
  FakeInbox server,
  Widget child, {
  String? account = 'acc_1',
  void Function(NotificationItem item)? onOpen,
}) async {
  final container = ProviderContainer(
    overrides: [
      notificationsApiProvider.overrideWithValue(server.api),
      notificationsAccountProvider.overrideWith(
        (ref) => ref.watch(testAccountProvider(account)),
      ),
      if (onOpen != null) notificationOpenProvider.overrideWithValue(onOpen),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
