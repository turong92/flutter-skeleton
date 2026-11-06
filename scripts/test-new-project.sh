#!/usr/bin/env bash
# Test of scripts/new-project.sh: bad arguments, then three real stamps that must resolve, analyze and test.
#
#   scripts/test-new-project.sh
#
#   1. bad arguments are refused with exit 2 and create nothing
#   2. default stamp (acme_app, com.example): renames, no leftovers, pub get + analyze + test of the whole workspace
#   3. --packages auth --org com.shop --prefix shop (shop_app): the same, with the prefix and org applied
#   4. --packages board,storage,push,notifications,realtime,iap,i18n: all stay with their starter screens, apps/sample is gone, the same checks
#
# Needs the Flutter SDK and network for `flutter pub get` (a few minutes). The temp folder goes away at the end (KEEP=1 keeps it).
# Texts that cannot be found stopping the stamp is tested in tool/test/stamp_test.dart.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="$SRC/scripts/new-project.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/new-project-test.XXXXXX")"
trap '[ "${KEEP:-0}" = 1 ] || rm -rf "$TMP"' EXIT

FAILURES=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILURES=$((FAILURES + 1)); }
check() { # check "<what>" <command...> passes when the command succeeds
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi
}
LAST_OUTPUT=""
expect_exit() { # expect_exit <code> "<what>" <command...>
  local want="$1" what="$2"; shift 2
  local got=0
  LAST_OUTPUT="$("$@" 2>&1)" || got=$?
  if [ "$got" = "$want" ]; then pass "$what (exit $got)"; else fail "$what: exit $got, expected $want: $(echo "$LAST_OUTPUT" | head -3)"; fi
}
leftovers() { # leftovers <dir> <pattern>: files that still contain the pattern (generated and lock files are ignored)
  grep -rIl --exclude-dir=.dart_tool --exclude-dir=build --exclude=pubspec.lock -e "$2" "$1" || true
}

echo "== 1. arguments"
expect_exit 2 "no arguments" bash "$SCRIPT"
expect_exit 2 "an unknown package" bash "$SCRIPT" "$TMP/x1" acme_app --packages no-such-package
echo "$LAST_OUTPUT" | grep -q "api-client" && pass "the error lists the valid packages" || fail "no package list: $LAST_OUTPUT"
mkdir "$TMP/exists"
expect_exit 2 "a target that exists" bash "$SCRIPT" "$TMP/exists" acme_app
expect_exit 2 "a name with a hyphen" bash "$SCRIPT" "$TMP/x2" acme-app
expect_exit 2 "an org that is not reverse-domain" bash "$SCRIPT" "$TMP/x3" acme_app --org acme
expect_exit 2 "the prefix skeleton" bash "$SCRIPT" "$TMP/x4" acme_app --prefix skeleton
expect_exit 2 "a prefix that makes a name an existing dependency has (flutter_lints)" bash "$SCRIPT" "$TMP/x4b" acme_app --prefix flutter
expect_exit 2 "an app name containing skeleton_" bash "$SCRIPT" "$TMP/x4c" my_skeleton_app
expect_exit 2 "an unknown option" bash "$SCRIPT" "$TMP/x5" acme_app --nope
expect_exit 2 "a target inside the repo" bash "$SCRIPT" "$SRC/stamped-inside" acme_app
[ ! -e "$SRC/stamped-inside" ] && pass "nothing is created inside the repo" || { fail "created inside the repo"; rm -rf "$SRC/stamped-inside"; }
[ ! -e "$TMP/x1" ] && pass "a refused call creates nothing" || fail "$TMP/x1 exists"

# workspace-wide pub get + analyze + test of a stamped project
verify() { # verify <dir>
  local dir="$1"
  ( cd "$dir" && flutter pub get ) >"$TMP/log" 2>&1 && pass "flutter pub get" || { fail "flutter pub get: $(tail -5 "$TMP/log")"; return; }
  ( cd "$dir" && dart run melos run analyze ) >"$TMP/log" 2>&1 && pass "analyze (every package)" || fail "analyze: $(tail -15 "$TMP/log")"
  ( cd "$dir" && dart run melos run test ) >"$TMP/log" 2>&1 && pass "test (every package)" || fail "test: $(tail -15 "$TMP/log")"
}

echo "== 2. default stamp"
P1="$TMP/acme"
expect_exit 0 "stamp acme_app" bash "$SCRIPT" "$P1" acme_app
check "the app is apps/acme_app and apps/starter is gone" test -d "$P1/apps/acme_app" -a ! -e "$P1/apps/starter"
check "the new-project tools did not come along" test ! -e "$P1/tool" -a ! -e "$P1/scripts" -a ! -e "$P1/.github/workflows/new-project.yml"
check "the Android package folder moved" test -f "$P1/apps/acme_app/android/app/src/main/kotlin/com/example/acme_app/MainActivity.kt" -a ! -e "$P1/apps/acme_app/android/app/src/main/kotlin/com/example/starter"
check "applicationId is com.example.acme_app" grep -q 'applicationId = "com.example.acme_app"' "$P1/apps/acme_app/android/app/build.gradle.kts"
check "the iOS bundle id is camelCase (no underscore)" grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.example.acmeApp;' "$P1/apps/acme_app/ios/Runner.xcodeproj/project.pbxproj"
check "the workspace lists the app and not tool" bash -c "grep -q '  - apps/acme_app' '$P1/pubspec.yaml' && ! grep -q '  - tool' '$P1/pubspec.yaml'"
check "no env/*.json, no .git, no generated platform files came along" bash -c "[ ! -e '$P1/.git' ] && [ ! -e '$P1/apps/acme_app/env/dev.json' ] && [ ! -e '$P1/apps/acme_app/ios/Flutter/Generated.xcconfig' ]"
[ -z "$(leftovers "$P1" 'com.example.starter\|package:starter/')" ] && pass "no starter id left" || fail "starter left in: $(leftovers "$P1" 'com.example.starter\|package:starter/')"
check "AGENTS.md is written for the project and CLAUDE.md only imports it" bash -c "head -1 '$P1/AGENTS.md' | grep -q 'acme_app' && grep -qx '@AGENTS.md' '$P1/CLAUDE.md'"
check "the catalog is a project catalog" grep -q '"mode": "project"' "$P1/capabilities.json"
check "apps/sample, board and push are not in a default stamp" test ! -e "$P1/apps/sample" -a ! -e "$P1/packages/board" -a ! -e "$P1/packages/push"
check "a default stamp has none of the optional screens and no marker line" bash -c "[ ! -e '$P1/apps/acme_app/lib/screens/board_screens.dart' ] && [ ! -e '$P1/apps/acme_app/lib/firebase_setup.dart' ] && [ ! -e '$P1/apps/acme_app/lib/screens/store_screen.dart' ] && ! grep -rIq -e '#if ' -e '#endif' -e '#file ' --include='*.dart' --include='*.yaml' --include='*.plist' --include='*.xml' '$P1/apps'"
check "a default stamp has both languages, only the texts of what it has, and no language menu" bash -c "D='$P1/apps/acme_app' && [ -f \$D/lib/l10n/app_ko.arb ] && [ -f \$D/lib/l10n/app_en.arb ] && grep -q createAccount \$D/lib/l10n/app_en.arb && ! grep -q boardTitle \$D/lib/l10n/app_en.arb && ! grep -q x-feature \$D/lib/l10n/app_ko.arb && ! grep -rq LanguageMenu \$D/lib"
check "a default stamp has the format dart format wants" bash -c "cd '$P1' && ! dart format --output=none --set-exit-if-changed apps 2>/dev/null | grep -q Changed"
verify "$P1"

echo "== 3. --packages auth --org com.shop --prefix shop"
P2="$TMP/shop"
expect_exit 0 "stamp shop_app" bash "$SCRIPT" "$P2" shop_app --packages auth --org com.shop --prefix shop
check "the package is shop_auth, the folder stays packages/auth" grep -q '^name: shop_auth' "$P2/packages/auth/pubspec.yaml"
check "applicationId is com.shop.shop_app" grep -q 'applicationId = "com.shop.shop_app"' "$P2/apps/shop_app/android/app/build.gradle.kts"
check "imports use the prefix" grep -q "package:shop_auth/shop_auth.dart" "$P2/apps/shop_app/lib/main.dart"
[ -z "$(leftovers "$P2" 'skeleton_')" ] && pass "no skeleton_ left" || fail "skeleton_ left in: $(leftovers "$P2" 'skeleton_')"
verify "$P2"

echo "== 4. --packages board,storage,push,notifications,realtime,iap,i18n"
P3="$TMP/shop2"
expect_exit 0 "stamp shop_app with board, storage, push, notifications, realtime, iap and i18n" bash "$SCRIPT" "$P3" shop_app --packages board,storage,push,notifications,realtime,iap,i18n
check "the starter has the screens, routes and wiring of what was picked" bash -c "D='$P3/apps/shop_app/lib' && [ -f \$D/screens/board_screens.dart ] && [ -f \$D/screens/notifications_screen.dart ] && [ -f \$D/screens/notification_settings_screen.dart ] && [ -f \$D/screens/store_screen.dart ] && [ -f \$D/firebase_setup.dart ] && [ -f \$D/inbox_realtime.dart ] && grep -q \"path: '/board'\" \$D/router.dart && grep -q 'ImageUploadField' \$D/screens/board_screens.dart && grep -q 'iapApiProvider' \$D/wiring.dart"
check "the picked starter has the Korean and English texts, the language menu and the saved language" bash -c "D='$P3/apps/shop_app' && [ -f \$D/lib/l10n/app_ko.arb ] && [ -f \$D/lib/l10n/app_en.arb ] && grep -q LanguageMenu \$D/lib/screens/me_screen.dart && grep -q loadSavedLocale \$D/lib/main.dart && grep -q boardTitle \$D/lib/l10n/app_en.arb && ! grep -q x-feature \$D/lib/l10n/app_en.arb"
check "the picked starter has the format dart format wants and no marker line" bash -c "cd '$P3' && ! dart format --output=none --set-exit-if-changed apps 2>/dev/null | grep -q Changed && ! grep -rIq -e '#if ' -e '#endif' -e '#file ' --include='*.dart' --include='*.yaml' --include='*.plist' --include='*.xml' apps"
check "the four are kept, apps/sample is gone" test -d "$P3/packages/board" -a -d "$P3/packages/push" -a -d "$P3/packages/notifications" -a -d "$P3/packages/realtime" -a ! -e "$P3/apps/sample"
check "the workspace lists the four and not the sample" bash -c "grep -q '  - packages/board' '$P3/pubspec.yaml' && grep -q '  - packages/push' '$P3/pubspec.yaml' && grep -q '  - packages/notifications' '$P3/pubspec.yaml' && grep -q '  - packages/realtime' '$P3/pubspec.yaml' && ! grep -q 'apps/sample' '$P3/pubspec.yaml'"
check "the CI file builds only the app" bash -c "! grep -q 'apps/sample' '$P3/.github/workflows/ci.yml'"
verify "$P3"

echo
if [ "$FAILURES" -eq 0 ]; then echo "all passed"; else echo "$FAILURES failed"; exit 1; fi
