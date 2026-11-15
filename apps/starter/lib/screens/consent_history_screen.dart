import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

import '../l10n/l10n.dart';

/// `/account/consents`: what the person agreed to and withdrew, newest first.
class ConsentHistoryScreen extends StatelessWidget {
  const ConsentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = context.byLocale(
      const LegalLabels.ko(),
      const LegalLabels(),
    );
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/account')),
        title: Text(labels.history),
      ),
      body: ConsentHistoryView(labels: labels),
    );
  }
}
