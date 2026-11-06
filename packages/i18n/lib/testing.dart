/// Test helpers for apps that use `skeleton_i18n`: import from tests only
/// (`package:skeleton_i18n/testing.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'src/locale_store.dart';

/// A store that keeps the pick in memory.
class MemoryLocaleStore implements LocaleStore {
  MemoryLocaleStore([this.code]);

  String? code;

  @override
  Future<String?> load() async => code;

  @override
  Future<void> save(String languageCode) async => code = languageCode;

  @override
  Future<void> clear() async => code = null;
}

/// Reads an ARB file into its map.
Map<String, Object?> readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

final _placeholderName = RegExp(r'\{(\w+)\s*[,}]');

/// The `{placeholders}` of a message at its top level: `{name}` and
/// `{count, plural, ...}` count, the words inside a plural or select branch do not.
Set<String> _placeholders(Object? message) {
  final text = '$message';
  final names = <String>{};
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '{') {
      if (depth == 0) {
        final m = _placeholderName.matchAsPrefix(text, i);
        if (m != null) names.add(m.group(1)!);
      }
      depth++;
    } else if (c == '}' && depth > 0) {
      depth--;
    }
  }
  return names;
}

/// What differs between the base-language ARB and a translation: a key one has
/// and the other does not, or a key whose `{placeholders}` are not the same.
/// Empty = the two match. (`@key` metadata and `@@locale` are not texts.)
List<String> arbProblems(
  Map<String, Object?> base,
  Map<String, Object?> translation,
) {
  bool isText(String key) => !key.startsWith('@');
  final baseKeys = base.keys.where(isText).toSet();
  final otherKeys = translation.keys.where(isText).toSet();
  final problems = <String>[
    for (final k in baseKeys.difference(otherKeys))
      'missing in translation: $k',
    for (final k in otherKeys.difference(baseKeys)) 'not in the base: $k',
  ];
  for (final k in baseKeys.intersection(otherKeys)) {
    if (_placeholders(base[k])
            .difference(_placeholders(translation[k]))
            .isNotEmpty ||
        _placeholders(translation[k])
            .difference(_placeholders(base[k]))
            .isNotEmpty) {
      problems.add('placeholders differ: $k');
    }
  }
  return problems..sort();
}
