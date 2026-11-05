import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'auth_session.dart';
import 'form_parts.dart';

/// The texts of [MagicLinkLanding] (defaults are English).
class MagicLinkLabels {
  const MagicLinkLabels({
    this.checking = 'Signing you in...',
    this.invalid = 'This link is invalid or expired. Ask for a new one.',
    this.requestNew = 'Request a new link',
    this.retry = 'Try again',
    this.networkError = 'Cannot reach the server. Check your connection.',
    this.genericError = 'Something went wrong. Please try again.',
  });

  final String checking;
  final String invalid;
  final String requestNew;
  final String retry;
  final String networkError;
  final String genericError;
}

/// The page a mailed link opens (`<link-base-url>/magic-link?token=`): the
/// [token] is exchanged for a sign-in once, on arrival. [onDone] runs after
/// the session started (the app goes on, usually by the router's redirect).
/// An account in its deletion grace sets `pendingDeletionProvider`; the app's
/// redirect then shows the offer to cancel. A dead link offers [onInvalid]
/// ("request a new link", usually the sign-in screen).
///
/// The token is only sent to the server: never shown, logged or put in an
/// error text. Any other failure keeps the link usable ("Try again"), since
/// a network error does not spend it.
class MagicLinkLanding extends ConsumerStatefulWidget {
  const MagicLinkLanding({
    super.key,
    required this.token,
    required this.onDone,
    this.onInvalid,
    this.labels = const MagicLinkLabels(),
  });

  final String? token;
  final VoidCallback onDone;
  final VoidCallback? onInvalid;
  final MagicLinkLabels labels;

  @override
  ConsumerState<MagicLinkLanding> createState() => _MagicLinkLandingState();
}

class _MagicLinkLandingState extends ConsumerState<MagicLinkLanding> {
  var _invalid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token == null || token.isEmpty) {
      _invalid = true;
    } else {
      // One attempt per mounted page; the page is not rebuilt into a second.
      Future.microtask(() => _redeem(token));
    }
  }

  Future<void> _redeem(String token) async {
    final labels = widget.labels;
    if (mounted) setState(() => _error = null);
    try {
      await ref.read(authSessionProvider.notifier).redeemMagicLink(token);
      if (mounted) widget.onDone();
    } on ApiRequestError catch (e) {
      if (!mounted) return;
      // A grace period is not a failure: the redirect shows the offer.
      if (deletionPendingOf(e) != null) return;
      setState(() {
        if (e.code == AccountErrorCodes.tokenInvalid) {
          _invalid = true;
        } else {
          _error = e.code == ClientErrorCodes.networkError
              ? labels.networkError
              : labels.genericError;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    if (_invalid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(labels.invalid),
          if (widget.onInvalid != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.onInvalid,
              child: Text(labels.requestNew),
            ),
          ],
        ],
      );
    }
    final error = _error;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorText(error),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _redeem(widget.token!),
            child: Text(labels.retry),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(labels.checking),
      ],
    );
  }
}
