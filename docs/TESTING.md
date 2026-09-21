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
- The same suite also passed **on the device** in the full run below.
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
- **Status 2026-09-21 21:09: RUN GREEN.** The full suite ran on the iPhone 11 Pro
  (`00008030-000669DE3408802E`, iOS 26.2.1), `** TEST SUCCEEDED **`:

  | Target | Tests | Result |
  | --- | --- | --- |
  | `SwiperKitTests` | 126 | 0 failures |
  | `SwiperAppTests` | 31 | 0 failures |
  | `SwiperUITests` | 31 | 0 failures |

  188 tests, 0 failures. Result bundle: `.derivedData/final4.xcresult`.
- The interrupted-session case runs on the device too:
  `testKillingTheAppMidSessionRestoresPositionMarksAndUndo` terminates the app
  mid-flow, relaunches it, and checks that Continue sorting, the mark and Undo all
  survive.
- Two environmental preconditions, both previously recorded as blockers:
  * The device must be **unlocked**. A locked phone fails with
    `deviceprep Code=-3 "Unlock iPhone to Continue"`, and if it locks between the
    runner launching and enabling automation the runner reports
    "Timed out while enabling automation mode."
  * It helps to force a full connection first. `xcrun devicectl list devices`
    showing `available (paired)` was followed by automation-mode timeouts;
    `xcrun devicectl device info details --device <udid>` brought it to
    `connected` and the run then worked.
- `SwiperUITests` takes about 3.5 minutes (212 s) because each test relaunches the
  app and several hold a drag for 1.5 s.
- Inside a restricted sandbox, launching a device test host needs a
  pseudo-terminal; without full file access Xcode fails with
  `IDEPseudoTerminalDomain … Errno: 1` (EPERM) before any test runs.

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

The green run's attachments are committed, resized to a 900 px long side, in
[`docs/screenshots/`](screenshots) so a reviewer can see them without running
anything. They were each inspected by eye; what they establish is listed below.

Attachments the suite produces, and what each one is for:

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
| `Viewer — Live Photo labelled` | `testLivePhotosAreLabelledInTheViewer` | The "LIVE" chip in the top strip, with symbol and word |
| `Controls — fixture step 0…3` | `testControlRailDoesNotMoveBetweenPhotos` | The bottom rail in the same place for every aspect ratio |
| `Controls — right side rail` | `testControlRailCanMoveToEitherSideRail` | The rail moved to the right edge, Close at top and Keep at bottom |
| `Controls — left side rail` | same | The rail moved to the left edge, with the photo fitted beside its lane |
| `Settings — statistics row` | `testStatisticsIsReachedFromSettings` | Statistics now inside Settings, reached from a row |
| `Start Here — explanation, months, jump and sort` | `testStartHereExplainsItselfAndGroupsTheLibraryByMonth` | The explanation, month sections with sticky headers, the month menu and the order toggle |
| `Start Here — oldest first` | same | The order toggle actually reversing the month sections |
| `Start Here — jumped to a month` | `testStartHereCanJumpStraightToAMonth` | A month reached by the menu, far beyond one screen of scrolling |
| `Controls — Keep first order` | `testTheRailOrderCanBeFlipped` | The rail order flipped so the decisions sit at the near end |

Mid-gesture screenshots are taken while the drag is still held
(`press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` on a
background queue), because the outcome wells only exist during the gesture. They
must be inspected by eye: passing assertions alone do not establish that the
photo is uncropped or the controls legible.

**Resolved on first execution:** `XCUICoordinate.press(...)` asserts
"Must be called on the main thread", so the original helper (drag on a background
queue, screenshot on the main thread) failed. `holdDrag` is now inverted: the
drag runs on the main thread and the screenshot is taken from a background queue
while the gesture is held. That ran green and produced the drag attachments.

Real **Live Photo playback** cannot be covered by the fake library, which returns
no `PHLivePhoto`. It needs a manual check on a device with a real live photo, and
is currently unverified.
