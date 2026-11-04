import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'consent_tile.dart';
import 'legal_document_page.dart';
import 'legal_labels.dart';
import 'legal_providers.dart';
import 'models.dart';
import 'reconsent.dart';

/// The screen behind the `/consent` route: the documents in
/// [reconsentProvider] with a box each, and one button that agrees to them
/// (`POST /legal/consents`). When nothing is missing any more the state clears
/// and the router's [reconsentRedirect] takes the user back to where they were
/// going; this screen does not navigate.
class ReconsentScreen extends ConsumerStatefulWidget {
  const ReconsentScreen({
    super.key,
    this.locale,
    this.labels = const LegalLabels(),
    this.onLeave,
  });

  static Key checkKey(String type) =>
      Key('skeleton_legal.reconsent.check.$type');
  static Key viewKey(String type) => Key('skeleton_legal.reconsent.view.$type');
  static const agreeKey = Key('skeleton_legal.reconsent.agree');
  static const leaveKey = Key('skeleton_legal.reconsent.leave');

  final String? locale;
  final LegalLabels labels;

  /// The way out for someone who will not agree (sign out). This package does
  /// not know the session, so the app passes it; without it there is no button.
  final VoidCallback? onLeave;

  @override
  ConsumerState<ReconsentScreen> createState() => _ReconsentScreenState();
}

class _ReconsentScreenState extends ConsumerState<ReconsentScreen> {
  /// `type/version`: a document with a newer version starts unchecked.
  final _checked = <String>{};
  var _busy = false;
  var _failed = false;

  static String _id(MissingConsent m) => '${m.type}/${m.version}';

  LegalDocumentRef _ref(MissingConsent m) =>
      (type: m.type, version: m.version, locale: widget.locale);

  Future<void> _agree(List<MissingConsent> items) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final api = ref.read(legalApiProvider);
    final reconsent = ref.read(reconsentProvider.notifier);
    try {
      final status = await api.agree([
        for (final m in items)
          ConsentClaim(
            type: m.type,
            version: m.version!,
            locale:
                ref.read(legalDocumentProvider(_ref(m))).value?.locale ??
                widget.locale,
          ),
      ], source: 're-consent');
      status.missing.isEmpty
          ? reconsent.clear()
          : reconsent.require(status.missing);
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed = true);
      // 409 LEGAL.VERSION_STALE: the list is out of date, read it again
      if (e is ApiRequestError && e.code == 'LEGAL.VERSION_STALE') {
        try {
          reconsent.require((await api.status()).missing);
        } on ApiRequestError {
          // the message above stays; the button tries again
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final items = [
      for (final m in ref.watch(reconsentProvider))
        if (m.version != null) m,
    ];
    _checked.retainAll(items.map(_id));
    final all = items.every((m) => _checked.contains(_id(m)));
    return Scaffold(
      appBar: AppBar(title: Text(labels.reconsentTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(labels.reconsentBody),
          const SizedBox(height: 12),
          for (final m in items)
            Consumer(
              builder: (context, ref, _) => ConsentTile(
                checkKey: ReconsentScreen.checkKey(m.type),
                viewKey: ReconsentScreen.viewKey(m.type),
                title:
                    ref.watch(legalDocumentProvider(_ref(m))).value?.title ??
                    m.type,
                tag: labels.required,
                viewLabel: labels.view,
                checked: _checked.contains(_id(m)),
                onChanged: (on) => setState(() {
                  on ? _checked.add(_id(m)) : _checked.remove(_id(m));
                }),
                onView: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LegalDocumentPage(
                      type: m.type,
                      version: m.version,
                      locale: widget.locale,
                      labels: labels,
                    ),
                  ),
                ),
              ),
            ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(
              labels.agreeFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: ReconsentScreen.agreeKey,
            onPressed: _busy || items.isEmpty || !all
                ? null
                : () => _agree(items),
            child: Text(labels.agree),
          ),
          if (widget.onLeave != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: ReconsentScreen.leaveKey,
              onPressed: widget.onLeave,
              child: Text(labels.signOut),
            ),
          ],
        ],
      ),
    );
  }
}
