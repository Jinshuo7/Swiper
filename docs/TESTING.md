# Testing

This document records the exact commands used to verify Swiper and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

## Pure-logic suite (`SwiperKitTests`)

The `SwiperKit` unit tests run on macOS without `xcodebuild`, using the raw
compiler inside `Xcode.app`. On this machine the global developer directory
points at Command Line Tools, so set `DEVELOPER_DIR`:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

- Result: **66 tests, 0 failures** (exit 0).
- The script honours `$DEVELOPER_DIR` if set, otherwise uses `xcode-select -p`.
- It detects the host architecture with `uname -m` and the installed macOS SDK
  version from `MacOSX.sdk/SDKSettings.plist`; the target triple is built from
  those, so no version is hardcoded.
- `/usr/bin/plutil` (a system tool) is used to read the SDK version.
