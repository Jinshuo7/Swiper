#!/usr/bin/env bash
# Capture the Round 4 Home screenshots on `SWIPR iPhone 11 Pro`.
#
# Requires the app to be built for the simulator first:
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
#   xcodebuild build -project SWIPR.xcodeproj -scheme SWIPR \
#     -destination 'platform=iOS Simulator,id=71EAC83D-54D4-451A-AB32-74A8878C7869' \
#     -derivedDataPath ./.derivedData \
#     OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
#
# Then run this script from anywhere. It installs the build, seeds the store,
# captures light and dark Home, and rebuilds home-compare.png.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

UDID="${UDID:-71EAC83D-54D4-451A-AB32-74A8878C7869}"
BUNDLE="com.zhangjinshuo.swipr"
APP="$REPO/.derivedData/Build/Products/Debug-iphonesimulator/SWIPR.app"

xcrun simctl install "$UDID" "$APP"
python3 "$HERE/seed_state.py" --udid "$UDID"

capture() {
  local argument="$1" output="$2"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE" "$argument" >/dev/null
  sleep 7
  xcrun simctl io "$UDID" screenshot "$output" >/dev/null 2>&1
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  echo "captured $output"
}

capture -uiTestingForceLight "$HERE/current-home-light.png"
capture -uiTestingForceDark "$HERE/current-home-dark.png"
python3 "$HERE/make_compare.py"
