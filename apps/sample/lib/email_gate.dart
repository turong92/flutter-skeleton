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
  /// The calls refused for want of an address, waiting for the screen.
  final _held = HeldCalls();

  @override
  EmailGate build() {
    ref.listen(authSessionProvider, (previous, next) async {
      if (next is! SignedIn) {
        state = _closed;
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

  /// A call was refused: the account has no address. Opens the screen and
  /// holds the call: true = the address is confirmed, send it again; false =
  /// the person left, the call ends with its 403. Signed out (a late answer
  /// must not raise the screen for the next person): false at once.
  Future<bool> hold() {
    if (ref.read(authSessionProvider) is! SignedIn) return Future.value(false);
    require();
    return _held.hold();
  }

  /// Opens the screen (a warning button, or a refused call through [hold]).
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
  /// The refused calls end with their 403.
  void later() {
    state = (open: false, blocking: state.blocking, toWrite: state.toWrite);
    _held.release(resend: false);
  }

  /// The registration screen is gone (popped, or replaced by a `go()`): unless
  /// it ended by [registered] or [later], or it was the blocking one, that is
  /// "later".
  void screenGone() {
    if (ref.mounted && state.open && !state.blocking) later();
  }

  /// The address is confirmed: the refused calls are sent again.
  void registered() {
    state = _closed;
    _held.release(resend: true);
  }
}

/// A redirect that keeps an account the server blocks until it has an address
/// on [path]. Null otherwise: a screen opened only for a write is pushed over
/// the screen the person is on (see `router.dart`), so what was typed there is
/// still there afterwards.
GoRouterRedirect emailRedirect(Ref ref, {String path = '/email'}) {
  return (context, routerState) {
    final gate = ref.read(emailGateProvider);
    return gate.open && gate.blocking && routerState.matchedLocation != path
        ? path
        : null;
  };
}

Listenable emailRefreshListenable(Ref ref) {
  final notifier = _Changed();
  // Only the gate that blocks everything is a redirect. A screen opened for a
  // write is pushed and popped by hand; a refresh on its way out would parse
  // the old location again and put the pushed screen back.
  ref.listen(
    emailGateProvider.select((g) => g.open && g.blocking),
    (_, _) => notifier.changed(),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
