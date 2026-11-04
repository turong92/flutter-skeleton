import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'consent_tile.dart';
import 'legal_document_page.dart';
import 'legal_labels.dart';
import 'legal_providers.dart';
import 'models.dart';

/// What the checklist holds right now.
class SignUpConsentsValue {
  const SignUpConsentsValue({required this.claims, required this.complete});

  /// The checked documents, with the version and language the user saw.
  final List<ConsentClaim> claims;

  /// Every document that is required at sign-up is checked.
  final bool complete;

  /// For the sign-up request's `consents` field.
  List<Map<String, String>> toJson() => [for (final c in claims) c.toJson()];

  @override
  bool operator ==(Object other) =>
      other is SignUpConsentsValue &&
      other.complete == complete &&
      _sameClaims(other.claims, claims);

  @override
  int get hashCode => Object.hash(complete, claims.length);

  static bool _sameClaims(List<ConsentClaim> a, List<ConsentClaim> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type ||
          a[i].version != b[i].version ||
          a[i].locale != b[i].locale) {
        return false;
      }
    }
    return true;
  }
}

/// The consent boxes of a sign-up form: one per document required at sign-up
/// and one per optional document, all unchecked. Does not know the sign-up
/// form (nor the auth package): [onChanged] hands over the value to put into
/// the request, and `complete` tells whether the submit button may work.
///
/// Reads the documents from [legalDocumentsProvider]. When the backend answers
/// `400 LEGAL.CONSENT_REQUIRED` anyway, `ref.invalidate(legalDocumentsProvider)`:
/// a document whose version changed comes back unchecked.
class SignUpConsents extends ConsumerStatefulWidget {
  const SignUpConsents({
    super.key,
    required this.onChanged,
    this.locale,
    this.labels = const LegalLabels(),
  });

  static Key checkKey(String type) => Key('skeleton_legal.sign_up.check.$type');
  static Key viewKey(String type) => Key('skeleton_legal.sign_up.view.$type');

  /// Called after a frame in which the value changed, also for the first one.
  final ValueChanged<SignUpConsentsValue> onChanged;

  /// The language to show; a document without it is shown in its first one.
  final String? locale;
  final LegalLabels labels;

  @override
  ConsumerState<SignUpConsents> createState() => _SignUpConsentsState();
}

class _SignUpConsentsState extends ConsumerState<SignUpConsents> {
  /// `type/version` of the checked documents: a new version starts unchecked.
  final _checked = <String>{};
  SignUpConsentsValue? _sent;

  static String _id(LegalDocumentSummary d) => '${d.type}/${d.version}';

  /// One entry per type: the wanted language, else the first.
  List<LegalDocumentSummary> _shown(List<LegalDocumentSummary> all) {
    final byType = <String, LegalDocumentSummary>{};
    for (final d in all) {
      if (d.required && !d.requiredAtSignUp) continue; // asked for later
      final seen = byType[d.type];
      if (seen == null ||
          (d.locale == widget.locale && seen.locale != d.locale)) {
        byType[d.type] = d;
      }
    }
    return byType.values.toList();
  }

  void _report(List<LegalDocumentSummary> shown) {
    final value = SignUpConsentsValue(
      claims: [
        for (final d in shown)
          if (_checked.contains(_id(d)))
            ConsentClaim(type: d.type, version: d.version, locale: d.locale),
      ],
      complete: shown
          .where((d) => d.requiredAtSignUp)
          .every((d) => _checked.contains(_id(d))),
    );
    if (value == _sent) return;
    _sent = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final documents = ref.watch(legalDocumentsProvider);
    return documents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels.loadFailed),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.invalidate(legalDocumentsProvider),
            child: Text(labels.retry),
          ),
        ],
      ),
      data: (all) {
        final shown = _shown(all);
        // a version that is gone from the list can no longer be checked
        _checked.retainAll(shown.map(_id));
        _report(shown);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in shown)
              ConsentTile(
                checkKey: SignUpConsents.checkKey(d.type),
                viewKey: SignUpConsents.viewKey(d.type),
                title: d.title ?? d.type,
                tag: d.requiredAtSignUp ? labels.required : labels.optional,
                viewLabel: labels.view,
                checked: _checked.contains(_id(d)),
                onChanged: (on) => setState(() {
                  on ? _checked.add(_id(d)) : _checked.remove(_id(d));
                }),
                onView: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LegalDocumentPage(
                      type: d.type,
                      version: d.version,
                      locale: d.locale,
                      labels: labels,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
