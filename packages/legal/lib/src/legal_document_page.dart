import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'legal_labels.dart';
import 'legal_providers.dart';

/// One document, its markdown source as plain selectable text (a renderer
/// comes later). [version] null = the current one.
class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({
    super.key,
    required this.type,
    this.version,
    this.locale,
    this.labels = const LegalLabels(),
  });

  final String type;
  final String? version;
  final String? locale;
  final LegalLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (type: type, version: version, locale: locale);
    final document = ref.watch(legalDocumentProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(document.value?.title ?? '')),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labels.loadFailed),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(legalDocumentProvider(key)),
                child: Text(labels.retry),
              ),
            ],
          ),
        ),
        data: (document) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(document.markdown),
        ),
      ),
    );
  }
}
