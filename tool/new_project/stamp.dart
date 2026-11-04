// The string work of scripts/new-project.sh: which packages to keep, the copy, and the renames.
//
//   dart tool/new_project/stamp.dart plan  <src> <requested,ids>
//   dart tool/new_project/stamp.dart copy  <src> <target>
//   dart tool/new_project/stamp.dart apply <target> <name> <org> <prefix|-> <kept,ids>
//
// Nothing is skipped quietly: a file that is missing or a text that is not there stops the
// stamp (exit 1), so a skeleton change that the stamper does not know about shows up at once.
import 'dart:convert';
import 'dart:io';

import '../build_capabilities.dart';
import '../workspace.dart';

class StampError implements Exception {
  StampError(this.message);
  final String message;
  @override
  String toString() => message;
}

class StampOptions {
  const StampOptions({
    required this.name,
    required this.org,
    required this.keep,
    this.prefix,
  });

  /// Dart package name of the app (`acme_app`); the folder is `apps/<name>`.
  final String name;

  /// Reverse-domain organisation (`com.example`).
  final String org;

  /// Ids of the packages to keep (from [planKeep]).
  final List<String> keep;

  /// Replaces `skeleton_` in package names and imports when set.
  final String? prefix;
}

/// [text] with every [from] replaced; stops when [from] is not in it.
String replaceOrFail(String text, String from, String to, String where) {
  if (!text.contains(from)) {
    throw StampError('"$from" is not in $where, so it cannot be renamed');
  }
  return text.replaceAll(from, to);
}

// ---------------------------------------------------------------------------- plan

class Plan {
  Plan(this.keep, this.why);
  final List<String> keep;
  final Map<String, String> why;
}

/// What a stamped project keeps: the starter's closure, the root tooling and [requested]
/// (ids, e.g. `api-client`) with what they need.
Plan planKeep(List<PubPackage> all, List<String> requested) {
  final packages = all.where((p) => !p.isApp).toList();
  final ids = packages.map((p) => p.id).toSet();
  for (final id in requested) {
    if (!ids.contains(id)) {
      throw StampError(
        'unknown package: $id (valid: ${(ids.toList()..sort()).join(' ')})',
      );
    }
  }
  final byName = {for (final p in all) p.name: p};
  final why = <String, String>{};
  void add(PubPackage p, String reason) {
    if (why.containsKey(p.id)) {
      return;
    }
    why[p.id] = reason;
    for (final dep in p.deps) {
      final d = byName[dep];
      if (d != null) {
        add(d, 'needed by ${p.id}');
      }
    }
  }

  final starter = all.where((p) => p.dir == 'apps/starter');
  for (final s in starter) {
    for (final dep in s.deps) {
      if (byName[dep] != null) {
        add(byName[dep]!, 'the starter uses it');
      }
    }
  }
  for (final p in packages) {
    if (rootToolIds.contains(p.id)) {
      add(p, 'root tooling');
    }
  }
  for (final id in requested) {
    final p = packages.firstWhere((p) => p.id == id);
    why.remove(id); // "requested" wins over a weaker reason
    add(p, 'requested');
  }
  return Plan(why.keys.toList()..sort(), why);
}

// ---------------------------------------------------------------------------- copy

const _skipDirs = {
  '.dart_tool',
  'build',
  '.git',
  '.claude',
  '.superpowers',
  '.gradle',
  'Pods',
  'ephemeral',
  '.symlinks',
  '.melos_tool',
  '.idea',
};
const _skipFiles = {
  '.DS_Store',
  'pubspec_overrides.yaml',
  'local.properties',
  'key.properties',
  'Generated.xcconfig',
  'flutter_export_environment.sh',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
};

void copyTree(Directory src, Directory dst) {
  dst.createSync(recursive: true);
  for (final item in src.listSync(followLinks: false)) {
    final name = item.path.split('/').last;
    if (item is Directory) {
      if (!_skipDirs.contains(name)) {
        copyTree(item, Directory('${dst.path}/$name'));
      }
    } else if (item is File) {
      final isLocalEnv =
          item.parent.path.endsWith('/env') && name.endsWith('.json');
      if (!_skipFiles.contains(name) && !name.endsWith('.iml') && !isLocalEnv) {
        item.copySync('${dst.path}/$name');
      }
    }
  }
}

// ---------------------------------------------------------------------------- apply

String _display(String name) => name
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _read(Directory t, String rel) {
  final file = File('${t.path}/$rel');
  if (!file.existsSync()) {
    throw StampError('$rel is missing, so it cannot be renamed');
  }
  return file.readAsStringSync();
}

void _write(Directory t, String rel, String text) =>
    File('${t.path}/$rel').writeAsStringSync(text);

/// Reads [rel], applies [changes] (each stops when its text is missing) and writes it back.
void _edit(Directory t, String rel, List<(String, String)> changes) {
  var text = _read(t, rel);
  for (final (from, to) in changes) {
    text = replaceOrFail(text, from, to, rel);
  }
  _write(t, rel, text);
}

void _delete(Directory t, String rel) {
  final path = '${t.path}/$rel';
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.notFound) {
    throw StampError('$rel is missing, so it cannot be removed');
  }
  if (type == FileSystemEntityType.directory) {
    Directory(path).deleteSync(recursive: true);
  } else {
    File(path).deleteSync();
  }
}

void applyStamp(Directory target, StampOptions o) {
  final name = o.name;
  final display = _display(name);
  final appId = '${o.org}.$name';
  final iosId = appId.replaceAll(
    '_',
    '-',
  ); // an iOS bundle id has no underscore
  final all = readPackages(target);

  // 1. packages that were not asked for
  for (final p in all) {
    if (!p.isApp && !o.keep.contains(p.id)) {
      _delete(target, p.dir);
    }
  }

  // 2. the app: starter -> name
  const app = 'apps/starter';
  _edit(target, '$app/pubspec.yaml', [('name: starter\n', 'name: $name\n')]);
  _write(
    target,
    '$app/pubspec.yaml',
    _read(target, '$app/pubspec.yaml').replaceFirst(
      RegExp(r'^description: .*$', multiLine: true),
      'description: $display app.',
    ),
  );
  _edit(target, '$app/android/app/build.gradle.kts', [
    ('com.example.starter', appId),
  ]);
  _edit(target, '$app/android/app/src/main/AndroidManifest.xml', [
    ('android:label="starter"', 'android:label="$display"'),
  ]);
  const kotlinDir = '$app/android/app/src/main/kotlin';
  _edit(target, '$kotlinDir/com/example/starter/MainActivity.kt', [
    ('package com.example.starter', 'package $appId'),
  ]);
  final newDir = Directory(
    '${target.path}/$kotlinDir/${appId.replaceAll('.', '/')}',
  )..createSync(recursive: true);
  File('${target.path}/$kotlinDir/com/example/starter/MainActivity.kt')
      .renameSync('${newDir.path}/MainActivity.kt');
  _pruneEmpty(
    Directory('${target.path}/$kotlinDir/com/example/starter'),
    '${target.path}/$kotlinDir',
  );
  _edit(target, '$app/ios/Runner.xcodeproj/project.pbxproj', [
    ('com.example.starter', iosId),
  ]);
  for (final plist in ['Info.plist', 'Info-Debug.plist']) {
    _edit(target, '$app/ios/Runner/$plist', [
      ('<string>Starter</string>', '<string>$display</string>'),
      ('<string>starter</string>', '<string>$name</string>'),
    ]);
  }
  _edit(target, '$app/lib/main.dart', [
    ("title: 'Starter'", "title: '$display'"),
  ]);
  _edit(target, '$app/lib/screens/login_screen.dart', [
    ("Text('Starter')", "Text('$display')"),
  ]);
  _edit(target, '$app/test/app_test.dart', [
    ('package:starter/main.dart', 'package:$name/main.dart'),
  ]);
  _edit(target, '$app/README.md', [('# starter\n', '# $name\n')]);
  if (name != 'starter') {
    Directory('${target.path}/$app').renameSync('${target.path}/apps/$name');
  }

  // 3. the root pubspec: workspace list, name
  _rewriteRootPubspec(target, name, o.keep, all);

  // 4. what a project does not carry: the tools and the skeleton's own notes
  for (final rel in [
    'tool',
    'scripts/new-project.sh',
    'scripts/test-new-project.sh',
    'docs/superpowers',
    '.github/workflows/new-project.yml',
  ]) {
    _delete(target, rel);
  }
  _pruneEmpty(Directory('${target.path}/scripts'), target.path);
  _edit(target, '.github/workflows/ci.yml', [
    ('working-directory: apps/starter', 'working-directory: apps/$name'),
  ]);
  var ci = _read(target, '.github/workflows/ci.yml');
  final catalogStep = RegExp(
    r'^      # The catalog says what.*\n      - run: dart tool/build_capabilities\.dart --check\n',
    multiLine: true,
  );
  if (!catalogStep.hasMatch(ci)) {
    throw StampError(
      'the catalog check step is not in .github/workflows/ci.yml, so it cannot be removed',
    );
  }
  ci = ci.replaceFirst(catalogStep, '');
  _write(target, '.github/workflows/ci.yml', ci);

  // 5. --prefix: skeleton_ -> <prefix>_ in package names, imports and their docs
  final prefix = o.prefix;
  if (prefix != null) {
    _applyPrefix(target, prefix, o.keep, readPackages(target));
  }

  // 6. the catalog and the project's own docs
  _writeProjectCatalog(
    target,
    o,
    prefix == null ? packagePrefix : '${prefix}_',
  );
  _writeProjectDocs(target, o);
}

void _pruneEmpty(Directory dir, String stopAt) {
  var d = dir;
  while (d.path != stopAt && d.existsSync() && d.listSync().isEmpty) {
    d.deleteSync();
    d = d.parent;
  }
}

void _rewriteRootPubspec(
  Directory t,
  String name,
  List<String> keep,
  List<PubPackage> all,
) {
  var text = _read(t, 'pubspec.yaml');
  text = replaceOrFail(
    text,
    'name: flutter_skeleton_workspace\n',
    'name: ${name}_workspace\n',
    'pubspec.yaml',
  );
  text = text.replaceFirst(
    RegExp(r'^description: .*$', multiLine: true),
    'description: Workspace root of $name. Not published; each package under packages/ is picked on its own.',
  );
  final block = RegExp(r'^workspace:\n((?:  - .*\n)+)', multiLine: true);
  if (!block.hasMatch(text)) {
    throw StampError('the workspace: list is not in pubspec.yaml');
  }
  final dirs = [
    for (final p in all)
      if (p.isApp) 'apps/$name' else if (keep.contains(p.id)) p.dir,
  ];
  text = text.replaceFirst(
    block,
    'workspace:\n${dirs.map((d) => '  - $d\n').join()}',
  );
  _write(t, 'pubspec.yaml', text);
}

void _applyPrefix(
  Directory t,
  String prefix,
  List<String> keep,
  List<PubPackage> kept,
) {
  // every kept package must be renamed, or the stamp stops
  for (final p in kept) {
    if (p.isApp || !keep.contains(p.id)) {
      continue;
    }
    final oldName = pubspecName(_read(t, '${p.dir}/pubspec.yaml'))!;
    _edit(t, '${p.dir}/pubspec.yaml', [
      ('name: $packagePrefix', 'name: ${prefix}_'),
    ]);
    // the package's main library is lib/<name>.dart: `package:shop_ui/shop_ui.dart`
    final lib = Directory('${t.path}/${p.dir}/lib');
    if (lib.listSync().any((f) => f is File && f.path.endsWith('.dart'))) {
      final main = File('${lib.path}/$oldName.dart');
      if (!main.existsSync()) {
        throw StampError(
          '${p.dir}/lib/$oldName.dart is missing, so it cannot be renamed',
        );
      }
      main.renameSync(
        '${lib.path}/${prefix}_${oldName.substring(packagePrefix.length)}.dart',
      );
    }
  }
  const textExtensions = {'.dart', '.yaml', '.json', '.md'};
  for (final item in t.listSync(recursive: true, followLinks: false)) {
    if (item is! File || item.path.contains('/.git/')) {
      continue;
    }
    if (!textExtensions.any(item.path.endsWith)) {
      continue;
    }
    final text = item.readAsStringSync();
    if (text.contains(packagePrefix)) {
      item.writeAsStringSync(text.replaceAll(packagePrefix, '${prefix}_'));
    }
  }
}

// ---------------------------------------------------------------------------- catalog and docs

void _writeProjectCatalog(Directory t, StampOptions o, String prefix) {
  final skeleton = readJson(File('${t.path}/$catalogFile'));
  final entries = entriesOf(skeleton);
  final appId = 'app-${o.name.replaceAll('_', '-')}';
  final kept = <Json>[];
  final omitted = <Json>[];
  for (final e in entries) {
    if (e['kind'] == 'app') {
      kept.add({
        ...e,
        'id': appId,
        'package': o.name,
        'path': 'apps/${o.name}',
        'docs': [
          for (final d in stringsOf(e['docs']))
            d.replaceFirst('apps/starter/', 'apps/${o.name}/'),
        ],
      });
    } else if (o.keep.contains(
      (e['path']! as String).split('/').last.replaceAll('_', '-'),
    )) {
      kept.add(e);
    } else {
      omitted.add({
        'id': e['id'],
        'kind': e['kind'],
        'summary': e['summary'],
        'stampFlag': (e['stampFlag']! as Json)['flag'],
      });
    }
  }
  final project = <String, Object?>{
    r'$schema': skeleton[r'$schema'],
    'schemaVersion': 1,
    'mode': 'project',
    'name': o.name,
    'summary':
        '${_display(o.name)}: a Flutter app stamped from flutter-skeleton. The backend is kotlin-skeleton.',
    'skeleton': {
      'name': 'flutter-skeleton',
      'pointer': 'the capabilities.json of the flutter-skeleton repo',
    },
    'capabilities': kept,
    if (omitted.isNotEmpty) 'omitted': omitted,
  };
  File('${t.path}/$catalogFile').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(project)}\n',
  );
  writeGenerated(t, project);
  final problems = [
    ...checkSchema(project, readJson(File('${t.path}/$schemaFile'))),
    ...checkCatalog(t, project, prefix),
    ...checkGenerated(t, project),
  ];
  if (problems.isNotEmpty) {
    throw StampError(
      'the stamped catalog does not match the stamped project:\n  - ${problems.join('\n  - ')}',
    );
  }
}

void _writeProjectDocs(Directory t, StampOptions o) {
  final name = o.name;
  final prefix = o.prefix ?? 'skeleton';
  final catalog = readJson(File('${t.path}/$catalogFile'));
  final structure = [
    for (final e in entriesOf(catalog)) '- `${e['path']}` — ${e['summary']}',
  ].join('\n');

  _write(t, 'README.md', '''# $name

Flutter app stamped from flutter-skeleton (Pub Workspaces + Melos). Sign in, see who you are, sign out; the rest is added as the project needs it. The backend is kotlin-skeleton.

## Structure

$structure

`capabilities.json` says what is in this project (`omitted` lists what flutter-skeleton has and this project does not); `docs/capabilities.md` and `llms.txt` are written from it.

## Commands

```bash
flutter pub get                                    # resolve the whole workspace
melos run analyze                                  # flutter analyze in every package
melos run test                                     # every package that has test/
dart format --output=none --set-exit-if-changed .  # the format check CI runs
```

Melos: `dart pub global activate melos`. While working run `flutter analyze` and `flutter test` (`dart test` for a pure Dart package) in the changed folder only.

## Settings

The app reads `API_BASE_URL` (with `/api/v1`) from `--dart-define-from-file=env/dev.json`. `env/*.json` is ignored by git; copy `apps/$name/env/dev.json.example`.

## Android and iOS ids

Android `applicationId` and iOS bundle id are `${o.org}.$name` (underscores become hyphens on iOS). Change them before the first store upload.
''');

  _write(t, 'CLAUDE.md', '''# $name — Claude Code context

Flutter app stamped from flutter-skeleton. Pub Workspaces + Melos; the app is `apps/$name`, packages are under `packages/`. The backend is kotlin-skeleton (its `docs/account-http-contract.md`, `docs/modules/auth.md` and `docs/modules/auth-session.md` are the contract).

## Rules

- **Package boundaries**: packages call each other by name (`${prefix}_<id>`) and never import `package:x/src/...`. A declared dependency = a real import. The lints (`implementation_imports`, `depend_on_referenced_packages`) enforce it.
- **State management is Riverpod 3 (`flutter_riverpod`), providers written by hand.** No `riverpod_generator`, no `build_runner`.
- **The workspace list in the root `pubspec.yaml` takes no globs**: a new package is one more path line, and `resolution: workspace` in its pubspec.
- **Dependencies use carets (`^x.y.z`) and `pubspec.lock` is committed.**
- **The SDK version lives in one place**: root `environment.flutter`. CI reads it there.
- **Tokens are not logged.** Do not print `Authorization`; a `TokenStore`'s `toString` must not show values.
- **Cleartext http is for debug builds only** (Android `src/debug`, iOS `Info-Debug.plist`). Keep the two plists in step.
- Defaults are neutral; choices are overridden in app settings (`env/*.json`) or app code.

## Commands

- Resolve: `flutter pub get` (root)
- Analyze and test: in the changed package folder `flutter analyze` and `flutter test` (`dart test` for pure Dart). The whole workspace: `melos run analyze` and `melos run test`, once when a piece is done.
- Format: `dart format .`

## Catalog

`capabilities.json` lists what this project has. More packages come from flutter-skeleton (`scripts/new-project.sh` there shows the flags); copy the package folder, add its path to the workspace list and its entry to `capabilities.json`.
''');

  _write(t, 'CHANGELOG.md', '''# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Started from flutter-skeleton: sign in, see who you are, sign out.
''');
}

// ---------------------------------------------------------------------------- entry point

void main(List<String> args) {
  try {
    switch (args.isEmpty ? '' : args.first) {
      case 'plan':
        final all = readPackages(Directory(args[1]));
        final plan = planKeep(all, _csv(args[2]));
        for (final id in plan.keep) {
          stdout.writeln('keep $id');
        }
        for (final id in plan.keep) {
          stdout.writeln('why $id ${plan.why[id]}');
        }
      case 'copy':
        copyTree(Directory(args[1]), Directory(args[2]));
      case 'apply':
        applyStamp(
          Directory(args[1]),
          StampOptions(
            name: args[2],
            org: args[3],
            prefix: args[4] == '-' ? null : args[4],
            keep: _csv(args[5]),
          ),
        );
      default:
        stderr.writeln('usage: stamp.dart plan|copy|apply ...');
        exit(2);
    }
  } on StampError catch (e) {
    stderr.writeln('x ${e.message}');
    exit(args.isNotEmpty && args.first == 'plan' ? 2 : 1);
  }
}

List<String> _csv(String s) => s.isEmpty ? [] : s.split(',');
