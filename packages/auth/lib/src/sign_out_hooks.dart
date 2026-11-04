import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

typedef SignOutHook = Future<void> Function();

/// Work to do just before a sign-out, while the tokens are still valid (for
/// example `push` deleting this device's registration). Hooks run together and
/// share one time limit: a failing or slow hook never stops the sign-out.
class SignOutHooks {
  SignOutHooks({this.timeout = const Duration(seconds: 3)});

  final Duration timeout;
  final List<SignOutHook> _hooks = [];

  /// Returns the function that removes the hook again.
  void Function() add(SignOutHook hook) {
    _hooks.add(hook);
    return () => _hooks.remove(hook);
  }

  Future<void> run() async {
    if (_hooks.isEmpty) return;
    final all = Future.wait([for (final hook in List.of(_hooks)) _guard(hook)]);
    try {
      await all.timeout(timeout);
    } on TimeoutException {
      // Slow hooks go on in the background; the sign-out does not wait.
    }
  }

  Future<void> _guard(SignOutHook hook) async {
    try {
      await hook();
    } catch (e, stackTrace) {
      if (e is ApiRequestError) return; // offline or a server error: expected
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'skeleton_auth',
          context: ErrorDescription('while running a sign-out hook'),
        ),
      );
    }
  }
}
