import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// While a sign-in's offer to cancel a deletion is held
/// ([pendingDeletionProvider]) everyone is sent to [path]; without one nobody
/// stays there (a restart or a dropped offer lands on sign-in). The path
/// carries nothing: the restore token never goes into a route.
GoRouterRedirect deletionPendingRedirect(
  Ref ref, {
  String path = '/deletion-pending',
  String loginPath = '/login',
}) {
  return (context, routerState) {
    final held = ref.read(pendingDeletionProvider) != null;
    final here = routerState.matchedLocation == path;
    if (held == here) return null;
    return held ? path : loginPath;
  };
}

Listenable deletionPendingRefreshListenable(Ref ref) {
  final notifier = _Changed();
  ref.listen(pendingDeletionProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
