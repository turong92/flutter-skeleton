import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:skeleton_push/skeleton_push.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'config.dart';
import 'firebase_setup.dart';
import 'router.dart';
import 'screens/store_screen.dart';
import 'wiring.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Not an assert: a release build without the define would otherwise start
  // and fail on every request.
  if (AppConfig.apiBaseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL is empty: build with --dart-define-from-file=env/<env>.json',
    );
  }
  // No Firebase values: nothing starts and push stays "unavailable".
  await initFirebaseIfConfigured();
  runApp(
    ProviderScope(
      overrides: [
        authConfigProvider.overrideWithValue(
          const AuthConfig(apiBaseUrl: AppConfig.apiBaseUrl),
        ),
        tokenStoreProvider.overrideWithValue(SecureTokenStore()),
        signUpAttemptStoreProvider.overrideWithValue(
          SecureSignUpAttemptStore(),
        ),
        ...sampleWiring,
      ],
      child: const SampleApp(),
    ),
  );
}

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

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class SampleApp extends ConsumerWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_pushSetupProvider);
    // Watched from the root so the store's left-over purchases are picked up
    // at start; what the server said to each purchase is shown wherever the
    // person is.
    ref.watch(iapServiceProvider);
    ref.listen(iapOutcomesProvider, (_, next) {
      final outcome = next.value;
      if (outcome == null) return;
      if (outcome is IapGranted) ref.invalidate(mySubscriptionProvider);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(iapOutcomeText(outcome))),
      );
    });
    // iOS shows a message that arrives in front by itself; Android does not.
    ref.listen(pushMessagesProvider, (_, next) {
      final message = next.value;
      if (message == null || defaultTargetPlatform != TargetPlatform.android) {
        return;
      }
      final text = message.title ?? message.body;
      if (text == null) return;
      final link = message.link;
      // The messenger's context sits below MaterialApp, so it carries the app theme.
      final scheme = Theme.of(_messengerKey.currentContext ?? context)
          .colorScheme;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text),
          action: link == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  onPressed: () => ref.read(routerProvider).go(link),
                ),
        ),
      );
    });
    return MaterialApp.router(
      title: 'Sample',
      scaffoldMessengerKey: _messengerKey,
      theme: skeletonLightTheme(),
      darkTheme: skeletonDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
