import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_auth/skeleton_auth.dart';

/// What the app knows about the address of the signed-in account.
///
/// - [open]: the registration screen has to be shown.
/// - [blocking]: the server wants the address right after sign-in
///   (`me.emailRequired`): it refuses reads too, so the screen cannot be left
///   but by signing out.
/// - [toWrite]: the server wants it only for changes (`me.emailRequiredToWrite`):
///   reads pass, the screen can be closed ("later"), and the person is told
///   before a write screen opens.
typedef EmailGate = ({bool open, bool blocking, bool toWrite});

const _closed = (open: false, blocking: false, toWrite: false);

/// Read once per sign-in from `GET /account/me` (a failed read lets the person
/// in; a `403 ACCOUNT.EMAIL_REQUIRED` on any call still opens the screen, see
/// [EmailRequiredInterceptor]). Order of the gates: ID, then email, then
/// consent, then nickname.
final emailGateProvider = NotifierProvider<EmailGateNotifier, EmailGate>(
  EmailGateNotifier.new,
);

class EmailGateNotifier extends Notifier<EmailGate> {
  @override
  EmailGate build() {
    ref.listen(authSessionProvider, (previous, next) async {
      if (next is! SignedIn) {
        state = _closed;
        return;
      }
      if (previous is SignedIn) return;
      try {
        final me = await ref.read(accountApiProvider).me();
        if (ref.mounted && ref.read(authSessionProvider) is SignedIn) {
          final missing = me.email == null;
          state = (
            open: me.emailRequired && missing,
            blocking: me.emailRequired && missing,
            toWrite: me.emailRequiredToWrite && missing,
          );
        }
      } catch (_) {
        // Let the person in; a refused call raises the screen.
      }
    }, fireImmediately: true);
    return _closed;
  }

  /// A call was refused: the account has no address. Ignored while signed out
  /// (a late answer must not raise the screen for the next person).
  void require() {
    if (ref.read(authSessionProvider) is SignedIn) {
      state = (open: true, blocking: state.blocking, toWrite: state.toWrite);
    }
  }

  /// Before a write screen opens: true = go on; false = the registration
  /// screen was opened instead (the person repeats the action afterwards).
  bool ensure() {
    if (!state.toWrite) return true;
    require();
    return false;
  }

  /// "Later": only where the server lets reads through.
  void later() =>
      state = (open: false, blocking: state.blocking, toWrite: state.toWrite);

  void registered() => state = _closed;
}

/// A redirect that keeps an account without an address on [path] while the
/// screen is open. Null while it is not.
GoRouterRedirect emailRedirect(Ref ref, {String path = '/email'}) {
  return (context, routerState) =>
      ref.read(emailGateProvider).open && routerState.matchedLocation != path
      ? path
      : null;
}

Listenable emailRefreshListenable(Ref ref) {
  final notifier = _Changed();
  ref.listen(emailGateProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
