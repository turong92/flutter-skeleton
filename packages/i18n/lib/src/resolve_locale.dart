import 'dart:ui';

/// Which language the app shows: the saved pick, else the first device
/// language the app supports (by language code), else [fallback]. A saved pick
/// the app no longer supports is ignored.
Locale resolveLocale({
  required List<Locale> supported,
  required Locale fallback,
  Locale? saved,
  List<Locale> device = const [],
}) {
  Locale? match(Locale wanted) {
    for (final s in supported) {
      if (s.languageCode == wanted.languageCode) return s;
    }
    return null;
  }

  if (saved != null) {
    final m = match(saved);
    if (m != null) return m;
  }
  for (final d in device) {
    final m = match(d);
    if (m != null) return m;
  }
  return fallback;
}
