import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// #if social-login-kakao
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
// #endif
// #if push
import 'package:flutter/foundation.dart';
// #endif
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_error_report/skeleton_error_report.dart';
// #if ads
import 'package:skeleton_ads/skeleton_ads.dart';
// #endif
// #if app-control
import 'package:skeleton_app_control/skeleton_app_control.dart';
// #endif
// #if audio
import 'package:skeleton_audio/skeleton_audio.dart';
// #endif
// #if i18n
import 'package:skeleton_i18n/skeleton_i18n.dart';
// #endif
// #if iap
import 'package:skeleton_iap/skeleton_iap.dart';
// #endif
// #if notifications push
import 'package:skeleton_notifications/skeleton_notifications.dart';
// #endif
// #if push
import 'package:skeleton_push/skeleton_push.dart';
// #endif
// #if social-login
import 'package:skeleton_social_login/skeleton_social_login.dart';
// #endif
import 'package:skeleton_ui/skeleton_ui.dart';

import 'l10n/l10n.dart';
import 'config.dart';
// #if push
import 'firebase_setup.dart';
// #endif
// #if notifications realtime
import 'inbox_realtime.dart';
// #endif
import 'router.dart';
import 'session_scope.dart';
// #if social-login
import 'social_support.dart';
// #endif
// #if iap
import 'screens/store_screen.dart';
// #endif
import 'wiring.dart';

/// The app's providers, once it has started: the error reporter reads the last
/// request's trace id and the current screen from it.
ProviderContainer? _container;

/// Where what the app could not handle goes: the backend's client-errors path
/// (off unless `ERROR_REPORT=true`, like the path on the server). Replace it
/// with another `ErrorReporter` (Sentry, ...) and nothing else changes.
ErrorReporter _errorReporter() {
  if (!AppConfig.errorReport) return const NoopErrorReporter();
  return ServerErrorReporter(
    endpoint: Uri.parse('${AppConfig.apiBaseUrl}/client-errors'),
    release: AppConfig.appRelease.isEmpty ? null : AppConfig.appRelease,
    traceId: () => _container?.read(apiClientProvider).lastTraceId,
    route: () => _container
        ?.read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .path,
  );
}

Future<void> main() async {
  final reporter = _errorReporter();
  installErrorReporting(reporter);
  // The whole start in one zone, so an error nobody caught also reaches it.
  await runReportedZoned(reporter, () => _start(reporter));
}

Future<void> _start(ErrorReporter reporter) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Repeats that were folded are sent when the app goes to the background.
  AppLifecycleListener(onPause: reporter.flush);
  // Not an assert: a release build without the define would otherwise start
  // and fail on every request.
  if (AppConfig.apiBaseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL is empty: build with --dart-define-from-file=env/<env>.json',
    );
  }
  // #if push
  // No Firebase values: nothing starts and push stays "unavailable".
  await initFirebaseIfConfigured();
  // #endif
  // #if social-login-kakao
  // The Kakao SDK is started by the app, and only with a key (no key = no
  // Kakao button).
  if (AppConfig.kakaoNativeAppKey.isNotEmpty) {
    await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  }
  // #endif
  // #if i18n
  // The language the person picked last time (before the first frame).
  const languageStore = SharedPreferencesLocaleStore();
  final savedLocale = await loadSavedLocale(languageStore);
  // #endif
  // #if audio
  // The sound settings the person kept last time (before the first frame).
  const audioStore = SharedPreferencesAudioSettingsStore();
  final savedAudio = await loadSavedAudioSettings(audioStore);
  // #endif
  final container = ProviderContainer(
    overrides: [
      // #if audio
      savedAudioSettingsProvider.overrideWithValue(savedAudio),
      // #endif
      // #if i18n
      savedLocaleProvider.overrideWithValue(savedLocale),
      localeStoreProvider.overrideWithValue(languageStore),
      // #endif
      authConfigProvider.overrideWithValue(
        const AuthConfig(apiBaseUrl: AppConfig.apiBaseUrl),
      ),
      tokenStoreProvider.overrideWithValue(SecureTokenStore()),
      signUpAttemptStoreProvider.overrideWithValue(SecureSignUpAttemptStore()),
      ...starterWiring,
      // #if social-login
      // Which providers this build has; the server's /auth/methods then
      // narrows them to the ones shown. Not in starterWiring: tests bring
      // their own, since a provider SDK cannot run in a widget test.
      socialProvidersProvider.overrideWith((ref) => buildSocialProviders()),
      // #endif
    ],
  );
  _container = container;
  runApp(
    UncontrolledProviderScope(container: container, child: const StarterApp()),
  );
}

// #if push
/// Push needs two things the packages leave to the app: the sign-out hook that
/// deletes this device on the server, and the controller being alive (it
/// registers the device and hands over tapped notifications).
final _pushSetupProvider = Provider<void>((ref) {
  ref.watch(pushControllerProvider);
  // Without Firebase there is no registration to delete.
  if (ref.watch(pushTokenSourceProvider).available) {
    final remove = ref
        .read(signOutHooksProvider)
        .add(ref.read(pushSignOutHookProvider));
    ref.onDispose(remove);
  }
});

// #endif
// #if social-login
/// Sign-out also ends the providers' own SDK sessions.
final _socialSetupProvider = Provider<void>((ref) {
  final remove = ref
      .read(signOutHooksProvider)
      .add(ref.read(socialSignOutHookProvider));
  ref.onDispose(remove);
});

// #endif
// #if push|iap
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

// #endif
class StarterApp extends ConsumerWidget {
  const StarterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // What one person's data sits in is dropped with the session.
    ref.watch(sessionResetProvider);
    // #if social-login
    ref.watch(_socialSetupProvider);
    // #endif
    // #if ads
    // Consent first, then the SDK: the banner stays empty until it is ready.
    ref.watch(adsControllerProvider);
    // #endif
    // #if iap
    // Watched from the root so the store's left-over purchases are picked up
    // at start; what the server said to each purchase is shown wherever the
    // person is.
    ref.watch(iapServiceProvider);
    ref.listen(iapOutcomesProvider, (_, next) {
      final outcome = next.value;
      if (outcome == null) return;
      if (outcome is IapGranted) ref.invalidate(mySubscriptionProvider);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            iapOutcomeText(
              _messengerKey.currentContext?.l10n ??
                  lookupAppLocalizations(const Locale('ko')),
              outcome,
            ),
          ),
        ),
      );
    });
    // #endif
    // #if push
    ref.watch(_pushSetupProvider);
    // iOS shows a message that arrives in front by itself; Android does not.
    ref.listen(pushMessagesProvider, (_, next) {
      final message = next.value;
      if (message == null) return;
      if (defaultTargetPlatform != TargetPlatform.android) return;
      final text = message.title ?? message.body;
      if (text == null) return;
      final link = message.link;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text),
          action: link == null
              ? null
              : SnackBarAction(
                  label: (_messengerKey.currentContext ?? context).l10n.open,
                  onPressed: () => ref.read(routerProvider).go(link),
                ),
        ),
      );
    });
    // #endif
    // #if notifications push
    // The push is the same notification the inbox holds: read it again.
    ref.listen(pushMessagesProvider, (_, next) {
      if (next.value != null) notificationsChanged(ref);
    });
    // #endif
    // #if notifications realtime
    // The notification stream while signed in and in front.
    ref.watch(inboxRealtimeProvider);
    // #endif
    return MaterialApp.router(
      // #if push|iap
      scaffoldMessengerKey: _messengerKey,
      // #endif
      title: 'Starter',
      // #if app-control
      // Maintenance, a forced update and the recommended-update notice sit
      // above every screen; the config is read at start and whenever the app
      // comes back to the front.
      builder: (context, child) => AppControlGate(
        labels: context.byLocale(
          const AppControlLabels.ko(),
          const AppControlLabels(),
        ),
        child: child!,
      ),
      // #endif
      // Korean first: it is the language an unsupported device language falls back to.
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // #if i18n
      locale: ref.watch(localeProvider),
      // #endif
      theme: skeletonLightTheme(),
      darkTheme: skeletonDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
