import 'dart:io';

/// Checks the Korean sets of this package: for every `class XxxLabels` in the
/// `.dart` files directly in [libSrc], the `XxxLabels.ko()` constructor must
/// name every field the main constructor has (a field it leaves out would
/// quietly stay English). With [requireAll] a Labels class without `.ko()` is a
/// problem too. Empty = fine.
List<String> koLabelProblems(String libSrc, {bool requireAll = false}) {
  final problems = <String>[];
  final fieldRe = RegExp(r'this\.(\w+)');
  final namedRe = RegExp(r'[(,\s](\w+):\s');
  for (final file in Directory(libSrc).listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final source = file.readAsStringSync();
    for (final m in RegExp(
      r'^class (\w+Labels) \{',
      multiLine: true,
    ).allMatches(source)) {
      final name = m.group(1)!;
      final mainStart = source.indexOf('const $name(', m.start);
      final mainEnd = source.indexOf('});', mainStart);
      final koStart = source.indexOf('const $name.ko()', m.start);
      if (koStart < 0) {
        if (requireAll) problems.add('$name has no .ko()');
        continue;
      }
      final koEnd = source.indexOf(');', koStart);
      final fields = {
        for (final f in fieldRe.allMatches(
          source.substring(mainStart, mainEnd),
        ))
          f.group(1)!,
      };
      final named = {
        for (final f in namedRe.allMatches(source.substring(koStart, koEnd)))
          f.group(1)!,
      };
      for (final f in fields.difference(named)) {
        problems.add('$name.ko() leaves out $f');
      }
      for (final f in named.difference(fields)) {
        problems.add('$name.ko() names $f, which is not a field');
      }
    }
  }
  return problems..sort();
}
