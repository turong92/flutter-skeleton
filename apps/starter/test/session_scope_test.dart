import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starter/session_scope.dart';

void main() {
  test('every public provider in lib/ is dropped with the session or exempt '
      '(add one to neither list and this fails)', () {
    final declared = <String>{};
    // A public top-level provider; a private one lives and dies in its file.
    final pattern = RegExp(r'^final\s+([a-z]\w*Provider)\b', multiLine: true);
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // The lists themselves, and the reset provider built from them.
      if (file.path.endsWith('session_scope.dart')) continue;
      for (final m in pattern.allMatches(file.readAsStringSync())) {
        declared.add(m.group(1)!);
      }
    }
    expect(declared, isNotEmpty);
    final classified = {
      ...userScopedProviders.keys,
      ...sessionScopeExempt.keys,
    };
    expect(declared.difference(classified), isEmpty);
    // The names in the lists are real providers, not leftovers.
    expect(classified.difference(declared), isEmpty);
  });

  test('an exemption always gives its reason', () {
    for (final entry in sessionScopeExempt.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });
}
