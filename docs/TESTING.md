# Testing

This document records the exact commands used to verify Swiper and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

## Full suite (Xcode)

Verified working 2026-09-20: Xcode 27.0, iOS 26.5 Simulator runtime, licence
accepted. `xcode-select -p` still points at Command Line Tools, so set
`DEVELOPER_DIR`:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- Result: **66 `SwiperKitTests` + 4 `SwiperUITests`, 0 failures**, `TEST SUCCEEDED`
  (about 75 s on the iPhone 17 Pro Simulator).
- A physical iPhone is *not* required; `devicectl`/`xctrace` list only Simulators
  unless a device is connected, trusted and in Developer Mode.

## Pure-logic suite (`SwiperKitTests`, fallback)

The `SwiperKit` unit tests also run on macOS without `xcodebuild`, using the raw
compiler inside `Xcode.app`. Set `DEVELOPER_DIR` for the same reason:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

- Result: **66 tests, 0 failures** (exit 0).
- The script honours `$DEVELOPER_DIR` if set, otherwise uses `xcode-select -p`.
- It detects the host architecture with `uname -m` and the installed macOS SDK
  version from `MacOSX.sdk/SDKSettings.plist`; the target triple is built from
  those, so no version is hardcoded.
- `/usr/bin/plutil` (a system tool) is used to read the SDK version.

## iOS typecheck

Compile-checks `SwiperKit` and the whole `Swiper` app against the iOS Simulator
SDK without `xcodebuild`. Same `DEVELOPER_DIR` shape as above:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/typecheck-ios.sh
```

- Result on this machine: green, exit 0. Output:

  ```
  ==> Building SwiperKit for iOS (arm64-apple-ios27.0-simulator)
  ==> Type-checking the Swiper app
  OK
  ```

- The script honours `$DEVELOPER_DIR` (else `xcode-select -p`) and derives the
  target triple from `uname -m` and the installed SDK version, so no SDK
  version is hardcoded.
