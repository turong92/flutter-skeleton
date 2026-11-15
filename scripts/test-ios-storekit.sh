#!/usr/bin/env bash
# The ad removal of apps/sample (one-time purchase and subscription) against StoreKit testing, on the iOS simulator,
# with nobody at the keyboard.
#
#   scripts/test-ios-storekit.sh                 # iPhone 17 simulator
#   SIM_NAME="iPhone Air" scripts/test-ios-storekit.sh
#
# `flutter run` does not take the scheme's StoreKit file. This does: the Dart test (apps/sample/integration_test) runs
# inside the Runner app under `xcodebuild test`, and ios/RunnerTests/RunnerTests.swift makes an SKTestSession from
# ios/Runner/Products.storekit in that same process (dialogs off, so no purchase sheet). The simulator it booted is shut
# down again at the end. Needs Xcode and the simulator runtime; no network, no server (the sample server is a double).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
APP="$SRC/apps/sample"
SIM_NAME="${SIM_NAME:-iPhone 17}"
TARGET="integration_test/ads_removal_storekit_test.dart"
DERIVED="${DERIVED:-$SRC/build/storekit-derived}"

UDID="$(xcrun simctl list devices available | grep -E "^ +$SIM_NAME \(" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
[ -n "$UDID" ] || { echo "no available simulator named '$SIM_NAME'" >&2; exit 2; }

WAS_BOOTED="$(xcrun simctl list devices booted | grep -c "$UDID" || true)"
if [ "$WAS_BOOTED" = 0 ]; then xcrun simctl boot "$UDID"; fi
trap '[ "$WAS_BOOTED" != 0 ] || xcrun simctl shutdown "$UDID" || true' EXIT

cd "$APP"
# writes the Dart entry (the test) and the Pods into ios/ without building the app
flutter build ios --simulator --debug --config-only --target "$TARGET" --dart-define-from-file=env/dev.json.example

cd ios
xcodebuild test \
  -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" \
  -only-testing:RunnerTests -parallel-testing-enabled NO
