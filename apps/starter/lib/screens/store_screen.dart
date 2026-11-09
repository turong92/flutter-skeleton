// #file iap
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import '../l10n/l10n.dart';

/// The subscription of the account as the server has it. Read again after the
/// server granted a purchase; the package opens nothing itself.
final mySubscriptionProvider = FutureProvider.autoDispose<IapSubscription?>(
  (ref) => ref.watch(iapApiProvider).mySubscription(),
);

/// What a person is told about the server's answer to a purchase.
String iapOutcomeText(AppLocalizations l, IapOutcome outcome) =>
    switch (outcome) {
      IapGranted() => l.purchaseConfirmed,
      IapRejected() => l.purchaseRefused(outcome.code),
      IapNotConfirmed(reason: IapWait.storePending) => l.purchaseStorePending,
      IapNotConfirmed(reason: IapWait.otherAccount) => l.purchaseOtherAccount,
      IapNotConfirmed(reason: IapWait.retryLater) => l.purchaseRetryLater,
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
      appBar: AppBar(title: Text(context.l10n.storeTitle)),
      body: catalog.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          message: context.l10n.productsLoadFailed,
          onRetry: () => ref.invalidate(iapCatalogProvider),
        ),
        data: (data) => data == null
            ? Center(child: Text(context.l10n.purchasesNotAvailable))
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
    // What was bought once and kept: shown as bought, not as something to buy.
    final entitlements = ref.watch(iapEntitlementsProvider).forThisAccount;
    // A server that sells on the web only has no store purchase to offer.
    final storeSells = catalog.config.channel != IapChannel.webOnly;
    return ListView(
      padding: const EdgeInsets.all(SkeletonSpace.md),
      children: [
        if (storeSells) ...[
          Text(
            context.l10n.products,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (catalog.offers.isEmpty)
            ListTile(title: Text(context.l10n.nothingToBuy)),
          for (final offer in catalog.offers)
            ListTile(
              title: Text(offer.details.title),
              subtitle: Text(offer.details.description),
              trailing:
                  !offer.product.consumable &&
                      entitlements != null &&
                      entitlements.owns(
                        offer.product.itemType ?? '',
                        offer.product.itemRef ?? '',
                      )
                  ? Chip(label: Text(context.l10n.purchased))
                  : FilledButton(
                      onPressed: service == null
                          ? null
                          : () async {
                              try {
                                await service.buy(offer);
                              } on Object {
                                if (context.mounted) {
                                  _say(
                                    context,
                                    context.l10n.startPurchaseFailed,
                                  );
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
                        _say(context, context.l10n.restoreFailed);
                      }
                    }
                  },
            child: Text(context.l10n.restorePurchases),
          ),
        ],
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
                        _say(context, context.l10n.webCheckoutFailed);
                      }
                    }
                  },
            child: Text(context.l10n.payOnWeb),
          ),
        ],
        const Divider(height: SkeletonSpace.xl),
        Text(
          context.l10n.mySubscription,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subscription.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              ListTile(title: Text(context.l10n.subscriptionLoadFailed)),
          data: (value) => ListTile(
            title: Text(
              value == null
                  ? context.l10n.noSubscription
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
