import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'auth_session.dart';
import 'models.dart';

/// A provider that drops everything one person's data sits in when the session
/// ends, when one begins and when one account is swapped for another with no
/// sign-out between (so the next person on the phone never sees the last
/// one's data, not even for a moment). The app keeps the list, watches the
/// result once at its root, and has a guard test that fails when a new
/// provider is in neither the list nor an exemption with its reason (see the
/// starter's `session_scope.dart`).
///
/// The map is `name: provider`; the name is what the guard test compares.
Provider<void> sessionResetOf(Map<String, ProviderOrFamily> userScoped) =>
    Provider<void>((ref) {
      ref.listen(authSessionProvider, (previous, next) {
        final ended = previous is SignedIn && next is! SignedIn;
        final began = previous is! SignedIn && next is SignedIn;
        final switched =
            previous is SignedIn &&
            next is SignedIn &&
            previous.principal.accountId != next.principal.accountId;
        if (ended || began || switched) {
          for (final p in userScoped.values) {
            ref.invalidate(p);
          }
        }
      });
    });
