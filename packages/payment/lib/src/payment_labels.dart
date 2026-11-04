import 'models.dart';

/// The texts of the payment widgets. The package does not translate: the app
/// passes its own (defaults are English).
class PaymentLabels {
  const PaymentLabels({
    this.unavailable = 'Payments are unavailable right now.',
    this.testBanner = 'Test payment: no real money moves.',
    this.empty = 'No payments yet.',
    this.loadFailed = 'Could not load.',
    this.retry = 'Try again',
    this.loadMore = 'Load more',
    this.paid = 'Payment complete.',
    this.confirming = 'Still checking this payment. See your payment history.',
    this.canceled = 'Payment canceled.',
    this.failed = 'The payment did not go through.',
    this.unsupported = 'This payment method is not supported in this app.',
    this.declined = const {
      'LIMIT_OR_BALANCE':
          'The card limit or balance is too low. Try another card.',
      'CARD_DECLINED':
          'The card company did not accept the payment. Ask the card company or try another card.',
      'TEMPORARY': 'Something went wrong for a moment. Try again later.',
      'OTHER': 'The payment did not finish. Try again.',
    },
    this.done = 'Done',
    this.viewOrders = 'View payment history',
    this.close = 'Close',
    this.statuses = const {
      'PENDING': 'Not paid',
      'CONFIRMING': 'Checking',
      'PAID': 'Paid',
      'PARTIALLY_REFUNDED': 'Partly refunded',
      'REFUNDED': 'Refunded',
      'FAILED': 'Failed',
      'EXPIRED': 'Expired',
      'CANCELED': 'Canceled',
    },
    this.formatMoney = _plainMoney,
  });

  /// Shown instead of the purchase UI when the server says it cannot take
  /// payments.
  final String unavailable;

  /// The strip that stays on while the provider keys are test keys.
  final String testBanner;
  final String empty;
  final String loadFailed;
  final String retry;
  final String loadMore;
  final String paid;

  /// Money may have moved but the server has not said so yet.
  final String confirming;
  final String canceled;
  final String failed;

  /// The server asked for a payment window this package does not open.
  final String unsupported;

  /// Decline category (`LIMIT_OR_BALANCE`, `CARD_DECLINED`, `TEMPORARY`,
  /// `OTHER`) to words. A category not in the map reads `OTHER`.
  final Map<String, String> declined;
  final String done;
  final String viewOrders;

  /// Label of the close button of the payment window.
  final String close;

  /// Order status to words. A status not in the map is shown as it is.
  final Map<String, String> statuses;
  final String Function(Money) formatMoney;
}

String _plainMoney(Money money) => '${money.amount} ${money.currency}';
