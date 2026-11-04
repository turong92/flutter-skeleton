// capabilities.json -> docs/capabilities.md and llms.txt, and a check that the catalog says what the repo is.
//
//   dart tool/build_capabilities.dart           # write the generated files, then check
//   dart tool/build_capabilities.dart --check   # write nothing, exit 1 on any mismatch (CI)
//
// What is checked: the entries against packages/* and apps/*, `needs` against the pubspec
// skeleton_* dependencies, `stampFlag.included` against what the starter pulls in, the
// files named in `docs`, the generated files against the catalog, and, only when
// ../kotlin-skeleton and ../react-skeleton are cloned next to this repo, the names the
// catalog borrows from them. The sibling repos are only read.
import 'dart:convert';
import 'dart:io';

import 'workspace.dart';

typedef Json = Map<String, Object?>;

const catalogFile = 'capabilities.json';
const schemaFile = 'docs/capabilities.schema.json';
const generatedMd = 'docs/capabilities.md';
const generatedLlms = 'llms.txt';

Json readJson(File file) => jsonDecode(file.readAsStringSync()) as Json;

List<Json> entriesOf(Json catalog) => [
  for (final e in catalog['capabilities']! as List) e as Json,
];

List<String> stringsOf(Object? list) => [
  for (final s in (list as List? ?? const [])) s as String,
];

// ---------------------------------------------------------------------------- schema

/// Checks [value] against the part of JSON Schema the schema file uses:
/// $ref, type, const, enum, required, properties, additionalProperties: false, items, minItems, minLength.
List<String> checkSchema(Json catalog, Json schema) {
  final problems = <String>[];

  Json resolve(Json node) {
    final ref = node[r'$ref'] as String?;
    if (ref == null) return node;
    var target = schema as Object?;
    for (final part in ref.substring(2).split('/')) {
      target = (target! as Json)[part];
    }
    return target! as Json;
  }

  String typeOf(Object? v) => switch (v) {
    null => 'null',
    String _ => 'string',
    bool _ => 'boolean',
    int _ => 'integer',
    List _ => 'array',
    Map _ => 'object',
    _ => 'number',
  };

  void visit(Object? value, Json rawNode, String at) {
    final node = resolve(rawNode);
    final type = node['type'];
    if (type != null) {
      final allowed = type is List ? stringsOf(type) : [type as String];
      if (!allowed.contains(typeOf(value))) {
        problems.add(
          '$at must be ${allowed.join(' or ')}, is ${typeOf(value)}',
        );
        return;
      }
    }
    if (node.containsKey('const') && value != node['const']) {
      problems.add('$at must be ${node['const']}');
    }
    if (node['enum'] != null && !(node['enum']! as List).contains(value)) {
      problems.add(
        '$at must be one of ${(node['enum']! as List).join(', ')} (is $value)',
      );
    }
    if (value is String && value.length < (node['minLength'] as int? ?? 0)) {
      problems.add('$at is empty');
    }
    if (value is List) {
      if (value.length < (node['minItems'] as int? ?? 0)) {
        problems.add('$at needs at least ${node['minItems']} item(s)');
      }
      final items = node['items'];
      if (items != null) {
        for (var i = 0; i < value.length; i++) {
          visit(value[i], items as Json, '$at[$i]');
        }
      }
    }
    if (value is Map) {
      for (final key in stringsOf(node['required'])) {
        if (!value.containsKey(key)) problems.add('$at is missing "$key"');
      }
      final props = (node['properties'] as Json?) ?? const {};
      for (final key in value.keys) {
        if (props.containsKey(key)) {
          visit(value[key], props[key]! as Json, '$at.$key');
        } else if (node['additionalProperties'] == false) {
          problems.add('$at has "$key", which the schema does not know');
        }
      }
    }
  }

  visit(catalog, schema, 'capabilities.json');
  return problems;
}

// ---------------------------------------------------------------------------- the catalog against this repo

List<String> checkCatalog(
  Directory root,
  Json catalog, [
  String prefix = packagePrefix,
]) {
  final problems = <String>[];
  final entries = entriesOf(catalog);
  final byId = <String, Json>{};
  for (final e in entries) {
    if (byId.containsKey(e['id'])) {
      problems.add('id "${e['id']}" is used twice');
    }
    byId[e['id']! as String] = e;
  }

  final packages = readPackages(root, prefix);
  final idOfName = {for (final p in packages) p.name: p.id};
  final always = packages.any((p) => p.dir == 'apps/starter')
      ? alwaysIds(packages)
      : <String>{};

  for (final p in packages) {
    final e = byId[p.catalogId];
    if (e == null) {
      problems.add(
        '${p.dir} has no entry in $catalogFile (expected id "${p.catalogId}")',
      );
      continue;
    }
    final where = 'entry "${e['id']}"';
    if (e['path'] != p.dir) {
      problems.add('$where: path is "${e['path']}", the folder is ${p.dir}');
    }
    if (e['package'] != p.name) {
      problems.add(
        '$where: package is "${e['package']}", pubspec name is ${p.name}',
      );
    }
    if (e['kind'] != (p.isApp ? 'app' : 'package')) {
      problems.add('$where: kind is "${e['kind']}" for ${p.dir}');
    }

    final declared = {for (final d in p.deps) idOfName[d] ?? d};
    final needs = stringsOf(e['needs']).toSet();
    if (needs.length != declared.length || !needs.containsAll(declared)) {
      problems.add(
        '$where: needs [${stringsOf(e['needs']).join(', ')}] differ from the pubspec skeleton_* dependencies [${declared.toList()..sort()}]',
      );
    }

    if (!p.isApp && always.isNotEmpty) {
      final stamp = e['stampFlag']! as Json;
      final isAlways = stamp['included'] == 'always';
      if (isAlways != always.contains(p.id)) {
        problems.add(
          '$where: stampFlag.included is "${stamp['included']}", but the starter ${always.contains(p.id) ? 'needs' : 'does not need'} it',
        );
      }
      if (!isAlways && stamp['flag'] != '--packages ${p.id}') {
        problems.add(
          '$where: stampFlag.flag must be "--packages ${p.id}", is "${stamp['flag']}"',
        );
      }
    }
  }

  final known = {for (final p in packages) p.catalogId};
  for (final e in entries) {
    if (!known.contains(e['id'])) {
      problems.add('entry "${e['id']}" has no folder (${e['path']})');
    }
    for (final doc in stringsOf(e['docs'])) {
      if (!File('${root.path}/$doc').existsSync()) {
        problems.add(
          'entry "${e['id']}": docs names "$doc", which does not exist',
        );
      }
    }
  }

  final newProject = catalog['newProject'] as Json?;
  if (newProject != null) {
    final script = File('${root.path}/${newProject['script']}');
    if (!script.existsSync()) {
      problems.add(
        'newProject.script "${newProject['script']}" does not exist',
      );
    } else {
      final text = script.readAsStringSync();
      for (final flag in stringsOf(newProject['flags'])) {
        if (!text.contains(flag)) {
          problems.add(
            'newProject.flags names $flag, which ${newProject['script']} does not handle',
          );
        }
      }
    }
  }
  return problems;
}

// ---------------------------------------------------------------------------- the catalog against the sibling repos

List<String> checkSiblings(Directory root, Json catalog) {
  final siblings = catalog['siblings'] as Json?;
  if (siblings == null) return const [];
  final problems = <String>[];
  Directory? clone(String key) {
    final dir = Directory(
      '${root.parent.path}/${(siblings[key]! as Json)['repo']}',
    );
    return dir.existsSync() ? dir : null;
  }

  final kotlin = clone('kotlin');
  if (kotlin != null) {
    final readme = File('${kotlin.path}/docs/modules/README.md');
    final modules = {
      if (readme.existsSync())
        for (final m in RegExp(
          r'^\| `([a-z0-9-]+)` \|',
          multiLine: true,
        ).allMatches(readme.readAsStringSync()))
          m.group(1)!,
    };
    for (final e in entriesOf(catalog)) {
      final b = e['backend'] as Json?;
      if (b == null) continue;
      final named = [
        ...stringsOf(b['modules']),
        ...stringsOf(b['optionalModules']),
        for (final g in b['oneOfModules']! as List) ...stringsOf(g),
      ];
      for (final m in named) {
        if (!modules.contains(m)) {
          problems.add(
            'entry "${e['id']}": backend names module "$m", which ${kotlin.path.split('/').last} docs/modules/README.md does not list',
          );
        }
      }
      for (final doc in stringsOf(b['docs'])) {
        if (!File('${kotlin.path}/$doc').existsSync()) {
          problems.add(
            'entry "${e['id']}": backend.docs names "$doc", which ${kotlin.path.split('/').last} does not have',
          );
        }
      }
    }
  }

  final react = clone('react');
  if (react != null) {
    final file = File(
      '${react.path}/${(siblings['react']! as Json)['catalog']}',
    );
    if (file.existsSync()) {
      final ids = {for (final e in entriesOf(readJson(file))) e['id']};
      for (final e in entriesOf(catalog)) {
        for (final id in stringsOf((e['pairsWith']! as Json)['react'])) {
          if (!ids.contains(id)) {
            problems.add(
              'entry "${e['id']}": pairsWith.react names "$id", which ${react.path.split('/').last} has no entry for',
            );
          }
        }
      }
    }
  }
  return problems;
}

// ---------------------------------------------------------------------------- generated files

const _generatedNote =
    '<!-- Generated from capabilities.json by tool/build_capabilities.dart. Do not edit by hand. -->';
const _projectNote =
    '<!-- Written from capabilities.json when the project was stamped. Keep the two in step by hand. -->';

String _code(String s) => '`$s`';
String _cell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

String _backendText(Json? b) {
  if (b == null) return 'none (Flutter only)';
  final parts = <String>[
    if (stringsOf(b['modules']).isNotEmpty)
      'modules ${stringsOf(b['modules']).map(_code).join(' · ')}',
    for (final g in b['oneOfModules']! as List)
      'one of ${stringsOf(g).map(_code).join(' | ')}',
    if (stringsOf(b['optionalModules']).isNotEmpty)
      'more when present ${stringsOf(b['optionalModules']).map(_code).join(' · ')}',
    if (stringsOf(b['basePaths']).isNotEmpty)
      'paths ${stringsOf(b['basePaths']).map(_code).join(' · ')}',
  ];
  return parts.join(' · ');
}

String _howToTake(Json e) {
  final stamp = e['stampFlag']! as Json;
  return stamp['included'] == 'always'
      ? 'in every project'
      : _code(stamp['flag']! as String);
}

String renderMd(Json catalog) {
  final entries = entriesOf(catalog);
  final out = StringBuffer()
    ..writeln(catalog['mode'] == 'project' ? _projectNote : _generatedNote)
    ..writeln()
    ..writeln('# Capabilities — ${catalog['name']}')
    ..writeln()
    ..writeln(catalog['summary'])
    ..writeln()
    ..writeln(
      'The source is `capabilities.json` (schema `docs/capabilities.schema.json`); this file and `llms.txt` are made from it.',
    )
    ..writeln();
  final skeleton = catalog['skeleton'] as Json?;
  if (skeleton != null) {
    out
      ..writeln(
        'This project was stamped from ${_code(skeleton['name']! as String)}. Below is what **this project has**; for anything else see: ${skeleton['pointer']}',
      )
      ..writeln();
  }
  final np = catalog['newProject'] as Json?;
  if (np != null) {
    out
      ..writeln('## new-project.sh')
      ..writeln()
      ..writeln('- ${_code(np['usage']! as String)}')
      ..writeln()
      ..writeln(
        '`--packages` takes ids from the table; what a package needs comes along. The backend side is built with kotlin-skeleton `new-project.sh --modules` from the modules in the Backend column.',
      )
      ..writeln();
  }
  out
    ..writeln('## Entries')
    ..writeln()
    ..writeln(
      '| id | What it gives | How to take it | Backend modules | Pairs with (react) |',
    )
    ..writeln('|---|---|---|---|---|');
  for (final e in entries) {
    final b = e['backend'] as Json?;
    final react = stringsOf((e['pairsWith']! as Json)['react']);
    out.writeln(
      '| ${_code(e['id']! as String)} | ${_cell(e['summary']! as String)} | ${_cell(_howToTake(e))} | ${b == null ? '—' : _cell(stringsOf(b['modules']).join(', '))} | ${react.isEmpty ? '—' : react.map(_code).join(', ')} |',
    );
  }
  out.writeln();
  for (final e in entries) {
    final kw = e['keywords']! as Json;
    out
      ..writeln('### ${_code(e['id']! as String)} — ${e['summary']}')
      ..writeln()
      ..writeln(
        '- Where: ${_code(e['package']! as String)} (${_code(e['path']! as String)}) · ${e['kind']}',
      )
      ..writeln('- How to take it: ${_howToTake(e)}')
      ..writeln(
        '- Needs: ${stringsOf(e['needs']).isEmpty ? '—' : stringsOf(e['needs']).map(_code).join(' · ')}',
      )
      ..writeln('- Backend: ${_backendText(e['backend'] as Json?)}');
    final docs = stringsOf((e['backend'] as Json?)?['docs']);
    if (docs.isNotEmpty) {
      out.writeln(
        '- Backend docs (kotlin-skeleton): ${docs.map(_code).join(' · ')}',
      );
    }
    if (stringsOf(e['docs']).isNotEmpty) {
      out.writeln('- Docs: ${stringsOf(e['docs']).map(_code).join(' · ')}');
    }
    out
      ..writeln(
        '- Web twin (react-skeleton): ${stringsOf((e['pairsWith']! as Json)['react']).map(_code).join(' · ').ifEmpty('—')}',
      )
      ..writeln('- Not for: ${stringsOf(e['notFor']).join(' / ')}')
      ..writeln(
        '- Keywords: ${stringsOf(kw['ko']).join(', ')} / ${stringsOf(kw['en']).join(', ')}',
      )
      ..writeln();
  }
  final omitted = (catalog['omitted'] as List?) ?? const [];
  if (omitted.isNotEmpty) {
    out
      ..writeln('## Not in this project')
      ..writeln();
    for (final o in omitted) {
      o as Json;
      out.writeln(
        '- ${_code(o['id']! as String)} — ${o['summary']}${o['stampFlag'] == null ? '' : ' (${_code(o['stampFlag']! as String)})'}',
      );
    }
    out.writeln();
  }
  return out.toString();
}

String renderLlms(Json catalog) {
  final out = StringBuffer()
    ..writeln('# ${catalog['name']}')
    ..writeln()
    ..writeln('> ${catalog['summary']}')
    ..writeln();
  final np = catalog['newProject'] as Json?;
  if (np != null) {
    out
      ..writeln('## New project')
      ..writeln()
      ..writeln('- ${_code(np['usage']! as String)}')
      ..writeln('- Details: docs/capabilities.md')
      ..writeln();
  }
  out
    ..writeln('## Capabilities')
    ..writeln();
  for (final e in entriesOf(catalog)) {
    final kw = e['keywords']! as Json;
    final b = e['backend'] as Json?;
    out
      ..writeln('- ${_code(e['id']! as String)}: ${e['summary']}')
      ..writeln(
        '  - take: ${_howToTake(e)}; needs: ${stringsOf(e['needs']).isEmpty ? '—' : stringsOf(e['needs']).join(', ')}',
      )
      ..writeln(
        '  - backend: ${b == null ? '—' : _backendText(b)}; react twin: ${stringsOf((e['pairsWith']! as Json)['react']).join(', ').ifEmpty('—')}',
      )
      ..writeln(
        '  - keywords: ${stringsOf(kw['ko']).join(', ')} / ${stringsOf(kw['en']).join(', ')}',
      );
  }
  return out.toString();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

Map<String, String Function(Json)> get generated => {
  generatedMd: renderMd,
  generatedLlms: renderLlms,
};

void writeGenerated(Directory root, Json catalog) {
  generated.forEach((path, render) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(render(catalog));
  });
}

List<String> checkGenerated(Directory root, Json catalog) => [
  for (final entry in generated.entries)
    if (!File('${root.path}/${entry.key}').existsSync() ||
        File('${root.path}/${entry.key}').readAsStringSync() !=
            entry.value(catalog))
      '${entry.key} is not what $catalogFile produces: run `dart tool/build_capabilities.dart`',
];

// ---------------------------------------------------------------------------- entry point

void main(List<String> args) {
  final check = args.contains('--check');
  final root = File.fromUri(Platform.script).parent.parent;
  final catalog = readJson(File('${root.path}/$catalogFile'));

  final schemaProblems = checkSchema(
    catalog,
    readJson(File('${root.path}/$schemaFile')),
  );
  if (schemaProblems.isNotEmpty) _fail(schemaProblems);

  if (!check) writeGenerated(root, catalog);
  final problems = [
    ...checkCatalog(root, catalog),
    ...checkSiblings(root, catalog),
    ...checkGenerated(root, catalog),
  ];
  if (problems.isNotEmpty) _fail(problems);
  stdout.writeln(
    'capabilities ok — ${entriesOf(catalog).length} entries${check ? ' (generated files up to date)' : ''}',
  );
}

Never _fail(List<String> problems) {
  stderr.writeln('capabilities: ${problems.length} problem(s)\n');
  for (final p in problems) {
    stderr.writeln('  - $p');
  }
  exit(1);
}
