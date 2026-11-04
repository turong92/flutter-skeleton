/// The in-app path of a notification's `link`, or null. Only a path that
/// starts with `/` is taken; `//host` (and its backslash form), a scheme,
/// a backslash and control characters are dropped, so a notification cannot
/// open another site. Same rule as `safePushLink` in `skeleton_push` (the
/// packages do not import each other).
String? safeNotificationLink(Object? raw) {
  if (raw is! String) return null;
  if (!raw.startsWith('/')) return null;
  if (raw.startsWith('//')) return null;
  if (raw.contains('\\')) return null;
  if (raw.runes.any((c) => c < 0x20 || c == 0x7f)) return null;
  return raw;
}
