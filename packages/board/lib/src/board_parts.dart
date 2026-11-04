import 'package:flutter/material.dart';

import 'board_labels.dart';

/// A failed read: the message and a button that reads again.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.labels, required this.onRetry});

  final BoardLabels labels;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labels.loadFailed),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: Text(labels.retry)),
          ],
        ),
      ),
    );
  }
}

/// Takes the place of the write button, the editor and the comment box when
/// the server wants an author id and the app gave no resolver.
class AuthorMissingNotice extends StatelessWidget {
  const AuthorMissingNotice({super.key, required this.labels});

  final BoardLabels labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(labels.authorMissing)),
        ],
      ),
    );
  }
}

/// `2026-01-31`, in the device's time zone.
String formatDate(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// Asks before a delete; true when the user agreed.
Future<bool> confirmDelete(
  BuildContext context,
  BoardLabels labels,
  String question,
) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(labels.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(labels.delete),
        ),
      ],
    ),
  );
  return agreed ?? false;
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
