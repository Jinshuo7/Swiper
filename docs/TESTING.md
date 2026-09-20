# Testing

This document records the exact commands used to verify Swiper and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

## Full suite (Xcode)

Verified working 2026-09-20: Xcode 27.0, licence accepted. The iOS Simulator
runtime was removed to save disk, so the full suite runs on a connected iPhone.
`xcode-select -p` still points at Command Line Tools, so set `DEVELOPER_DIR`:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS,id=<device UDID>'
```

- Find the UDID with `xcrun devicectl list devices`.
- Result: **66 `SwiperKitTests` + 4 `SwiperUITests`, 0 failures**, `TEST SUCCEEDED`
  (~250 s on an iPhone 11 Pro, iOS 26.2.1).
- The device must be connected, unlocked and in Developer Mode, with its developer
  profile trusted under Settings → General → VPN & Device Management. Personal
  Team profiles expire after 7 days; rebuild to re-trust.
- Device builds sign with the personal team and a unique app bundle id set in
  `Scripts/generate_project.rb`; `com.swiper.app` is globally taken and cannot be
  registered to the team.

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
