# Testing

This document records the exact commands used to verify Swiper and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

There are three test targets:

| Target | What it covers | Where it runs |
| --- | --- | --- |
| `SwiperKitTests` | Pure logic: ordering, marks, undo, persistence and migration, reconciliation, statistics, layout | macOS **or** device |
| `SwiperAppTests` | `AppModel` against `FakePhotoLibrary` and a controllable `InMemorySessionStore`: acknowledgement, failure/retry, restart, recovery, deletion outcomes | Device only |
| `SwiperUITests` | Real UI against the fake library: viewer bounds, drag feedback, tutorial, home/review navigation, screenshots | Device only |

Automated tests never touch a real photo library: unit tests use fakes, and every
UI test launches with `-uiTestingFakeLibrary`.

## Pure-logic suite (macOS, always available)

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

- Latest result (2026-09-21, Xcode 27.0): **111 tests, 0 failures**, exit 0.
- The script honours `$DEVELOPER_DIR` if set, otherwise uses `xcode-select -p`.
- It detects the host architecture with `uname -m` and the installed macOS SDK
  version from `MacOSX.sdk/SDKSettings.plist`, so no version is hardcoded.

## iOS type check (no device needed)

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/typecheck-ios.sh
```

- Latest result: **green**, output `OK`.
- The script sets `-Xfrontend -disable-sandbox` itself. Without it, SwiftUI's
  macros fail with "external macro implementation type … produced malformed
  response" whenever the script runs inside another sandbox.

## Build everything for testing (no device needed)

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TMPDIR=$PWD/.tmp \
xcodebuild build-for-testing -project Swiper.xcodeproj -scheme Swiper \
  -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData \
  -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
```

- Latest result: `** TEST BUILD SUCCEEDED **`. This compiles all three test
  targets, so it is the check that catches a broken `SwiperAppTests` or
  `SwiperUITests` without a device.
- `-derivedDataPath ./.derivedData` is required inside a restricted sandbox: the
  default `~/Library/Developer/Xcode/DerivedData` is not writable.
- `-Xfrontend -disable-sandbox` is required for the same reason (SwiftUI macro
  plugins cannot apply their own nested sandbox).

## Full suite on a connected iPhone

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TMPDIR=$PWD/.tmp \
xcodebuild test -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS,id=00008030-000669DE3408802E' \
  -derivedDataPath ./.derivedData -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
```

- Find the UDID with `xcrun devicectl list devices`.
- The device must be connected, unlocked and in Developer Mode, with its
  developer profile trusted under Settings → General → VPN & Device Management.
  Personal Team profiles expire after 7 days; rebuild to re-trust.
- **Status 2026-09-21: BLOCKED.** The iPhone reported `unavailable` for the whole
  working session, and there is no Simulator runtime on this machine
  (`xcrun simctl list runtimes` is empty; the runtime was removed for disk).
  A `swiper` UI run was attempted while the device still reported `booted`, hung
  for ~35 minutes with no `xcresult` progress, and was killed. Therefore
  `SwiperAppTests` and `SwiperUITests` have **not executed** since the redesign,
  and no design acceptance criterion that depends on them is verified. Do not
  report them as passing.

## Screenshots

UI tests attach screenshots with `lifetime = .keepAlways`. They are written into
the run's `.xcresult` bundle:

```
.derivedData/Logs/Test/Test-Swiper-<timestamp>.xcresult
```

Extract them with:

```sh
xcrun xcresulttool export attachments \
  --path .derivedData/Logs/Test/Test-Swiper-<timestamp>.xcresult \
  --output-path ./screenshots
```

Attachments the suite is written to produce, and what each one is for:

| Attachment | Produced by | Shows |
| --- | --- | --- |
| `Viewer — complete photo, fixture step N` | `testViewerShowsWholePhotosWithoutCroppingOrOffscreenControls` | Portrait, landscape, square and panorama fixture with edge markers, alternating bright/dark |
| `Partial left drag — below threshold` | `testPartialDragsShowFeedbackButDecideNothing` | Trash well below the threshold, photo following the finger |
| `Partial right drag — below threshold` | same | Check well below the threshold |
| `Left drag past threshold` | same | Armed trash well |
| `Vertical drag — no decision` | `testVerticalDragDecidesNothing` | No well, no outcome |
| `Tutorial — first photo, Swipe preset` | `testFirstPhotoTutorialExplainsAndReplaysFromSettings` | Tutorial copy and dismissal |
| `Settings — How to use` | same | Settings entry that replays it |
| `Save failure — Retry offered` | `testAFailedSaveShowsRetryAndDoesNotAdvanceTheSession` | The visible save-failure banner and its Retry action |

Mid-gesture screenshots are taken while the drag is still held
(`press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` on a
background queue), because the outcome wells only exist during the gesture. They
must be inspected by eye: passing assertions alone do not establish that the
photo is uncropped or the controls legible.

Real **Live Photo playback** cannot be covered by the fake library, which returns
no `PHLivePhoto`. It needs a manual check on a device with a real live photo, and
is currently unverified.
