import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_notifications/skeleton_notifications.dart';
import 'package:skeleton_realtime/skeleton_realtime.dart';

/// Whether the app is in front. Only `resumed` counts: the stream is not kept
/// open behind the user's back (the push covers that time).
class _Foreground extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance..addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    final now = binding.lifecycleState;
    return now == null || now == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) =>
      state = lifecycle == AppLifecycleState.resumed;
}

final _foregroundProvider = NotifierProvider<_Foreground, bool>(
  _Foreground.new,
);

/// The notification stream while somebody is signed in and the app is in
/// front. Signing out, another account or going to the background closes it;
/// coming back opens it again and reads the inbox once for what was missed.
/// An event is only a signal: the count is read from the server.
/// Watch it from the app root.
final inboxRealtimeProvider = Provider<void>((ref) {
  ref.listen(_foregroundProvider, (before, now) {
    if (now && before == false) notificationsChanged(ref);
  });
  final connected =
      ref.watch(notificationsAccountProvider) != null &&
      ref.watch(_foregroundProvider);
  if (!connected) return;
  final connection = SseConnection(
    dio: ref.read(apiClientProvider).dio,
    onEvent: (_) => notificationsChanged(ref),
  )..start();
  ref.onDispose(connection.close);
});
