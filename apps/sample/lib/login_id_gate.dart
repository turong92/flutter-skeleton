import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// True while the signed-in account has to choose its login ID: `GET
/// /account/me` has `loginId: null` (read once per sign-in; a failed read lets
/// the person in), or any call was refused with `403 ACCOUNT.LOGIN_ID_REQUIRED`
/// ([LoginIdRequiredInterceptor] calls [require]). The server answers nothing
/// else until then, so this gate comes first (ID, then consent, then nickname).
final needsLoginIdProvider = NotifierProvider<NeedsLoginId, bool>(
  NeedsLoginId.new,
);

class NeedsLoginId extends Notifier<bool> {
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
          if (me.loginIdRequired) state = true;
        }
      } catch (_) {
        // Let the person in; a 403 on the next call still raises the gate.
      }
    }, fireImmediately: true);
    return false;
  }

  /// A call was refused: the account has no ID. Ignored while signed out (a
  /// late answer must not raise the gate for the next person).
  void require() {
    if (ref.read(authSessionProvider) is SignedIn) state = true;
  }

  void done() => state = false;
}

/// A redirect that keeps an account without a login ID on [path] until it has
/// one. Null while no ID is needed.
GoRouterRedirect loginIdRedirect(Ref ref, {String path = '/login-id'}) {
  return (context, routerState) =>
      ref.read(needsLoginIdProvider) && routerState.matchedLocation != path
      ? path
      : null;
}

Listenable loginIdRefreshListenable(Ref ref) {
  final notifier = _Changed();
  ref.listen(needsLoginIdProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
