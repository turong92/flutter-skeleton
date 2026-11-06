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
    // Buttons Flutter draws itself (time/date picker OK and Cancel) are
    // TextButtons; give them a border so they read as pressable at rest.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        // Height only: an infinite minimum width breaks a button inside a
        // Row. A full-width button says so where it is placed.
        minimumSize: const Size(0, 48),
      ),
    ),
  );
}
