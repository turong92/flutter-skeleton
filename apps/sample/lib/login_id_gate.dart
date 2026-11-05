import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// True while the signed-in account has to choose its login ID: `GET
/// /account/me` has `loginId: null` (read once per sign-in; a failed read lets
/// the person in), or any call was refused with `403 ACCOUNT.LOGIN_ID_REQUIRED`
/// ([LoginIdRequiredInterceptor] calls [NeedsLoginId.hold]). The server answers nothing
/// else until then, so this gate comes first (ID, then consent, then nickname).
final needsLoginIdProvider = NotifierProvider<NeedsLoginId, bool>(
  NeedsLoginId.new,
);

class NeedsLoginId extends Notifier<bool> {
  /// The calls refused for want of an ID, waiting for the form.
  final _held = HeldCalls();

  @override
  bool build() {
    ref.listen(authSessionProvider, (previous, next) async {
      if (next is! SignedIn) {
        state = false;
        _held.release(resend: false);
        return;
      }
      if (previous is SignedIn) {
        // Another account without a sign-out in between: calls held for the
        // first one must not go out with the second one's headers.
        if (previous.principal.accountId != next.principal.accountId) {
          _held.release(resend: false);
        }
        return;
      }
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

  /// A call was refused: the account has no ID. Raises the gate and holds the
  /// call: true = the ID is chosen, send it again; false = the person signed
  /// out, the call ends with its 403. Signed out (a late answer must not raise
  /// the gate for the next person): false at once.
  Future<bool> hold() {
    if (ref.read(authSessionProvider) is! SignedIn) return Future.value(false);
    state = true;
    return _held.hold();
  }

  /// The ID is chosen: the refused calls are sent again.
  void done() {
    state = false;
    _held.release(resend: true);
  }
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
