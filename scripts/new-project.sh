#!/usr/bin/env bash
# Stamp a new project: copy -> keep only the packages needed -> rename the app -> (optional) org and prefix -> rewrite the docs.
#
#   scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]
#
#   e.g. scripts/new-project.sh ~/work/acme acme_app
#        scripts/new-project.sh ~/work/acme acme_app --org com.acme --prefix acme
#
# What it does (the string work is tool/new_project/stamp.dart):
#   1. Copies this repo to <target-dir> (no .git, .dart_tool, build, env/*.json, generated platform files).
#   2. apps/starter -> apps/<name>: pubspec name, Android namespace / applicationId / MainActivity package folder,
#      iOS bundle id, display names. A text that cannot be found stops the script (exit 1), nothing is skipped quietly.
#   3. Packages = what the starter uses + --packages, closed over their pubspec dependencies. The other packages are
#      removed and the workspace list in the root pubspec.yaml is rewritten.
#   4. --prefix acme: skeleton_ -> acme_ in package names and imports.
#   5. capabilities.json becomes mode "project" (what is kept; the rest under "omitted"), docs/capabilities.md and
#      llms.txt are regenerated, README / CLAUDE.md / CHANGELOG are rewritten for the project.
#   6. The new-project tools (this script, its test, tool/, the workflow) do not come along.
#
# Exit codes: 0 done / 1 failed midway (the target is left as it is) / 2 bad arguments (nothing is created).
# Needs only bash (3.2 is fine) and the Dart SDK.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
HELPER="$SRC/tool/new_project/stamp.dart"

usage() {
  cat <<'EOF2'
usage: scripts/new-project.sh <target-dir> <name> [--packages a,b] [--org com.example] [--prefix acme]

  <target-dir>  new folder (refused if it exists or is inside this repo)
  <name>        Dart package name of the app = apps/<name> (lower-case letters, digits, underscores)
  --packages    packages to add to the starter's own (ids such as api-client, comma separated)
  --org         reverse-domain organisation for the Android applicationId and iOS bundle id (default com.example)
  --prefix      replaces skeleton_ in package names (acme -> acme_auth)
EOF2
}

die_usage() { echo "x $*" >&2; echo >&2; usage >&2; exit 2; }

valid_packages() {
  local d
  for d in "$SRC"/packages/*/; do
    [ -f "$d/pubspec.yaml" ] && basename "$d" | tr '_' '-'
  done | sort
}

POSITIONAL=()
PACKAGES_ARG=""
ORG="com.example"
PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --packages) [ $# -ge 2 ] && [ "${2#--}" = "$2" ] || die_usage "--packages needs a value"; PACKAGES_ARG="$2"; shift 2 ;;
    --packages=*) PACKAGES_ARG="${1#--packages=}"; shift ;;
    --org) [ $# -ge 2 ] && [ "${2#--}" = "$2" ] || die_usage "--org needs a value"; ORG="$2"; shift 2 ;;
    --org=*) ORG="${1#--org=}"; shift ;;
    --prefix) [ $# -ge 2 ] && [ "${2#--}" = "$2" ] || die_usage "--prefix needs a value"; PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#--prefix=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) die_usage "unknown option: $1" ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
[ "${#POSITIONAL[@]}" -eq 2 ] || die_usage "expected 2 arguments (<target-dir> <name>), got ${#POSITIONAL[@]}"
TARGET_ARG="${POSITIONAL[0]}"; NAME="${POSITIONAL[1]}"

echo "$NAME" | grep -Eq '^[a-z][a-z0-9_]*$' || die_usage "name must be lower-case letters, digits, underscores: $NAME"
echo "$ORG" | grep -Eq '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$' || die_usage "org must look like com.example: $ORG"
if [ -n "$PREFIX" ]; then
  echo "$PREFIX" | grep -Eq '^[a-z][a-z0-9]*$' || die_usage "prefix must be lower-case letters and digits: $PREFIX"
  [ "$PREFIX" != skeleton ] || die_usage "prefix 'skeleton' is what it already is"
fi

ALL_PACKAGES="$(valid_packages)"
REQUESTED=""
if [ -n "$PACKAGES_ARG" ]; then
  while IFS= read -r p; do
    p="$(echo "$p" | tr -d '[:space:]')"
    [ -n "$p" ] || continue
    if ! grep -Fxq -- "$p" <<<"$ALL_PACKAGES"; then
      echo "x unknown package: $p" >&2
      echo "valid packages: $(echo "$ALL_PACKAGES" | tr '\n' ' ')" >&2
      exit 2
    fi
    REQUESTED="${REQUESTED:+$REQUESTED,}$p"
  done <<EOF2
$(printf '%s' "$PACKAGES_ARG" | tr ',' '\n')
EOF2
fi

case "$TARGET_ARG" in /*) TARGET="$TARGET_ARG" ;; *) TARGET="$PWD/$TARGET_ARG" ;; esac
TARGET="${TARGET%/}"
# resolve ../ and symlinks, or a `../x` called from inside the repo is mistaken for "inside the repo"
normalize_path() {
  local p="$1" d b
  d="$(dirname "$p")"; b="$(basename "$p")"
  if [ -d "$d" ]; then printf '%s/%s' "$(cd "$d" && pwd -P)" "$b"; else printf '%s/%s' "$(normalize_path "$d")" "$b"; fi
}
[ -n "$TARGET" ] || die_usage "target must not be /"
TARGET="$(normalize_path "$TARGET")"
[ ! -e "$TARGET" ] || die_usage "target already exists: $TARGET"
case "$TARGET/" in "$SRC"/*) die_usage "target must be outside the skeleton repo ($SRC): $TARGET" ;; esac
command -v dart >/dev/null || { echo "x the Dart SDK (dart) is required" >&2; exit 1; }

# ---------------------------------------------------------------------------------------------------- plan, copy, transform
PLAN="$(dart "$HELPER" plan "$SRC" "$REQUESTED")" || { echo "$PLAN" >&2; exit 2; }
KEEP="$(printf '%s\n' "$PLAN" | sed -n 's/^keep //p' | tr '\n' ',' | sed 's/,$//')"
echo "== plan"
printf '%s\n' "$PLAN" | sed -n 's/^why /   /p'
echo "   app: apps/$NAME (from apps/starter), id $ORG.$NAME"

echo "== copy -> $TARGET"
dart "$HELPER" copy "$SRC" "$TARGET"
echo "== transform"
dart "$HELPER" apply "$TARGET" "$NAME" "$ORG" "${PREFIX:--}" "$KEEP"

cat <<EOF2

done: $TARGET
next steps:
  cd $TARGET
  git init && flutter pub get           # pubspec.lock is the skeleton's: pub get fits it to the kept packages, commit the result
  melos run analyze && melos run test   # dart pub global activate melos
  flutter run --dart-define-from-file=env/dev.json   # in apps/$NAME; copy env/dev.json.example first
Change the Android applicationId / iOS bundle id ($ORG.$NAME) before the first store upload.
EOF2
