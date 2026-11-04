import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_payment/skeleton_payment.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../config.dart';

/// One demo item (`cheer-3000` of the kotlin sample server) and the payment
/// history. The item is a demonstration: a digital good sold inside a store
/// app has to go through the store's in-app purchase (see the README).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _paying = false;

  /// A new key re-reads the history after a purchase.
  int _historyVersion = 0;

  Future<void> _pay() async {
    setState(() => _paying = true);
    final result = await purchase(
      api: ref.read(paymentApiProvider),
      itemType: 'cheer',
      itemRef: 'cheer-3000',
      launch: (checkout) => showTossCheckout(
        context,
        checkout,
        successUrl: AppConfig.paymentSuccessUrl,
        failUrl: AppConfig.paymentFailUrl,
      ),
    );
    if (!mounted) return;
    setState(() {
      _paying = false;
      _historyVersion++;
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Payment')),
          body: PaymentResultView(
            result: result,
            onDone: () => Navigator.of(context).pop(),
            onShowOrders: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: PaymentGate(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(SkeletonSpace.md),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(SkeletonSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cheer 3,000 KRW',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: SkeletonSpace.xs),
                      const Text('A demo item of the sample server.'),
                      const SizedBox(height: SkeletonSpace.md),
                      FilledButton(
                        onPressed: _paying ? null : _pay,
                        child: const Text('Pay 3,000 KRW'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SkeletonSpace.md),
              child: Text(
                'My payments',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(child: OrderListView(key: ValueKey(_historyVersion))),
          ],
        ),
      ),
    );
  }
}
