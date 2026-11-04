import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_legal/skeleton_legal.dart';

import 'advertising_api.dart';
import 'advertising_labels.dart';
import 'advertising_models.dart';

final _advertisingProvider = FutureProvider.autoDispose<Advertising>(
  (ref) => ref.watch(advertisingApiProvider).advertising(),
  retry: (_, _) => null,
);

/// 404 or 405: the server has no advertising kind (or no such module).
bool _absent(Object error) =>
    error is ApiRequestError && (error.status == 404 || error.status == 405);

String _formatTime(String iso) {
  final t = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// Consent to promotional push (advertising) and to night delivery (21-08):
/// each starts off, and there is no switch that turns it on. "Agree" opens the
/// document; the box under it is checked by the person, and only then the
/// version they saw is recorded (`POST /legal/consents`). Off is a confirm and
/// a withdrawal; withdrawing advertising withdraws night with it. A band asks
/// for the two-year reconfirmation. After every change the server is read
/// again; nothing is shown as changed before that.
///
/// Draws nothing when the server has no advertising route (404). Needs
/// `advertisingApiProvider` and `legalApiProvider` overridden. Place it below
/// `PushSettingsView`.
class AdvertisingSettingsView extends ConsumerStatefulWidget {
  const AdvertisingSettingsView({
    super.key,
    this.labels = const AdvertisingLabels(),
    this.locale,
    this.formatTime = _formatTime,
    this.now,
  });

  final AdvertisingLabels labels;

  /// The language the documents are read in; null = the server's default.
  final String? locale;

  /// Turns an ISO-8601 instant into the text shown. Default: local
  /// `yyyy-MM-dd HH:mm`.
  final String Function(String iso) formatTime;

  /// The moment "D-n" counts from. Default: now. For tests.
  final DateTime? now;

  @override
  ConsumerState<AdvertisingSettingsView> createState() =>
      _AdvertisingSettingsViewState();
}

class _AdvertisingSettingsViewState
    extends ConsumerState<AdvertisingSettingsView> {
  bool _withdrawing = false;
  bool _withdrawFailed = false;

  AdvertisingLabels get labels => widget.labels;

  int _daysLeft(String expiresAt) {
    final now = widget.now ?? DateTime.now();
    final ms = DateTime.parse(expiresAt).difference(now).inMilliseconds;
    return max(0, (ms / Duration.millisecondsPerDay).ceil());
  }

  String get _stamp =>
      widget.formatTime(DateTime.now().toUtc().toIso8601String());

  Future<void> _agree(Advertising ad, {required bool night}) async {
    final target = night ? ad.night : ad.consent;
    final messenger = ScaffoldMessenger.of(context);
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AgreePage(
          type: target.type,
          source: target.needsReconfirm ? 'reconfirm' : 'push-settings',
          locale: widget.locale,
          labels: labels,
        ),
      ),
    );
    if (agreed != true) return;
    ref.invalidate(_advertisingProvider);
    messenger.showSnackBar(SnackBar(content: Text(labels.agreed(_stamp))));
  }

  Future<void> _withdraw(Advertising ad, {required bool night}) async {
    final alsoNight = !night && ad.night.state == 'AGREED';
    final title = night ? labels.nightTitle : labels.consentTitle;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(legalApiProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labels.withdrawTitle),
        content: Text(
          [
            '$title — ${labels.withdrawDescription}',
            if (alsoNight) labels.withdrawAlsoNight,
          ].join(' '),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(labels.withdrawCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(labels.withdrawConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _withdrawing = true;
      _withdrawFailed = false;
    });
    var failed = false;
    try {
      await api.withdraw((night ? ad.night : ad.consent).type);
      if (alsoNight) {
        // advertising is already withdrawn: try the night one once more
        try {
          await api.withdraw(ad.night.type);
        } on ApiRequestError {
          await api.withdraw(ad.night.type);
        }
      }
    } on ApiRequestError {
      failed = true;
    }
    // read again either way: a half-done withdrawal must not stay shown as on
    ref.invalidate(_advertisingProvider);
    if (!failed) {
      messenger.showSnackBar(SnackBar(content: Text(labels.withdrawn(_stamp))));
    }
    if (mounted) {
      setState(() {
        _withdrawing = false;
        _withdrawFailed = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_advertisingProvider);
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _absent(error)
          ? const SizedBox.shrink()
          // an older value is not used: it could show a consent as on
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(labels.loadFailed)),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(_advertisingProvider),
                    child: Text(labels.retry),
                  ),
                ],
              ),
            ),
      data: _content,
    );
  }

  Widget _content(Advertising ad) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(labels.title, style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(labels.description(ad.senderName)),
        ),
        for (final night in [false, true])
          // a night agreement means nothing while advertising is off
          if ((!night || ad.consent.isOn) &&
              (night ? ad.night : ad.consent).needsReconfirm)
            _reconfirmBand(ad, night: night),
        _row(ad, night: false),
        _row(ad, night: true),
        if (_withdrawFailed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              labels.withdrawFailed,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _reconfirmBand(Advertising ad, {required bool night}) {
    final target = night ? ad.night : ad.consent;
    final expired = target.state == 'EXPIRED';
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: expired ? scheme.errorContainer : scheme.secondaryContainer,
        border: Border.all(color: expired ? scheme.error : scheme.secondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired
                      ? labels.reconfirmExpiredTitle
                      : labels.reconfirmDueTitle(
                          _daysLeft(target.expiresAt ?? ''),
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${night ? labels.nightTitle : labels.consentTitle} · '
                  '${expired ? labels.reconfirmExpiredDescription : labels.reconfirmDueDescription}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _agree(ad, night: night),
            child: Text(
              expired
                  ? labels.reconfirmExpiredAction
                  : labels.reconfirmDueAction,
            ),
          ),
        ],
      ),
    );
  }

  /// On: a switch that only turns off (after a confirm). Off: the text and an
  /// "Agree" button; there is no way to turn it on from here.
  Widget _row(Advertising ad, {required bool night}) {
    final target = night ? ad.night : ad.consent;
    final on = night ? ad.nightOn : ad.consent.isOn;
    final locked = night && !ad.consent.isOn;
    final title = night ? labels.nightTitle : labels.consentTitle;
    final base = night
        ? labels.nightDescription(
            ad.nightWindow.start,
            ad.nightWindow.end,
            ad.nightWindow.zone,
          )
        : labels.consentDescription;
    if (on) {
      final agreedAt = target.agreedAt;
      final expiresAt = target.expiresAt;
      return SwitchListTile(
        title: Text(title),
        subtitle: Text(
          agreedAt != null && expiresAt != null
              ? '$base ${labels.agreedUntil(widget.formatTime(agreedAt), widget.formatTime(expiresAt))}'
              : base,
        ),
        value: true,
        onChanged: _withdrawing
            ? null
            : (next) {
                if (!next) _withdraw(ad, night: night);
              },
      );
    }
    final extra = locked
        ? labels.nightLocked
        : const {'EXPIRED', 'WITHDRAWN', 'OUTDATED'}.contains(target.state)
        ? labels.stopped
        : null;
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(base), if (extra != null) Text(extra)],
      ),
      trailing: OutlinedButton(
        onPressed: locked || _withdrawing
            ? null
            : () => _agree(ad, night: night),
        child: Text(labels.agree),
      ),
    );
  }
}

/// The document and, under it, the box that starts unchecked. "Agree" is live
/// only when the document is read in and the box is checked; it sends the
/// version and language of the text that is on screen.
class _AgreePage extends ConsumerStatefulWidget {
  const _AgreePage({
    required this.type,
    required this.source,
    required this.locale,
    required this.labels,
  });

  final String type;
  final String source;
  final String? locale;
  final AdvertisingLabels labels;

  @override
  ConsumerState<_AgreePage> createState() => _AgreePageState();
}

class _AgreePageState extends ConsumerState<_AgreePage> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  LegalDocumentRef get _key =>
      (type: widget.type, version: null, locale: widget.locale);

  Future<void> _confirm(LegalDocument document) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(legalApiProvider).agree([
        ConsentClaim(
          type: widget.type,
          version: document.version,
          locale: document.locale,
        ),
      ], source: widget.source);
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiRequestError catch (e) {
      if (!mounted) return;
      if (e.code == 'LEGAL.VERSION_STALE') {
        // a new version is in force: read it, and the box is checked again
        ref.invalidate(legalDocumentProvider(_key));
        _checked = false;
        _error = widget.labels.documentChanged;
      } else {
        _error = widget.labels.agreeFailed;
      }
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final document = ref.watch(legalDocumentProvider(_key));
    final ready = document.hasValue && !document.isLoading && !_busy;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: LegalDocumentPage(type: widget.type, locale: widget.locale),
          ),
          SafeArea(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _checked,
                  onChanged: ready
                      ? (value) => setState(() => _checked = value ?? false)
                      : null,
                  title: Text(labels.documentCheck),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: ready && _checked
                          ? () => _confirm(document.requireValue)
                          : null,
                      child: Text(labels.documentConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
