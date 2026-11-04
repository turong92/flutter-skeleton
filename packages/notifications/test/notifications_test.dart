import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';

import 'support/fake_inbox.dart';

void main() {
  test('the api reads the inbox with the contract paths and fields', () async {
    final server = FakeInbox()
      ..pages = [
        [itemJson('a', link: '/board/7', collapsedCount: 3)],
      ];

    final page = await server.api.list(unreadOnly: true);
    final count = await server.api.unreadCount();
    await server.api.markRead('ev a/b');
    final updated = await server.api.markAllRead();

    expect(page.items.single.link, '/board/7');
    expect(page.items.single.collapsedCount, 3);
    expect(page.items.single.readAt, isNull);
    expect(page.items.single.payload['postId'], 7);
    expect(count, 2);
    expect(updated, 2);
    final list = server.where('GET', '/notifications').single;
    expect(list.queryParameters['page'], 0);
    expect(list.queryParameters['unreadOnly'], true);
    expect(server.adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /notifications',
      'GET /notifications/unread-count',
      'PATCH /notifications/ev%20a%2Fb/read',
      'PATCH /notifications/read-all',
    ]);
  });

  test('only an app path is a link; another site is dropped', () {
    expect(safeNotificationLink('/board/7'), '/board/7');
    expect(safeNotificationLink('//evil.example.com'), isNull);
    expect(safeNotificationLink('/\\evil.example.com'), isNull);
    expect(safeNotificationLink('https://example.com/x'), isNull);
    expect(safeNotificationLink('javascript:alert(1)'), isNull);
    expect(safeNotificationLink('/a\nb'), isNull);
    expect(safeNotificationLink(null), isNull);
  });

  testWidgets('a row is marked read by its own eventId, not its id', (
    tester,
  ) async {
    final server = FakeInbox()
      ..pages = [
        [itemJson('row-1', eventId: 'first-event', collapsedCount: 2)],
      ];
    NotificationItem? opened;
    await pumpInbox(
      tester,
      server,
      const NotificationListView(),
      onOpen: (item) => opened = item,
    );

    await tester.tap(find.text('title row-1'));
    await tester.pumpAndSettle();

    expect(
      server.where('PATCH', '/notifications/first-event/read'),
      hasLength(1),
    );
    expect(opened?.id, 'row-1');
  });

  testWidgets('a page that slides while paging does not repeat a row', (
    tester,
  ) async {
    final server = FakeInbox()
      ..pages = [
        [itemJson('a'), itemJson('b')],
        [itemJson('b'), itemJson('c')],
      ];
    await pumpInbox(tester, server, const NotificationListView());

    expect(find.text('title a'), findsOneWidget);
    expect(find.text('title b'), findsOneWidget);
    expect(find.text('title c'), findsOneWidget);
  });

  testWidgets('another account never sees the previous list', (tester) async {
    final server = FakeInbox();
    final container = await pumpInbox(
      tester,
      server,
      const NotificationListView(),
    );
    expect(find.text('title a'), findsOneWidget);

    server.pages = [[]];
    container.read(testAccountProvider('acc_1').notifier).set('acc_2');
    await tester.pump();

    expect(find.text('title a'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('title a'), findsNothing);
  });

  test('a list invalidated while the next page loads raises nothing', () async {
    final server = FakeInbox()
      ..pages = [
        [itemJson('a')],
        [itemJson('b')],
      ];
    final container = ProviderContainer(
      overrides: [
        notificationsApiProvider.overrideWithValue(server.api),
        notificationsAccountProvider.overrideWithValue('acc_1'),
      ],
    );
    addTearDown(container.dispose);
    final provider = notificationListProvider('acc_1');
    container.listen(provider, (_, _) {});
    await container.read(provider.future);

    final loading = container.read(provider.notifier).loadMore();
    container.invalidate(provider);
    final fresh = container.read(provider.future);

    await loading;
    await fresh;
    // the late page is dropped: the list is the freshly read first page
    expect(container.read(provider).requireValue.items.map((i) => i.id), ['a']);
    expect(container.read(provider).requireValue.loadingMore, false);
  });

  testWidgets('signed out, nothing is called', (tester) async {
    final server = FakeInbox();
    await pumpInbox(
      tester,
      server,
      Column(
        children: const [
          UnreadBadge(child: Icon(Icons.notifications)),
          Expanded(child: NotificationListView()),
        ],
      ),
      account: null,
    );

    expect(server.adapter.requests, isEmpty);
  });
}
