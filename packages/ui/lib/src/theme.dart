import 'package:flutter/material.dart';

import 'tokens.dart';

/// Light theme. The app follows the system setting with
/// `MaterialApp(theme: skeletonLightTheme(), darkTheme: skeletonDarkTheme())`.
ThemeData skeletonLightTheme() => _theme(Brightness.light);

ThemeData skeletonDarkTheme() => _theme(Brightness.dark);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: SkeletonColors.seed,
    brightness: brightness,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(SkeletonRadius.md),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SkeletonRadius.md),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size.fromHeight(48),
      ),
    ),
  );
}
