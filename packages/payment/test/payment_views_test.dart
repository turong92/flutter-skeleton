import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

import 'support/fake_payment.dart';

Future<void> pump(WidgetTester tester, FakePayment server, Widget child) async {
  final container = ProviderContainer(
    overrides: [paymentApiProvider.overrideWithValue(server.api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

PaymentOrder order(String status) =>
    PaymentOrder.fromJson(orderJson('ord_1', status: status));

void main() {
  group('PaymentGate', () {
    testWidgets('shows the child and the test banner while in test mode', (tester) async {
      final server = FakePayment()..testMode = true;

      await pump(tester, server, const PaymentGate(child: Text('buy')));

      expect(find.text('buy'), findsOneWidget);
      expect(find.text(const PaymentLabels().testBanner), findsOneWidget);
    });

    testWidgets('has no banner outside test mode', (tester) async {
      final server = FakePayment()..testMode = false;

      await pump(tester, server, const PaymentGate(child: Text('buy')));

      expect(find.text('buy'), findsOneWidget);
      expect(find.text(const PaymentLabels().testBanner), findsNothing);
    });

    testWidgets('says payments are unavailable and hides the child', (tester) async {
      final server = FakePayment()..available = false;

      await pump(tester, server, const PaymentGate(child: Text('buy')));

      expect(find.text(const PaymentLabels().unavailable), findsOneWidget);
      expect(find.text('buy'), findsNothing);
    });

    testWidgets('the texts come from the labels', (tester) async {
      final server = FakePayment()..available = false;

      await pump(
        tester,
        server,
        const PaymentGate(
          labels: PaymentLabels(unavailable: 'Not now'),
          child: Text('buy'),
        ),
      );

      expect(find.text('Not now'), findsOneWidget);
    });
  });

  group('OrderListView', () {
    testWidgets('lists my orders and hands one over on tap', (tester) async {
      final server = FakePayment()
        ..orderPages = [
          [orderJson('a', status: 'PAID', orderName: 'First'), orderJson('b', status: 'REFUNDED', orderName: 'Second')],
        ];
      PaymentOrder? opened;

      await pump(tester, server, OrderListView(onOpen: (o) => opened = o));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text(const PaymentLabels().statuses['PAID']!), findsOneWidget);

      await tester.tap(find.text('Second'));

      expect(opened?.id, 'b');
    });

    testWidgets('a Load more button follows the cursor', (tester) async {
      final server = FakePayment()
        ..orderPages = [
          [orderJson('a', orderName: 'First')],
          [orderJson('b', orderName: 'Second')],
        ];
      await pump(tester, server, const OrderListView());

      await tester.tap(find.text(const PaymentLabels().loadMore));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
      expect(find.text(const PaymentLabels().loadMore), findsNothing);
    });

    testWidgets('an empty list says so', (tester) async {
      final server = FakePayment()..orderPages = [[]];

      await pump(tester, server, const OrderListView());

      expect(find.text(const PaymentLabels().empty), findsOneWidget);
    });

    testWidgets('a failed read shows a message and a retry that reads again', (tester) async {
      var failing = true;
      final server = FakePayment()
        ..orderPages = [
          [orderJson('a', orderName: 'First')],
        ]
        ..respond = (o) => failing && o.path == '/payments/orders'
            ? errorBody(500, 'COMMON.INTERNAL')
            : null;
      await pump(tester, server, const OrderListView());
      expect(find.text(const PaymentLabels().loadFailed), findsOneWidget);

      failing = false;
      await tester.tap(find.text(const PaymentLabels().retry));
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
    });
  });

  group('PaymentResultView', () {
    const labels = PaymentLabels();

    Future<void> show(WidgetTester tester, PurchaseResult result, {VoidCallback? onShowOrders}) =>
        pump(
          tester,
          FakePayment(),
          PaymentResultView(result: result, onDone: () {}, onShowOrders: onShowOrders),
        );

    testWidgets('paid', (tester) async {
      await show(tester, PurchasePaid(order('PAID')));

      expect(find.text(labels.paid), findsOneWidget);
    });

    testWidgets('still confirming points to the order history', (tester) async {
      var shown = false;
      await show(tester, PurchaseConfirming(order('CONFIRMING')), onShowOrders: () => shown = true);

      expect(find.text(labels.confirming), findsOneWidget);
      await tester.tap(find.text(labels.viewOrders));
      expect(shown, isTrue);
    });

    testWidgets('canceled', (tester) async {
      await show(tester, const PurchaseCanceled());

      expect(find.text(labels.canceled), findsOneWidget);
    });

    testWidgets('a decline picks its text by category', (tester) async {
      await show(
        tester,
        const PurchaseDeclined(category: 'LIMIT_OR_BALANCE', providerCode: 'X'),
      );

      expect(find.text(labels.declined['LIMIT_OR_BALANCE']!), findsOneWidget);
      expect(find.textContaining('X'), findsNothing); // the provider code is not shown
    });

    testWidgets('a category it does not know falls back to OTHER', (tester) async {
      await show(tester, const PurchaseDeclined(category: 'SOMETHING_NEW'));

      expect(find.text(labels.declined['OTHER']!), findsOneWidget);
    });

    testWidgets('unavailable, unsupported and failed have their texts', (tester) async {
      await show(tester, const PurchaseUnavailable());
      expect(find.text(labels.unavailable), findsOneWidget);

      await show(tester, const PurchaseUnsupported('PADDLE_OVERLAY'));
      expect(find.text(labels.unsupported), findsOneWidget);

      await show(tester, const PurchaseFailed('X'));
      expect(find.text(labels.failed), findsOneWidget);
    });
  });
}
