/// The in-app path of a tapped notification's `data.link`, or null. Only a
/// path that starts with `/` is taken; `//host` (and its backslash form), a
/// scheme and anything else are dropped, so a push cannot open another site.
String? safePushLink(Object? raw) {
  if (raw is! String) return null;
  if (!raw.startsWith('/')) return null;
  if (raw.startsWith('//') || raw.startsWith('/\\')) return null;
  return raw;
}
