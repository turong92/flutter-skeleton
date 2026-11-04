import 'package:flutter/painting.dart';

/// Design tokens as Dart constants. The values are neutral defaults; a project
/// changes them here (or builds its own `ThemeData`).
abstract final class SkeletonColors {
  /// The seed of the Material 3 color scheme, light and dark.
  static const seed = Color(0xFF3F51B5);
}

abstract final class SkeletonSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class SkeletonRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 16.0;
}

abstract final class SkeletonFontSize {
  static const small = 12.0;
  static const body = 14.0;
  static const title = 20.0;
  static const headline = 28.0;
}
