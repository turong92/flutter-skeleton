import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'payment_labels.dart';
import 'payment_providers.dart';

/// "My payments": newest first, a Load more button follows the cursor, pull
/// down to read again. [onOpen] gets the tapped order (the app decides where
/// that goes).
class OrderListView extends ConsumerStatefulWidget {
  const OrderListView({
    super.key,
    this.onOpen,
    this.labels = const PaymentLabels(),
  });

  final void Function(PaymentOrder order)? onOpen;
  final PaymentLabels labels;

  @override
  ConsumerState<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends ConsumerState<OrderListView> {
  List<PaymentOrder>? _items;
  String? _next;
  bool _failed = false;
  bool _loadingMore = false;
  bool _moreFailed = false;

  PaymentLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() => _failed = false);
    try {
      final page = await ref.read(paymentApiProvider).myOrders();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _next = page.nextCursor;
        _moreFailed = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await ref.read(paymentApiProvider).myOrders(cursor: _next);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, ...page.items];
        _next = page.nextCursor;
        _loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      if (_failed) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_labels.loadFailed),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _loadFirst, child: Text(_labels.retry)),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) return Center(child: Text(_labels.empty));
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final order in items)
            ListTile(
              title: Text(order.orderName),
              subtitle: Text(_labels.statuses[order.status] ?? order.status),
              trailing: Text(_labels.formatMoney(order.amount)),
              onTap: widget.onOpen == null ? null : () => widget.onOpen!(order),
            ),
          if (_next != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_moreFailed) Text(_labels.loadFailed),
                  OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_labels.loadMore),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
