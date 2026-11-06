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

Set<String> skeletonDeps(String pubspec, [String prefix = packagePrefix]) => {
  for (final m in RegExp(
    '^  (${RegExp.escape(prefix)}[a-z0-9_]+):',
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
List<PubPackage> readPackages(Directory root, [String prefix = packagePrefix]) {
  final found = <PubPackage>[];
  for (final group in ['packages', 'apps']) {
    final dir = Directory('${root.path}/$group');
    if (!dir.existsSync()) continue;
    final folders = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final folder in folders) {
      final file = File('${folder.path}/pubspec.yaml');
      if (!file.existsSync()) continue;
      // the starter's optional blocks are not what it needs: those are picked per project
      final text = applyFeatureBlocks(
        file.readAsStringSync(),
        null,
        '${folder.path}/pubspec.yaml',
      );
      found.add(
        PubPackage(
          pubspecName(text)!,
          '$group/${folder.path.split('/').last}',
          skeletonDeps(text, prefix),
        ),
      );
    }
  }
  return found;
}

// ---------------------------------------------------------------------------- starter features
//
// The starter carries the screens of the optional packages (board, ...). What belongs to a
// package sits between two marker lines in any text file of the app, behind its comment mark:
//
//     // #if board storage      (`a|b` = either; yaml: `# #if board`, xml: `<!-- #if storage -->`)
//     ...
//     // #endif
//
// A block stays when every id after `#if` is kept; otherwise it goes. A file whose first
// lines hold `// #file board` is the package's file and is deleted with it. The ids are
// catalog ids (`board`, `social-login-google`). In the skeleton the starter has all of it;
// a stamp keeps only what was picked.

class FeatureMarkerError implements Exception {
  FeatureMarkerError(this.message);
  final String message;
  @override
  String toString() => message;
}

final _ifMarker = RegExp(
  r'^\s*(?://|#|<!--)\s*#if\s+([a-z0-9\-| ]+?)\s*(?:-->)?\s*$',
);
final _endMarker = RegExp(r'^\s*(?://|#|<!--)\s*#endif\s*(?:-->)?\s*$');

/// Anything that looks like a marker, strict or not. A line that looks like one and is not a
/// well-formed one (`// #if Board`, `# #if social_login`) stops the stamp instead of being kept.
final looseMarker = RegExp(r'^\s*(?://|#|<!--)\s*#(?:if|endif|file)\b');

final _fileMarker = RegExp(
  r'^\s*(?://|#|<!--)\s*#file\s+([a-z0-9\-| ]+?)\s*(?:-->)?\s*$',
);

/// Whether a marker's ids hold for [kept]: every id must be kept; `a|b` is kept when either is.
/// (No "not kept": in the skeleton the markers are comments and all the code is there, so a
/// block that excludes another could not compile next to it.)
bool featureOn(Iterable<String> ids, Set<String> kept) =>
    ids.every((id) => id.split('|').any(kept.contains));

/// The ids a text names in its markers (`#if` and `#file`).
Set<String> featureIdsIn(String text) {
  final ids = <String>{};
  for (final line in text.split('\n')) {
    final m = _ifMarker.firstMatch(line) ?? _fileMarker.firstMatch(line);
    if (m != null) {
      ids.addAll(
        m
            .group(1)!
            .split(' ')
            .where((s) => s.isNotEmpty)
            .expand((s) => s.split('|')),
      );
    }
  }
  return ids;
}

/// The ids of a `#file` marker in the first lines of [text], or null.
List<String>? fileFeatures(String text) {
  for (final line in text.split('\n').take(3)) {
    final m = _fileMarker.firstMatch(line);
    if (m != null) {
      return m.group(1)!.split(' ').where((s) => s.isNotEmpty).toList();
    }
  }
  return null;
}

/// [text] with the blocks of ids that are not all in [kept] removed and the marker lines
/// of the others removed. [kept] null drops every block (what the starter needs without
/// any optional package). Stops on a marker that is open, closed twice or nested.
String applyFeatureBlocks(String text, Set<String>? kept, String where) {
  final out = <String>[];
  List<String>? open;
  var drop = false;
  var n = 0;
  for (final line in text.split('\n')) {
    n++;
    if (_fileMarker.hasMatch(line)) {
      if (n > 3) {
        throw FeatureMarkerError(
          '$where:$n: #file must be in the first 3 lines',
        );
      }
      continue; // handled by the caller (the file stays or is deleted as a whole)
    }
    if (looseMarker.hasMatch(line) &&
        !_ifMarker.hasMatch(line) &&
        !_endMarker.hasMatch(line)) {
      throw FeatureMarkerError(
        '$where:$n: "${line.trim()}" looks like a marker but is not one '
        '(ids are lower-case catalog ids such as `social-login`, separated by spaces)',
      );
    }
    final start = _ifMarker.firstMatch(line);
    if (start != null) {
      if (open != null) {
        throw FeatureMarkerError('$where:$n: #if inside #if');
      }
      open = start.group(1)!.split(' ').where((s) => s.isNotEmpty).toList();
      drop = kept == null || !featureOn(open, kept);
      continue;
    }
    if (_endMarker.hasMatch(line)) {
      if (open == null) {
        throw FeatureMarkerError('$where:$n: #endif without #if');
      }
      open = null;
      drop = false;
      continue;
    }
    if (!drop) out.add(line);
  }
  if (open != null) {
    throw FeatureMarkerError('$where: #if ${open.join(' ')} is never closed');
  }
  return out.join('\n');
}
