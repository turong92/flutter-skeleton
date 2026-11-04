import 'dart:convert';

import 'models.dart';

// JS string escapes for < and > (a backslash, then u003c / u003e).
final _lt = String.fromCharCodes([0x5c, 0x75, 0x30, 0x30, 0x33, 0x63]);
final _gt = String.fromCharCodes([0x5c, 0x75, 0x30, 0x30, 0x33, 0x65]);

/// The page the payment window loads: Toss's JS SDK v2 and one call that opens
/// the window for [checkout]. The provider sends the buyer to [successUrl] or
/// [failUrl] afterwards; the app stops the window on the way there (see
/// `classifyCheckoutNavigation`), so those addresses are never really opened.
///
/// Every value is written as a JSON string with `<` escaped, so an order name
/// cannot close the script tag.
String tossCheckoutHtml(
  Checkout checkout, {
  required Uri successUrl,
  required Uri failUrl,
  String method = 'CARD',
}) {
  String js(Object? value) =>
      jsonEncode(value).replaceAll('<', _lt).replaceAll('>', _gt);
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://js.tosspayments.com/v2/standard"></script>
</head>
<body>
<script>
  var tossPayments = TossPayments(${js(checkout.clientKey)});
  var payment = tossPayments.payment({ customerKey: TossPayments.ANONYMOUS });
  payment.requestPayment({
    method: ${js(method)},
    amount: { currency: ${js(checkout.amount.currency)}, value: ${checkout.amount.amount} },
    orderId: ${js(checkout.orderId)},
    orderName: ${js(checkout.orderName)},
    successUrl: ${js(successUrl.toString())},
    failUrl: ${js(failUrl.toString())}
  });
</script>
</body>
</html>
''';
}
