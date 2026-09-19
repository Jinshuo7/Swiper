#!/usr/bin/env bash
#
# Compile-checks the whole iOS app and the SwiperKit framework against the iOS
# Simulator SDK without xcodebuild.
#
# Useful when `xcodebuild` cannot run (for example the installed Xcode license
# has not been accepted for the current user, which the raw compiler inside
# Xcode.app does not require). This does not produce a runnable .app; use
# Xcode for that. See README.md.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
SWIFTC="$XCODE_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
IOSSDK="$XCODE_DIR/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
ARCH="$(uname -m)"
SDK_VERSION="$(plutil -extract Version raw "$IOSSDK/SDKSettings.plist")"
TARGET="${TARGET:-$ARCH-apple-ios$SDK_VERSION-simulator}"
BUILD="$ROOT/.build-ios-typecheck"

if [[ ! -x "$SWIFTC" ]]; then
  echo "swiftc not found at $SWIFTC" >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Building SwiperKit for iOS ($TARGET)"
"$SWIFTC" -sdk "$IOSSDK" -target "$TARGET" -parse-as-library -enable-testing \
  -module-name SwiperKit -emit-module \
  -emit-module-path "$BUILD/SwiperKit.swiftmodule" \
  $(find "$ROOT/SwiperKit" -name '*.swift' | sort)

echo "==> Type-checking the Swiper app"
"$SWIFTC" -sdk "$IOSSDK" -target "$TARGET" -parse-as-library -typecheck \
  -I "$BUILD" \
  $(find "$ROOT/Swiper" -name '*.swift' | sort)

echo "OK"
