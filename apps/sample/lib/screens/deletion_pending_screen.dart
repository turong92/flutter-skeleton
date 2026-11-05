import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_social_login/skeleton_social_login.dart';

import 'form_page.dart';

/// Where a sign-in lands when the account is in its deletion grace (`403
/// AUTH.ACCOUNT_DELETION_PENDING`, by password or by a social provider): the
/// router sends everyone here while `pendingDeletionProvider` holds the offer.
/// The path carries nothing; the restore token stays in that provider.
/// Cancelling signs in (the router leaves); saying no goes back to sign-in.
class DeletionPendingScreen extends ConsumerWidget {
  const DeletionPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Whatever ends the offer also ends the "being deleted" line a social
    // button left under the sign-in buttons.
    ref.listen(pendingDeletionProvider, (_, next) {
      if (next == null) ref.invalidate(socialLoginControllerProvider);
    });
    return FormPage(
      title: 'Account scheduled for deletion',
      // Dropping the offer sends the router back to /login.
      children: const [DeletionPendingForm()],
    );
  }
}
