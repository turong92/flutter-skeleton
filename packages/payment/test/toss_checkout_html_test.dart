import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

Checkout checkout({String orderName = 'Cheer 3,000'}) => Checkout(
  provider: 'toss',
  kind: 'TOSS_PAYMENT_WINDOW',
  clientKey: 'test_ck_public_docs_key',
  testMode: true,
  orderId: 'ord_1',
  orderName: orderName,
  amount: const Money(amount: 3000, currency: 'KRW'),
);

void main() {
  final success = Uri.parse('https://checkout.example.com/pay/success');
  final fail = Uri.parse('https://checkout.example.com/pay/fail');

  test('loads the v2 SDK and asks for the payment of the order', () {
    final html = tossCheckoutHtml(
      checkout(),
      successUrl: success,
      failUrl: fail,
    );

    expect(html, contains('https://js.tosspayments.com/v2/standard'));
    expect(html, contains('"test_ck_public_docs_key"'));
    expect(html, contains('"ord_1"'));
    expect(html, contains('"https://checkout.example.com/pay/success"'));
    expect(html, contains('"https://checkout.example.com/pay/fail"'));
    expect(html, contains('3000'));
    expect(html, contains('"KRW"'));
  });

  test('a name that tries to close the script cannot', () {
    final html = tossCheckoutHtml(
      checkout(orderName: '</script><script>alert(1)</script>'),
      successUrl: success,
      failUrl: fail,
    );

    expect(html, isNot(contains('</script><script>alert')));
    expect(RegExp('</script>').allMatches(html), hasLength(2));
  });
}
