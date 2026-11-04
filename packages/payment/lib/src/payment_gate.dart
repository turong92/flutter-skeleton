import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payment_labels.dart';
import 'payment_providers.dart';

/// The strip that marks test payments. Outlined, not just tinted.
class TestPaymentBanner extends StatelessWidget {
  const TestPaymentBanner({super.key, this.labels = const PaymentLabels()});

  final PaymentLabels labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        border: Border.all(color: scheme.tertiary),
      ),
      child: Text(
        labels.testBanner,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

/// Wraps the purchase UI: shows [child] when the server can take payments (with
/// the test strip on top while the keys are test keys), otherwise only the
/// "unavailable" text. While the config loads, or when it cannot be read, the
/// child is shown: the purchase itself reports a real failure.
class PaymentGate extends ConsumerWidget {
  const PaymentGate({
    super.key,
    required this.child,
    this.labels = const PaymentLabels(),
  });

  final Widget child;
  final PaymentLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(paymentConfigProvider).value;
    if (config != null && !config.available) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(labels.unavailable, textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (config?.testMode ?? false) TestPaymentBanner(labels: labels),
        Expanded(child: child),
      ],
    );
  }
}
