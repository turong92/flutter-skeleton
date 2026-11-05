import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [DeletionPendingForm] (defaults are English).
class DeletionPendingLabels {
  const DeletionPendingLabels({
    this.cancel = 'Cancel the deletion',
    this.keep = 'Keep it deleted',
    this.back = 'Back to sign in',
    this.noRestore =
        'The deletion cannot be cancelled here. Contact support if you want '
        'the account back.',
    this.expired = 'That took too long. Sign in again to cancel the deletion.',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String cancel;
  final String keep;
  final String back;

  /// The server did not give a restore token (`deletion.self-restore` off).
  final String noRestore;

  /// `410 ACCOUNT.TOKEN_INVALID`: the token died (15 minutes by default).
  final String expired;
  final String networkError;
  final String genericError;

  String scheduled(String date) =>
      'This account is scheduled for deletion on $date. Cancel the deletion '
      'and keep using it?';

  String scheduledNoDate() =>
      'This account is scheduled for deletion. Cancel the deletion and keep '
      'using it?';
}

/// The offer to cancel a deletion that follows `403
/// AUTH.ACCOUNT_DELETION_PENDING` on a sign-in with any method. It reads
/// [pendingDeletionProvider] (set by `AuthSession.login` and by the social
/// sign-in); without one it shows nothing.
///
/// "Cancel the deletion" (`POST /account/delete/cancel`) is a sign-in: the
/// session starts and the router's redirect leaves. When the person says no or
/// the token is dead the offer is dropped and [onLeave] runs. The form does not
/// navigate. The token lives in memory only: it is not in a route, a
/// log or a message.
class DeletionPendingForm extends ConsumerStatefulWidget {
  const DeletionPendingForm({
    super.key,
    this.onLeave,
    this.formatDate = _isoDate,
    this.labels = const DeletionPendingLabels(),
  });

  /// Runs after the offer was dropped (no, or the token is dead). An app that
  /// sends everyone to sign-in while no offer is held needs nothing here.
  final VoidCallback? onLeave;

  /// How the erase date reads; the default is `2026-12-05` in local time.
  final String Function(DateTime date) formatDate;
  final DeletionPendingLabels labels;

  static String _isoDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  @override
  ConsumerState<DeletionPendingForm> createState() =>
      _DeletionPendingFormState();
}

class _DeletionPendingFormState extends ConsumerState<DeletionPendingForm> {
  var _busy = false;
  var _expired = false;
  String? _error;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).cancelDeletion();
    } catch (e) {
      if (!mounted) return;
      final labels = widget.labels;
      if (e is ApiRequestError && e.code == AccountErrorCodes.tokenInvalid) {
        ref.read(pendingDeletionProvider.notifier).clear();
        setState(() => _expired = true);
      } else {
        setState(
          () => _error =
              e is ApiRequestError && e.code == ClientErrorCodes.networkError
              ? labels.networkError
              : labels.genericError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    ref.read(pendingDeletionProvider.notifier).clear();
    widget.onLeave?.call();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final pending = ref.watch(pendingDeletionProvider);
    final back = OutlinedButton(onPressed: _leave, child: Text(labels.back));
    if (_expired) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(labels.expired), const SizedBox(height: 16), back],
      );
    }
    if (pending == null) return const SizedBox.shrink();
    final date = pending.purgeAfter;
    if (pending.restoreToken == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(labels.noRestore), const SizedBox(height: 16), back],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          date == null
              ? labels.scheduledNoDate()
              : labels.scheduled(widget.formatDate(date)),
        ),
        if (_error != null) ErrorText(_error!),
        const SizedBox(height: 16),
        SubmitButton(label: labels.cancel, busy: _busy, onPressed: _cancel),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _leave,
          child: Text(labels.keep),
        ),
      ],
    );
  }
}
