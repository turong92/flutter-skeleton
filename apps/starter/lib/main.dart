import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'config.dart';
import 'router.dart';

void main() {
  // Not an assert: a release build without the define would otherwise start
  // and fail on every request.
  if (AppConfig.apiBaseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL is empty: build with --dart-define-from-file=env/<env>.json',
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        authConfigProvider.overrideWithValue(
          const AuthConfig(apiBaseUrl: AppConfig.apiBaseUrl),
        ),
        tokenStoreProvider.overrideWithValue(SecureTokenStore()),
      ],
      child: const StarterApp(),
    ),
  );
}

class StarterApp extends ConsumerWidget {
  const StarterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Starter',
      theme: skeletonLightTheme(),
      darkTheme: skeletonDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
