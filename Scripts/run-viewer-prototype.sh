#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
device_id="${1:-00008030-000669DE3408802E}"
echo 'Keep the connected iPhone unlocked. Building the sample-only prototype…'
xcodebuild -quiet -project SWIPR.xcodeproj -scheme SWIPR -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath .derivedData-prototype build
xcrun devicectl device install app --device "$device_id" \
  .derivedData-prototype/Build/Products/Debug-iphoneos/SWIPR.app
xcrun devicectl device process launch --device "$device_id" --terminate-existing \
  com.zhangjinshuo.swipr -viewerDockPrototype
