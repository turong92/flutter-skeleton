import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeleton_auth/skeleton_auth.dart';
import 'package:skeleton_ui/skeleton_ui.dart';

import 'config.dart';
import 'router.dart';

void main() {
  assert(
    AppConfig.apiBaseUrl.isNotEmpty,
    'API_BASE_URL is empty: run with --dart-define-from-file=env/dev.json',
  );
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
