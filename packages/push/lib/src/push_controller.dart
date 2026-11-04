import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'push_api.dart';
import 'push_device_store.dart';
import 'push_token_source.dart';

/// The app overrides this with the `PushApi` built on its one `ApiClient`.
final pushApiProvider = Provider<PushApi>(
  (ref) => throw UnimplementedError(
    'Override pushApiProvider with a PushApi built on the app\'s ApiClient',
  ),
);

/// Firebase by default. It only uses an already initialized Firebase.
final pushTokenSourceProvider = Provider<PushTokenSource>(
  (ref) => FirebasePushTokenSource(),
);

final pushDeviceStoreProvider = Provider<PushDeviceStore>(
  (ref) => PushDeviceStore(),
);

/// The app says whether a session exists, so `push` needs no auth import:
/// `pushSignedInProvider.overrideWith((ref) => ref.watch(sessionProvider) is SignedIn)`.
/// True only once the session is restored, so a tap that started the app
/// waits for it.
final pushSignedInProvider = Provider<bool>((ref) => false);

/// Where a tapped notification's in-app path goes (the app's router).
final pushOpenLinkProvider = Provider<void Function(String link)>(
  (ref) => (_) {},
);

/// Where a tapped notification goes when it carries no in-app link (e.g. the
/// inbox route). Null (default): such a tap opens nothing.
final pushFallbackLinkProvider = Provider<String?>((ref) => null);

/// Messages that arrive while the app is in front (Android shows no system
/// notification then; the app shows its own, e.g. a SnackBar).
final pushMessagesProvider = StreamProvider<PushMessage>(
  (ref) => ref.watch(pushTokenSourceProvider).onMessage,
);

/// Hang this on auth's sign-out hooks:
/// `ref.read(signOutHooksProvider).add(ref.read(pushSignOutHookProvider))`.
final pushSignOutHookProvider = Provider<Future<void> Function()>((ref) {
  final api = ref.watch(pushApiProvider);
  final store = ref.watch(pushDeviceStoreProvider);
  return () => removeDeviceBeforeSignOut(api, store);
});

enum PushStatus {
  /// Cannot be used now: signed out, no Firebase, the server has FCM off, or
  /// the registration failed.
  unavailable,

  /// Permission not asked yet: show [PushPrompt].
  notAsked,

  /// The system refuses; only settings can change that.
  denied,

  /// This device is registered.
  enabled,

  /// The person switched this device off.
  off,
}

class PushState {
  const PushState(this.status);
  final PushStatus status;
}

/// Watch it once from the app root so it works: `ref.watch(pushControllerProvider)`.
///
/// Registers this device (signed in and `config.fcm`) at start, right after
/// sign-in and on every token refresh, and hands tapped notifications'
/// in-app links to [pushOpenLinkProvider].
class PushController extends Notifier<PushState> {
  int _generation = 0;
  bool _signedIn = false;
  bool _initialChecked = false;
  String? _pendingLink;

  PushApi get _api => ref.read(pushApiProvider);
  PushTokenSource get _source => ref.read(pushTokenSourceProvider);
  PushDeviceStore get _store => ref.read(pushDeviceStoreProvider);

  @override
  PushState build() {
    _signedIn = ref.watch(pushSignedInProvider);
    final source = ref.watch(pushTokenSourceProvider);
    final generation = ++_generation;
    if (source.available) {
      final refresh = source.onTokenRefresh.listen(_onTokenRefresh);
      final opened = source.onOpened.listen((m) => _open(_target(m)));
      ref.onDispose(() {
        refresh.cancel();
        opened.cancel();
      });
    }
    Future.microtask(() => _start(generation));
    return const PushState(PushStatus.unavailable);
  }

  bool _stale(int generation) => generation != _generation || !ref.mounted;

  Future<void> _start(int generation) async {
    if (_stale(generation) || !_source.available) return;
    if (!_initialChecked) {
      _initialChecked = true;
      final initial = await _source.initialMessage();
      _pendingLink = initial == null ? null : _target(initial);
      // Before the stale check: a build that ran while we waited has already
      // passed this block, so nobody else would deliver the link.
      _flush();
      if (_stale(generation)) return;
    }
    _flush();
    if (_signedIn) await _refresh(generation);
  }

  /// A tapped notification's path: its link, else the fallback.
  String? _target(PushMessage message) =>
      message.link ?? ref.read(pushFallbackLinkProvider);

  void _open(String? link) {
    if (link == null) return;
    _pendingLink = link;
    _flush();
  }

  void _flush() {
    final link = _pendingLink;
    if (link == null || !_signedIn) return;
    _pendingLink = null;
    ref.read(pushOpenLinkProvider)(link);
  }

  Future<void> _refresh(int generation) async {
    try {
      final config = await _api.config();
      if (_stale(generation)) return;
      if (!config.fcm) return _set(PushStatus.unavailable);
      switch (await _source.permission()) {
        case PushPermission.denied:
          return _set(PushStatus.denied);
        case PushPermission.notDetermined:
          return _set(PushStatus.notAsked);
        case PushPermission.granted:
          if (await _store.optedOut()) return _set(PushStatus.off);
          if (_stale(generation)) return;
          return _set(await _register());
      }
    } on ApiRequestError {
      _set(PushStatus.unavailable);
    } on Exception {
      _set(PushStatus.unavailable);
    }
  }

  void _set(PushStatus status) {
    if (ref.mounted) state = PushState(status);
  }

  Future<PushStatus> _register({String? token}) async {
    final value = token ?? await _source.token();
    if (value == null) return PushStatus.unavailable;
    try {
      await _api.registerDevice(
        await _store.installationId(),
        token: value,
        platform: _source.platform,
      );
      return PushStatus.enabled;
    } on ApiRequestError {
      // PUSH.KIND_DISABLED (the server has no FCM sender) or a failed call:
      // either way this device cannot receive now.
      return PushStatus.unavailable;
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    if (state.status != PushStatus.enabled) return;
    final result = await _register(token: token);
    if (result != PushStatus.enabled) _set(result);
  }

  /// Asks the system for permission. Call it from the tap on the prompt, never
  /// at start. On success the device is registered.
  Future<void> requestPermission() async {
    if (!_source.available) return;
    await _source.requestPermission();
    await _refresh(_generation);
  }

  /// The switch of this device. Off deletes the registration and is
  /// remembered; on asks for permission when it is not given yet.
  Future<void> setDeviceEnabled(bool enabled) async {
    if (enabled) {
      await _store.setOptedOut(false);
      await requestPermission();
    } else {
      await _store.setOptedOut(true);
      await removeDeviceBeforeSignOut(_api, _store);
      _set(PushStatus.off);
    }
  }

  /// `POST /push/devices/{id}/test`. Throws [ApiRequestError] (429
  /// [PushErrorCodes.testTooSoon]).
  Future<void> sendTest() async => _api.sendTest(await _store.installationId());
}

final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);
