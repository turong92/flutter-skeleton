import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_control_api.dart';
import 'app_state.dart';
import 'models.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `appControlApiProvider.overrideWith((ref) => AppControlApi(ref.watch(apiClientProvider)))`.
final appControlApiProvider = Provider<AppControlApi>(
  (ref) => throw UnimplementedError(
    'Override appControlApiProvider with an AppControlApi built on the app\'s ApiClient',
  ),
);

/// The installed app's version name (`1.4.2`), from the platform.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
  retry: (_, _) => null,
);

/// The key of this platform in the server's version rules: `ios`, `android`, or the
/// target platform's own name (`macos`, `windows` ...) - a desktop build never
/// takes the phone rules by mistake.
final appPlatformProvider = Provider<String>(
  (ref) => defaultTargetPlatform.name.toLowerCase(),
);

/// How often the config is read again while maintenance is on.
final appControlPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

/// Opens a store page; false when it could not.
typedef StoreLauncher = Future<bool> Function(Uri url);

final storeLauncherProvider = Provider<StoreLauncher>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// The server's config; null until it was read once. A failed read keeps what
/// was known: the app is only held back when the server says so. While
/// maintenance is on it is read again by itself, until it is lifted.
class AppControlConfigController extends AsyncNotifier<AppControlConfig?> {
  Timer? _timer;
  var _refreshing = false;

  @override
  Future<AppControlConfig?> build() {
    ref.onDispose(() => _timer?.cancel());
    return _read(null);
  }

  /// Read it again (the gate does when the app comes back to the front).
  Future<void> refresh() async {
    if (_refreshing) return; // a burst of 503s reads once
    _refreshing = true;
    try {
      state = AsyncData(await _read(state.value));
    } finally {
      _refreshing = false;
    }
  }

  Future<AppControlConfig?> _read(AppControlConfig? known) async {
    _timer?.cancel();
    AppControlConfig? config;
    try {
      config = await ref.read(appControlApiProvider).config();
    } on Exception catch (e) {
      // Not holding the app back is the point; an Error (a bug) is not caught.
      debugPrint(
        'app-control: reading the config failed, keeping what was known: $e',
      );
      config = known;
    }
    if (config != null && config.maintenance.enabled) {
      _timer = Timer(ref.read(appControlPollIntervalProvider), refresh);
    }
    return config;
  }
}

final appConfigProvider =
    AsyncNotifierProvider<AppControlConfigController, AppControlConfig?>(
      AppControlConfigController.new,
    );

/// The recommended version the person closed: asked again only for a newer one.
class DismissedUpdate extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String version) => state = version;
}

final dismissedUpdateProvider = NotifierProvider<DismissedUpdate, String?>(
  DismissedUpdate.new,
);

/// What the gate shows now.
final appControlStateProvider = Provider<AppState>(
  (ref) => appStateOf(
    ref.watch(appConfigProvider).value,
    appVersion: ref.watch(appVersionProvider).value,
    platform: ref.watch(appPlatformProvider),
    dismissed: ref.watch(dismissedUpdateProvider),
  ),
);

/// A switch the operator made visible to clients. A switch nobody made (or a
/// config not read yet) is off.
final featureProvider = Provider.family<bool, String>(
  (ref, key) => ref.watch(appConfigProvider).value?.flags[key] ?? false,
);

/// Like [featureProvider] with the answer for a switch nobody made (`fallback: true` for
/// a feature that is on until an operator turns it off).
final featureOrProvider = Provider.family<bool, ({String key, bool fallback})>(
  (ref, spec) =>
      ref.watch(appConfigProvider).value?.flags[spec.key] ?? spec.fallback,
);
