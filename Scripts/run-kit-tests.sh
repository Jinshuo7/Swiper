#!/usr/bin/env bash
#
# Runs the SwiperKit unit tests on macOS without xcodebuild.
#
# Why this exists: on machines where the global developer directory still points
# at Command Line Tools and/or the Xcode license has not been accepted for the
# installed Xcode, `xcodebuild` and `xcrun` refuse to run. The raw compiler
# inside Xcode.app does not, so this script invokes it directly to build and run
# the pure-logic test bundle. It is a convenience fallback, not a replacement
# for `xcodebuild test` (see README.md).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
SWIFTC="$XCODE_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
MACSDK="$XCODE_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
XCTEST_FW="$XCODE_DIR/Platforms/MacOSX.platform/Developer/Library/Frameworks"
XCTEST_LIB="$XCODE_DIR/Platforms/MacOSX.platform/Developer/usr/lib"
XCTEST_RUN="$XCODE_DIR/usr/bin/xctest"
ARCH="$(uname -m)"
SDK_VERSION="$(plutil -extract Version raw "$MACSDK/SDKSettings.plist")"
TARGET="${TARGET:-$ARCH-apple-macosx$SDK_VERSION}"
BUILD="$ROOT/.build-kit-tests"

if [[ ! -x "$SWIFTC" ]]; then
  echo "swiftc not found at $SWIFTC" >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Building SwiperKit (macOS)"
"$SWIFTC" -sdk "$MACSDK" -target "$TARGET" -parse-as-library -enable-testing \
  -module-name SwiperKit \
  -emit-module -emit-library \
  -emit-module-path "$BUILD/SwiperKit.swiftmodule" \
  -o "$BUILD/libSwiperKit.dylib" \
  $(find "$ROOT/SwiperKit" -name '*.swift' | sort)

BUNDLE="$BUILD/SwiperKitTests.xctest"
mkdir -p "$BUNDLE/Contents/MacOS"
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SwiperKitTests</string>
<key>CFBundleIdentifier</key><string>com.swiper.kittests</string>
<key>CFBundleName</key><string>SwiperKitTests</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
</dict></plist>
PLIST

echo "==> Building SwiperKitTests (macOS)"
"$SWIFTC" -sdk "$MACSDK" -target "$TARGET" -parse-as-library \
  -I "$BUILD" -L "$BUILD" -lSwiperKit \
  -I "$XCTEST_LIB" -L "$XCTEST_LIB" -F "$XCTEST_FW" \
  -framework XCTest -lXCTestSwiftSupport \
  -Xlinker -rpath -Xlinker "$BUILD" \
  -emit-library -o "$BUNDLE/Contents/MacOS/SwiperKitTests" \
  $(find "$ROOT/SwiperKitTests" -name '*.swift' | sort)

echo "==> Running tests"
"$XCTEST_RUN" "$BUNDLE"
