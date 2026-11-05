import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// True while the signed-in account has no nickname (`GET /account/me` says
/// `displayName: null`, e.g. a social sign-up). Read once per sign-in; a failed
/// read lets the person in, the server still decides what needs a nickname.
final needsNicknameProvider = NotifierProvider<NeedsNickname, bool>(
  NeedsNickname.new,
);

class NeedsNickname extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authSessionProvider, (previous, next) async {
      if (next is! SignedIn) {
        state = false;
        return;
      }
      if (previous is SignedIn) return;
      try {
        final me = await ref.read(accountApiProvider).me();
        if (ref.mounted && ref.read(authSessionProvider) is SignedIn) {
          state = me.displayName == null;
        }
      } catch (_) {
        // Let the person in; see above.
      }
    }, fireImmediately: true);
    return false;
  }

  void done() => state = false;
}

/// A redirect that keeps a nickname-less account on [path] until it has one.
GoRouterRedirect nicknameRedirect(Ref ref, {String path = '/nickname'}) {
  return (context, routerState) =>
      ref.read(needsNicknameProvider) && routerState.matchedLocation != path
      ? path
      : null;
}

Listenable nicknameRefreshListenable(Ref ref) {
  final notifier = _Changed();
  ref.listen(needsNicknameProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
