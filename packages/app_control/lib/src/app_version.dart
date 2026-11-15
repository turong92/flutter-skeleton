/// An app version: one to four numbers (`1.10.2`), compared number by number -
/// text order puts `1.10` before `1.9`. A missing trailing part counts as 0
/// (`1.2` equals `1.2.0`). A store build number (`+45`) and a suffix
/// (`-beta.1`) are cut off, since the limits are set on the version name.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.parts);

  final List<int> parts;

  static final _shape = RegExp(r'^\d{1,9}(\.\d{1,9}){0,3}$');

  /// Null when it cannot be read - a version nobody can read never forces an
  /// update.
  static AppVersion? parse(String raw) {
    final core = raw.trim().split(RegExp(r'[+-]')).first;
    if (!_shape.hasMatch(core)) return null;
    return AppVersion._([for (final part in core.split('.')) int.parse(part)]);
  }

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}

/// Is [version] lower than [limit]? False when either cannot be read.
bool isVersionBelow(String version, String limit) {
  final a = AppVersion.parse(version);
  final b = AppVersion.parse(limit);
  if (a == null || b == null) return false;
  return a.compareTo(b) < 0;
}
