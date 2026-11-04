// Reads the pubspecs of the workspace. Line based on purpose: the tools run with
// nothing but the Dart SDK, and the skeleton's pubspecs are plain.
import 'dart:io';

/// The prefix every skeleton package starts with. `new-project.sh --prefix` swaps it.
const packagePrefix = 'skeleton_';

class PubPackage {
  PubPackage(this.name, this.dir, this.deps);

  /// pubspec `name`, e.g. `skeleton_api_client`.
  final String name;

  /// Folder relative to the repo root, e.g. `packages/api_client`.
  final String dir;

  /// Names of `skeleton_*` packages in dependencies and dev_dependencies.
  final Set<String> deps;

  /// The catalog id: the folder name with hyphens (`api-client`).
  String get id => dir.split('/').last.replaceAll('_', '-');

  bool get isApp => dir.startsWith('apps/');

  /// The id in capabilities.json: apps are `app-<folder>`.
  String get catalogId => isApp ? 'app-$id' : id;
}

String? pubspecName(String pubspec) =>
    RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);

Set<String> skeletonDeps(String pubspec) => {
  for (final m in RegExp(
    '^  ($packagePrefix[a-z0-9_]+):',
    multiLine: true,
  ).allMatches(pubspec))
    m.group(1)!,
};

/// Root tooling nothing depends on but every project needs (the lints included by analysis_options.yaml).
const rootToolIds = {'lints'};

/// Package names the starter app needs: what it declares plus what those need, transitively.
Set<String> closureOf(List<PubPackage> all, Iterable<String> start) {
  final byName = {for (final p in all) p.name: p};
  final seen = <String>{};
  void walk(String name) {
    if (!seen.add(name)) return;
    for (final dep in byName[name]?.deps ?? const <String>{}) {
      walk(dep);
    }
  }

  start.forEach(walk);
  return seen;
}

/// Ids a stamp keeps with no flag: the starter's closure and the root tooling.
Set<String> alwaysIds(List<PubPackage> all) {
  final starter = all.firstWhere((p) => p.dir == 'apps/starter');
  final names = closureOf(all, starter.deps);
  return {
    for (final p in all)
      if (names.contains(p.name) || rootToolIds.contains(p.id)) p.id,
  };
}

/// Every `packages/*` and `apps/*` folder that has a pubspec.
List<PubPackage> readPackages(Directory root) {
  final found = <PubPackage>[];
  for (final group in ['packages', 'apps']) {
    final dir = Directory('${root.path}/$group');
    if (!dir.existsSync()) continue;
    final folders = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final folder in folders) {
      final file = File('${folder.path}/pubspec.yaml');
      if (!file.existsSync()) continue;
      final text = file.readAsStringSync();
      found.add(
        PubPackage(
          pubspecName(text)!,
          '$group/${folder.path.split('/').last}',
          skeletonDeps(text),
        ),
      );
    }
  }
  return found;
}
