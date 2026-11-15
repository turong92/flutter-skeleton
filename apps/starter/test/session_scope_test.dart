import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starter/session_scope.dart';

/// The top-level providers a Dart source declares, public and private:
/// `final x = FutureProvider...`, `final FutureProvider<T> x = ...`, whatever
/// the name ends with. Private ones that are `.autoDispose` are left out: no
/// screen holds them once the session ends and its screens are gone; a
/// private one that stays alive can only be exempt (another file cannot list
/// it, so it must say why it holds no one's data).
Set<String> declaredProviders(String source) {
  final pattern = RegExp(
    r'^final\s+(?:[\w<>?,. ]+?\s+)?(_?\w+)\s*=\s*(\w*Provider)((?:\.\w+)*)',
    multiLine: true,
  );
  return {
    for (final m in pattern.allMatches(source))
      if (!(m.group(1)!.startsWith('_') && m.group(3)!.contains('autoDispose')))
        m.group(1)!,
  };
}

void main() {
  test('every provider in lib/ is dropped with the session or exempt '
      '(add one to neither list and this fails)', () {
    final declared = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // The lists themselves, and the reset provider built from them.
      if (file.path.endsWith('session_scope.dart')) continue;
      declared.addAll(declaredProviders(file.readAsStringSync()));
    }
    expect(declared, isNotEmpty);
    // A provider of a package may be in the list too, so the names in the
    // lists are not compared back: a renamed one would not compile.
    final classified = {
      ...userScopedProviders.keys,
      ...sessionScopeExempt.keys,
    };
    expect(declared.difference(classified), isEmpty);
  });

  test('an exemption always gives its reason', () {
    for (final entry in sessionScopeExempt.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('the scan sees the declarations a plain pattern would miss', () {
    expect(
      declaredProviders('''
final FutureProvider<int?> typedFirst =
    FutureProvider<int?>((ref) async => 1);
final cart = NotifierProvider<Cart, int>(Cart.new);
final _kept = Provider<int>((ref) => 1);
final _gone = FutureProvider.autoDispose<int>((ref) async => 1);
final publicGone = FutureProvider.autoDispose<int>((ref) async => 1);
final notAProvider = GlobalKey<ScaffoldMessengerState>();
final list = <Override>[];
'''),
      {'typedFirst', 'cart', '_kept', 'publicGone'},
    );
  });
}
