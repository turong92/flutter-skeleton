import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_payment/skeleton_payment.dart';

final _success = Uri.parse('https://checkout.example.com/pay/success');
final _fail = Uri.parse('https://checkout.example.com/pay/fail');

CheckoutNavigation classify(String url) =>
    classifyCheckoutNavigation(url, successUrl: _success, failUrl: _fail);

void main() {
  group('the return addresses', () {
    test('the success address is caught before it loads and read', () {
      final nav = classify(
        'https://checkout.example.com/pay/success'
        '?paymentKey=pk_1&orderId=ord_1&amount=3000',
      );

      final returned = (nav as NavigationReturn).result;
      expect(
        returned,
        isA<CheckoutSucceeded>()
            .having((r) => r.paymentKey, 'paymentKey', 'pk_1')
            .having((r) => r.orderId, 'orderId', 'ord_1')
            .having((r) => r.amount, 'amount', 3000),
      );
    });

    test('a success address without a whole-number amount is a failure', () {
      for (final query in [
        'paymentKey=pk_1&orderId=ord_1',
        'paymentKey=pk_1&orderId=ord_1&amount=30.5',
        'paymentKey=pk_1&amount=3000',
        'orderId=ord_1&amount=3000',
      ]) {
        final nav = classify('https://checkout.example.com/pay/success?$query');

        expect(
          (nav as NavigationReturn).result,
          isA<CheckoutFailed>().having((r) => r.code, 'code', 'INVALID_RETURN'),
          reason: query,
        );
      }
    });

    test('the fail address carries the code and the order', () {
      final nav = classify(
        'https://checkout.example.com/pay/fail'
        '?code=PAY_PROCESS_CANCELED&message=x&orderId=ord_1',
      );

      expect(
        (nav as NavigationReturn).result,
        isA<CheckoutFailed>()
            .having((r) => r.code, 'code', 'PAY_PROCESS_CANCELED')
            .having((r) => r.orderId, 'orderId', 'ord_1'),
      );
    });

    test('another host or path with the same query is not a return', () {
      expect(
        classify(
          'https://evil.example.org/pay/success?paymentKey=a&orderId=b&amount=1',
        ),
        isA<NavigationLoad>(),
      );
      expect(
        classify('https://checkout.example.com/pay/success/more?paymentKey=a'),
        isA<NavigationLoad>(),
      );
    });
  });

  group('other addresses', () {
    test('web pages and blank pages load in the window', () {
      for (final url in [
        'https://pay.toss.im/x',
        'http://example.com',
        'about:blank',
        'data:text/html,hi',
        'blob:https://x/1',
      ]) {
        expect(classify(url), isA<NavigationLoad>(), reason: url);
      }
    });

    test('market:// opens outside', () {
      final nav = classify('market://details?id=com.kakao.talk');

      expect(
        nav,
        isA<NavigationOpenExternal>().having(
          (n) => n.uri.toString(),
          'uri',
          'market://details?id=com.kakao.talk',
        ),
      );
    });

    test('a card app scheme opens outside', () {
      final nav = classify('ispmobile://TID=abc');

      expect(
        nav,
        isA<NavigationOpenExternal>().having(
          (n) => n.uri.scheme,
          'scheme',
          'ispmobile',
        ),
      );
    });

    test('file and content addresses are blocked', () {
      expect(classify('file:///data/x'), isA<NavigationBlock>());
      expect(classify('content://x/y'), isA<NavigationBlock>());
    });
  });

  group('intent://', () {
    test('turns into the app scheme with a market address for the package', () {
      final nav = classify(
        'intent://pay?srCode=123&packageName=net.ib.android.smcard'
        '#Intent;scheme=shinhan-sr-ansimclick;package=com.shcard.smartpay;end',
      );

      final launch = (nav as NavigationOpenIntent).launch;
      expect(
        launch.appUri.toString(),
        'shinhan-sr-ansimclick://pay?srCode=123&packageName=net.ib.android.smcard',
      );
      expect(
        launch.marketUri.toString(),
        'market://details?id=com.shcard.smartpay',
      );
    });

    test('an intent with an empty body keeps the scheme alone', () {
      final launch = (classify(
        'intent://#Intent;scheme=ispmobile;package=kvp.jjy.MispAndroid320;end',
      ) as NavigationOpenIntent).launch;

      expect(launch.appUri.toString(), 'ispmobile://');
      expect(
        launch.marketUri.toString(),
        'market://details?id=kvp.jjy.MispAndroid320',
      );
    });

    test('extras after the scheme and package are ignored', () {
      final launch = (classify(
        'intent://kb?x=1#Intent;scheme=kb-acp;'
        'S.browser_fallback_url=https%3A%2F%2Fexample.com;'
        'package=com.kbcard.cxh.appcard;end',
      ) as NavigationOpenIntent).launch;

      expect(launch.appUri.toString(), 'kb-acp://kb?x=1');
      expect(
        launch.marketUri.toString(),
        'market://details?id=com.kbcard.cxh.appcard',
      );
    });

    test('without a package there is no market address', () {
      final launch = (classify(
        'intent://x#Intent;scheme=kakaotalk;end',
      ) as NavigationOpenIntent).launch;

      expect(launch.appUri.toString(), 'kakaotalk://x');
      expect(launch.marketUri, isNull);
    });

    test('an intent that is not http-like and has no scheme is blocked', () {
      expect(
        classify('intent://x#Intent;package=a.b;end'),
        isA<NavigationBlock>(),
      );
      expect(classify('intent://x'), isA<NavigationBlock>());
    });

    test('an intent that names a web scheme is blocked', () {
      expect(
        classify('intent://evil#Intent;scheme=https;package=a.b;end'),
        isA<NavigationBlock>(),
      );
      expect(
        classify('intent://x#Intent;scheme=file;end'),
        isA<NavigationBlock>(),
      );
    });
  });
}
