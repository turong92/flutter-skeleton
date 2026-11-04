import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

/// The subscription of the account as the server has it. Read again after the
/// server granted a purchase; the package opens nothing itself.
final mySubscriptionProvider = FutureProvider.autoDispose<IapSubscription?>(
  (ref) => ref.watch(iapApiProvider).mySubscription(),
);

/// What a person is told about the server's answer to a purchase.
String iapOutcomeText(IapOutcome outcome) => switch (outcome) {
  IapGranted() => 'Purchase confirmed.',
  IapRejected() => 'The purchase was refused (${outcome.code}).',
  IapNotConfirmed(reason: IapWait.storePending) =>
    'The store has not finished the payment yet.',
  IapNotConfirmed(reason: IapWait.otherAccount) =>
    'This purchase belongs to another account. Sign in with that one.',
  IapNotConfirmed(reason: IapWait.retryLater) => 'Could not confirm the purchase yet. It stays open and is sent again the next time the app starts.',
  IapStoreError() => outcome.message,
};

/// Products to buy, restore, the web checkout (only when the server's channel
/// has the web) and the subscription the server knows.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(iapCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: catalog.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          message: 'Could not load the products.',
          onRetry: () => ref.invalidate(iapCatalogProvider),
        ),
        data: (data) => data == null
            ? const Center(
                child: Text('Purchases are not available on this device.'),
              )
            : _StoreList(catalog: data),
      ),
    );
  }
}

class _StoreList extends ConsumerWidget {
  const _StoreList({required this.catalog});

  final IapCatalog catalog;

  void _say(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(iapServiceProvider);
    final subscription = ref.watch(mySubscriptionProvider);
    return ListView(
      padding: const EdgeInsets.all(SkeletonSpace.md),
      children: [
        Text('Products', style: Theme.of(context).textTheme.titleMedium),
        if (catalog.offers.isEmpty)
          const ListTile(title: Text('Nothing to buy right now.')),
        for (final offer in catalog.offers)
          ListTile(
            title: Text(offer.details.title),
            subtitle: Text(offer.details.description),
            trailing: FilledButton(
              onPressed: service == null
                  ? null
                  : () async {
                      try {
                        await service.buy(offer);
                      } on Object {
                        if (context.mounted) {
                          _say(context, 'Could not start the purchase.');
                        }
                      }
                    },
              child: Text(offer.details.price),
            ),
          ),
        const SizedBox(height: SkeletonSpace.sm),
        OutlinedButton(
          onPressed: service == null
              ? null
              : () async {
                  try {
                    await service.restore(catalog);
                  } on Object {
                    if (context.mounted) {
                      _say(context, 'Could not restore purchases.');
                    }
                  }
                },
          child: const Text('Restore purchases'),
        ),
        if (catalog.config.showsWebCheckout) ...[
          const SizedBox(height: SkeletonSpace.sm),
          OutlinedButton(
            onPressed: service == null
                ? null
                : () async {
                    try {
                      await service.openWebCheckout();
                    } on Object {
                      // The address holds a sign-in code; nothing of the
                      // error is shown.
                      if (context.mounted) {
                        _say(context, 'Could not open the web checkout.');
                      }
                    }
                  },
            child: const Text('Pay on the web'),
          ),
        ],
        const Divider(height: SkeletonSpace.xl),
        Text('My subscription', style: Theme.of(context).textTheme.titleMedium),
        subscription.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              const ListTile(title: Text('Could not load your subscription.')),
          data: (value) => ListTile(
            title: Text(
              value == null
                  ? 'No subscription.'
                  : (value.planName ?? value.planCode),
            ),
            subtitle: value == null
                ? null
                : Text(
                    '${value.status}'
                    '${value.provider == null ? '' : ' - ${value.provider}'}',
                  ),
          ),
        ),
      ],
    );
  }
}
