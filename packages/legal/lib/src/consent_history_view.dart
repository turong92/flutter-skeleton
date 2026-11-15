import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'legal_labels.dart';
import 'legal_providers.dart';
import 'models.dart';

/// The caller's own consent history, newest first: which document, agreed or
/// withdrawn, the version and the time (shown in the device's time zone). Twin
/// of the history in the web `ConsentSettings`. Pages are read on request
/// ("Load more"). Put it in a screen of its own (a settings entry opens it).
class ConsentHistoryView extends ConsumerStatefulWidget {
  const ConsentHistoryView({
    super.key,
    this.labels = const LegalLabels(),
    this.pageSize = 20,
  });

  final LegalLabels labels;
  final int pageSize;

  @override
  ConsumerState<ConsentHistoryView> createState() => _ConsentHistoryViewState();
}

class _ConsentHistoryViewState extends ConsumerState<ConsentHistoryView> {
  final _events = <ConsentEvent>[];
  PageInfo? _last;
  bool _loading = true;
  bool _failed = false;

  LegalLabels get labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _read(0);
  }

  Future<void> _read(int page) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await ref
          .read(legalApiProvider)
          .history(page: page, size: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _events.addAll(result.items);
        _last = result.pagination;
        _loading = false;
      });
    } on ApiRequestError {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// The title of a document in the person's language, else any language, else
  /// the type itself (the documents list is only for the titles).
  String _titleOf(String type) {
    final documents = ref.watch(legalDocumentsProvider).value ?? const [];
    final language = Localizations.localeOf(context).languageCode;
    final ofType = documents.where((d) => d.type == type);
    final pick =
        ofType.where((d) => d.locale == language).firstOrNull ??
        ofType.firstOrNull;
    return pick?.title ?? type;
  }

  static String _when(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty && _failed) return _failure();
    if (_events.isEmpty) return Center(child: Text(labels.historyEmpty));
    return ListView(
      children: [
        for (final e in _events)
          ListTile(
            title: Text(_titleOf(e.type)),
            subtitle: Text(
              '${e.withdrawn ? labels.historyWithdrawn : labels.historyAgreed}, '
              '${_when(e.at)}',
            ),
            trailing: Text(e.version),
          ),
        if (_failed) _failure(),
        if (_last?.hasNext ?? false)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: _loading ? null : () => _read(_last!.page + 1),
              child: Text(labels.loadMore),
            ),
          ),
      ],
    );
  }

  Widget _failure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels.historyLoadFailed),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _read(_last == null ? 0 : _last!.page + 1),
            child: Text(labels.retry),
          ),
        ],
      ),
    ),
  );
}
