import 'dart:convert';
import 'dart:io';

/// Writes [files] (path relative to [root] -> text) and returns [root].
Directory writeTree(Directory root, Map<String, String> files) {
  files.forEach((path, text) {
    final file = File('${root.path}/$path')..createSync(recursive: true);
    file.writeAsStringSync(text);
  });
  return root;
}

String pubspec(
  String name, {
  List<String> deps = const [],
  List<String> devDeps = const [],
}) {
  final b = StringBuffer('name: $name\nresolution: workspace\n');
  if (deps.isNotEmpty) {
    b.writeln('dependencies:');
    for (final d in deps) {
      b.writeln('  $d: any # workspace sibling');
    }
  }
  if (devDeps.isNotEmpty) {
    b.writeln('dev_dependencies:');
    for (final d in devDeps) {
      b.writeln('  $d: any');
    }
  }
  return b.toString();
}

/// A catalog entry with every field the schema requires.
Map<String, Object?> entry(
  String id, {
  String kind = 'package',
  String? package,
  String? path,
  List<String> needs = const [],
  Map<String, Object?>? backend,
  List<String> docs = const [],
  String included = 'always',
  List<String> reactIds = const [],
}) => {
  'id': id,
  'kind': kind,
  'summary': 'Summary of $id.',
  'package': package ?? 'skeleton_${id.replaceAll('-', '_')}',
  'path': path ?? 'packages/${id.replaceAll('-', '_')}',
  'stampFlag': {
    'flag': included == 'flag' ? '--packages $id' : null,
    'included': included,
  },
  'needs': needs,
  'backend': backend,
  'pairsWith': {'react': reactIds},
  'docs': docs,
  'notFor': ['nothing'],
  'keywords': {
    'ko': ['예'],
    'en': ['sample'],
  },
};

String json(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
