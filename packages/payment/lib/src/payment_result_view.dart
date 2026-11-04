import 'package:flutter/material.dart';

import 'payment_labels.dart';
import 'purchase.dart';

/// The words for how a [PurchaseResult] ended, and the buttons to leave.
/// [onShowOrders] is offered when the result is still being checked; leave it
/// null to hide that button.
class PaymentResultView extends StatelessWidget {
  const PaymentResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.onShowOrders,
    this.labels = const PaymentLabels(),
  });

  final PurchaseResult result;
  final VoidCallback onDone;
  final VoidCallback? onShowOrders;
  final PaymentLabels labels;

  String _message() => switch (result) {
    PurchasePaid() => labels.paid,
    PurchaseConfirming() => labels.confirming,
    PurchaseCanceled() => labels.canceled,
    PurchaseDeclined(:final category) =>
      labels.declined[category] ?? labels.declined['OTHER'] ?? labels.failed,
    PurchaseUnavailable() => labels.unavailable,
    PurchaseUnsupported() => labels.unsupported,
    PurchaseFailed() => labels.failed,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_message(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (result is PurchaseConfirming && onShowOrders != null) ...[
              FilledButton(
                onPressed: onShowOrders,
                child: Text(labels.viewOrders),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(onPressed: onDone, child: Text(labels.done)),
          ],
        ),
      ),
    );
  }
}
