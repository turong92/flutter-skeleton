import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'checkout_navigation.dart';
import 'models.dart';
import 'payment_gate.dart';
import 'payment_labels.dart';
import 'toss_checkout_html.dart';

/// Opens [uri] outside the app; false when nothing could take it.
typedef ExternalOpener = Future<bool> Function(Uri uri);

Future<bool> _openOutside(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// The Toss payment window in a WebView. Thin on purpose: what to do with an
/// address is decided by [classifyCheckoutNavigation]. Pops with the
/// [CheckoutReturn] read off the return address, or null when the buyer closes
/// the window.
///
/// [successUrl] and [failUrl] are never really opened: the window is stopped on
/// the way there. [baseUrl] is the origin the page is loaded under (the origin
/// of [successUrl] when null).
///
/// Not checked on a device: whether the SDK page shows the window when loaded
/// from a string, and whether card apps open (see README).
class TossCheckoutPage extends StatefulWidget {
  const TossCheckoutPage({
    super.key,
    required this.checkout,
    required this.successUrl,
    required this.failUrl,
    this.baseUrl,
    this.labels = const PaymentLabels(),
    this.openExternal = _openOutside,
  });

  final Checkout checkout;
  final Uri successUrl;
  final Uri failUrl;
  final Uri? baseUrl;
  final PaymentLabels labels;
  final ExternalOpener openExternal;

  @override
  State<TossCheckoutPage> createState() => _TossCheckoutPageState();
}

class _TossCheckoutPageState extends State<TossCheckoutPage> {
  bool _done = false;

  void _finish(CheckoutReturn? result) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(result);
  }

  Future<NavigationActionPolicy> _decide(String url) async {
    final nav = classifyCheckoutNavigation(
      url,
      successUrl: widget.successUrl,
      failUrl: widget.failUrl,
    );
    switch (nav) {
      case NavigationLoad():
        return NavigationActionPolicy.ALLOW;
      case NavigationReturn(:final result):
        _finish(result);
      case NavigationOpenIntent(:final launch):
        final opened = await widget.openExternal(launch.appUri);
        if (!opened && launch.marketUri != null) {
          await widget.openExternal(launch.marketUri!);
        }
      case NavigationOpenExternal(:final uri):
        await widget.openExternal(uri);
      case NavigationBlock():
        break;
    }
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseUrl ?? widget.successUrl.replace(path: '/', query: '');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.checkout.orderName),
        leading: IconButton(
          tooltip: widget.labels.close,
          icon: const Icon(Icons.close),
          onPressed: () => _finish(null),
        ),
      ),
      body: Column(
        children: [
          if (widget.checkout.testMode) TestPaymentBanner(labels: widget.labels),
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: tossCheckoutHtml(
                  widget.checkout,
                  successUrl: widget.successUrl,
                  failUrl: widget.failUrl,
                ),
                baseUrl: WebUri.uri(base),
              ),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
              ),
              shouldOverrideUrlLoading: (controller, action) =>
                  _decide(action.request.url?.toString() ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [TossCheckoutPage] as a full-screen route and answers like a
/// [CheckoutLauncher]: `(c) => showTossCheckout(context, c, successUrl: …, failUrl: …)`.
Future<CheckoutReturn?> showTossCheckout(
  BuildContext context,
  Checkout checkout, {
  required Uri successUrl,
  required Uri failUrl,
  Uri? baseUrl,
  PaymentLabels labels = const PaymentLabels(),
}) => Navigator.of(context).push<CheckoutReturn>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TossCheckoutPage(
      checkout: checkout,
      successUrl: successUrl,
      failUrl: failUrl,
      baseUrl: baseUrl,
      labels: labels,
    ),
  ),
);
