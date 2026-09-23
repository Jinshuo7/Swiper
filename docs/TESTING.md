# Testing

This document records the exact commands used to verify SWIPR and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

There are three test targets:

| Target | What it covers | Where it runs |
| --- | --- | --- |
| `SWIPRKitTests` | Pure logic: ordering, marks, undo, persistence and migration, reconciliation, statistics, layout | macOS **or** device |
| `SWIPRAppTests` | `AppModel` against `FakePhotoLibrary` and a controllable `InMemorySessionStore`: acknowledgement, failure/retry, restart, recovery, deletion outcomes | Device only |
| `SWIPRUITests` | Real UI against the fake library: viewer bounds, drag feedback, tutorial, home/review navigation, screenshots — plus the exploratory `PlaySessionUITests` "play like a user" suite | Device only |

Automated tests never touch a real photo library: unit tests use fakes, and every
UI test launches with `-uiTestingFakeLibrary`.

## Pure-logic suite (macOS, always available)

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

- Latest result (2026-09-23, Xcode 27.0): **130 tests, 0 failures**, exit 0.
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
xcodebuild build-for-testing -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData \
  -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
```

- Latest result: `** TEST BUILD SUCCEEDED **`. This compiles all three test
  targets, so it is the check that catches a broken `SWIPRAppTests` or
  `SWIPRUITests` without a device.
- `-derivedDataPath ./.derivedData` is required inside a restricted sandbox: the
  default `~/Library/Developer/Xcode/DerivedData` is not writable.
- `-Xfrontend -disable-sandbox` is required for the same reason (SwiftUI macro
  plugins cannot apply their own nested sandbox).

## Full suite on a connected iPhone

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TMPDIR=$PWD/.tmp \
xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS,id=00008030-000669DE3408802E' \
  -derivedDataPath ./.derivedData -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
```

- Find the UDID with `xcrun devicectl list devices`.
- The device must be connected, unlocked and in Developer Mode, with its
  developer profile trusted under Settings → General → VPN & Device Management.
  Personal Team profiles expire after 7 days; rebuild to re-trust.
- **Status 2026-09-23: RUN GREEN**, after the rename and the removal of
  favouriting, on the iPhone 11 Pro (`00008030-000669DE3408802E`, iOS 26.2.1),
  `** TEST SUCCEEDED **`:

  | Target | Tests | Result |
  | --- | --- | --- |
  | `SWIPRKitTests` | 130 | 0 failures |
  | `SWIPRAppTests` | 31 | 0 failures |
  | `SWIPRUITests` | 50 | 0 failures |

  211 tests, 0 failures. `SWIPRUITests` is 34 cases plus the 16
  `PlaySessionUITests` cases described below; the control redesign replaced the
  rail-order case and added five cluster cases, and removing favouriting took the
  heart case with it. The framework, app and UI suites all ran on the same build.
- Previously, 2026-09-21 21:09: **188 tests, 0 failures** (126 + 31 + 31), result
  bundle `.derivedData/final4.xcresult`.
- The interrupted-session case runs on the device too:
  `testKillingTheAppMidSessionRestoresPositionMarksAndUndo` terminates the app
  mid-flow, relaunches it, and checks that Resume, the mark and Undo all
  survive.
- Two environmental preconditions, both previously recorded as blockers:
  * The device must be **unlocked**. A locked phone fails with
    `deviceprep Code=-3 "Unlock iPhone to Continue"`, and if it locks between the
    runner launching and enabling automation the runner reports
    "Timed out while enabling automation mode." Nothing in `xcrun devicectl`
    reports the lock state, and a run that meets a locked phone **waits in
    silence** instead of failing, so ask the owner to unlock the phone before
    starting a device run, and kill the run and ask again the moment
    `Unlock iPhone to Continue` appears rather than letting it sit.
  * It helps to force a full connection first. `xcrun devicectl list devices`
    showing `available (paired)` was followed by automation-mode timeouts;
    `xcrun devicectl device info details --device <udid>` brought it to
    `connected` and the run then worked.
- The original `SWIPRUITests` cases take about 6 minutes because each test
  relaunches the app and several hold a drag for 1.5 s; the play suite below adds
  about 10 minutes.
- Inside a restricted sandbox the run fails before any test starts:
  launching a device test host needs a pseudo-terminal, so without full file
  access Xcode reports
  `IDEPseudoTerminalDomain … ErrorCode: 7 Errno: 1` (EPERM). Full file access is
  the only thing that unblocks it.

## Playing the app like a user (device)

`SWIPRUITests/PlaySessionUITests.swift` walks the app the way a curious person
would, entirely against the fake library: every preset, every cluster dock
(bottom, left and right, including sliding the cluster along an edge), marking,
review (including select mode and restoring several marks at once), deletion, the
empty library, Tumbler played to the end, preferences across a relaunch, the
persistence banners, and every screen at the largest accessibility text size. It
asserts the invariants that must hold in all of those states — controls on screen,
tappable, and never covering each other or the top strip — and attaches a
screenshot of each arrangement.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TMPDIR=$PWD/.tmp \
xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS,id=00008030-000669DE3408802E' \
  -derivedDataPath ./.derivedData -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
  -only-testing:SWIPRUITests/PlaySessionUITests
```

- Latest result (2026-09-23): **16 tests, 0 failures**, about 7 minutes. The
  largest-text walk needs ~1.5 minutes of that.
- `testPlayEveryScreenAtTheLargestAccessibilityTextSize` launches the app with
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
  That argument **does** take effect on the device — the attached screenshot is
  genuinely the app at AX5, not a normal-size run. Screenshots matter here:
  assertions cannot see truncated text, because the accessibility label stays
  whole while the glyphs are cut.
- What playing found, and what changed:
  * A side rail anchored at its start sat *over* the top strip, and the rail is
    drawn last: with the rail on the right, tapping "Review · 1" pressed Close.
    The top strip now steps around the rail's lane, so both stay tappable.
  * Start Here promised "walks toward older photos" whatever direction the user
    had chosen, and Settings described the direction choice as applying to the
    next session when Recent deliberately ignores it. Both now say what actually
    happens (`docs/SPEC.md` §2 and §4).
  * At AX5 the home footer was compressed into unreadable truncation and the
    tutorial's "Got it" sat ~1700 pt below the screen. The home screen and the
    tutorial now scroll at accessibility sizes, the result card scrolls, and
    button labels wrap instead of being cut.
  * Panorama thumbnails drew across their neighbours' columns on Start Here and
    in deletion review, because `scaledToFill` in a fixed-height cell asks for
    four times the column width. Both cells now own their size and the thumbnail
    is an overlay on it.


### The control redesign (2026-09-23, third round)

The viewer's controls were replaced again, following `docs/adr/0006`–`0009`:

- Close is fixed in the top left, drawn at 34 pt inside a 44 pt tap region. The
  Review entry shares the top strip, and the LIVE chip is centred between them.
- The cluster of three (Trash, Undo, Checkmark) now sits at exactly **three fixed
  positions** — a bottom row centred 20 pt above the bottom safe edge, and
  columns centred at 75% of the safe-area height 20 pt inside the left and right
  edges — stored as a three-way `ControlPosition`. The continuous position, the
  rail and the anchor migration are gone.
- It is moved by dragging a **three-dot grip** in the tray's leading end, in a
  44 x 44 pt hit region. The grip lifts a translucent **puck** that follows the
  finger one-to-one while the cluster stays put; the three positions appear as
  phantom **slots** with the nearest highlighted; a release over a slot lands
  there and a release over none changes nothing. Haptics fire on pickup, on slot
  change and on landing.
- The photo never resizes or shifts for the controls (`ADR-0006`): the lane
  reservation is deleted and the fitted frame is asserted identical at all three
  positions. Controls are drawn as translucent material over the photo.
- Swipe gestures are always available and the buttons are an optional display
  (`ADR-0009`): `Show buttons` hides the cluster and its grip, and the preset
  list and `Tap to keep` are gone.
- The three positions are reachable from Settings, from the drag, and from the
  cluster's accessibility action, and survive a relaunch.

Two things about the move gesture are easy to get wrong again:

- The grip is its **own view**, not the tray behind the buttons, and it carries a
  plain `DragGesture(minimumDistance: 0)`. Attaching a gesture to a container
  that holds `Button`s was never recognised; attaching it to the tray worked but
  made the whole tray the handle, which is the design this replaces.
- The drag is held in a **`@GestureState`**, which resets when a gesture ends *or
  is cancelled*, so an interrupted drag can never leave a puck stranded.
- The accessibility frame of the cluster is the union of its children, so both
  `dragGrip` helpers assert that frame is smaller than the screen before
  dragging.

`SWIPRUITests` covers this with `testTheGripMovesTheClusterToEachFixedPosition`,
`testAReleaseAwayFromEverySlotChangesNothing`,
`testAPlainSwipeNeverMovesTheCluster`,
`testThePhotoFrameIsIdenticalAtEveryControlPosition`,
`testTheClusterKeepsItsPlaceBetweenPhotos`, `testCloseIsSmallInTheTopLeftCorner`
and `testShowButtonsToggleHidesAndRestoresTheCluster`. The play suite adds
`testPlayEveryControlPosition`, which walks all three positions and checks at
reach that every control stays on screen, tappable, and clear of the top strip.

`SWIPRKitTests.ControlPreferencesTests` and `ControlClusterLayoutTests` cover the
storage and geometry: an old three-way rail becomes the matching fixed stop, an
unknown rail is still rejected, and the three centres, sizes, grip and slot hit
testing match the spec. `SWIPRKitTests.SessionPersistenceTests` covers the
version 3 state, including a version 2 session with a favourite undo entry.

## Screenshots

UI tests attach screenshots with `lifetime = .keepAlways`. They are written into
the run's `.xcresult` bundle:

```
.derivedData/Logs/Test/Test-SWIPR-<timestamp>.xcresult
```

Extract them with:

```sh
xcrun xcresulttool export attachments \
  --path .derivedData/Logs/Test/Test-SWIPR-<timestamp>.xcresult \
  --output-path ./screenshots
```

The green run's attachments are committed, resized to a 900 px long side, in
[`docs/screenshots/`](screenshots) so a reviewer can see them without running
anything. They were each inspected by eye; what they establish is listed below.

Attachments the suite produces, and what each one is for:

| Attachment | Produced by | Shows |
| --- | --- | --- |
| `Viewer — complete photo, fixture step N` | `testViewerShowsWholePhotosWithoutCroppingOrOffscreenControls` | Landscape, portrait, square and panorama fixtures with edge markers (`viewer-01`–`04`) |
| `Partial left drag — below threshold` / `Left drag past threshold` / `Partial right drag — below threshold` / `Vertical drag — no decision` | `testPartialDragsShowFeedbackButDecideNothing`, `testVerticalDragDecidesNothing` | The wells below and past the threshold, and no outcome on a vertical drag (`drag-01`–`04`) |
| `Viewer — Live Photo labelled` | `testLivePhotosAreLabelledInTheViewer` | The "LIVE" chip in the top strip (`viewer-05`) |
| `Tutorial — first photo` | `testFirstPhotoTutorialExplainsAndReplaysFromSettings` | The tutorial copy, including moving the buttons (`tutorial-first-photo`) |
| `Settings — How to use` / `Settings — inline statistics` | same, `testStatisticsIsInlineAtTheTopOfSettings` | The replay entry, and the statistics block at the top of Settings (`settings-*.png`) |
| `Save failure — Retry offered` | `testAFailedSaveShowsRetryAndDoesNotAdvanceTheSession` | The visible save-failure banner and its Retry action |
| `Controls — bottom centre` / `left edge column` / `right edge column` | `testTheGripMovesTheClusterToEachFixedPosition`, `testPlayEveryControlPosition` | The cluster at each of the three fixed positions (`controls-bottom`, `controls-left-column`, `controls-right-column`) with the photo frame unchanged |
| `Controls — close in the top left` | `testCloseIsSmallInTheTopLeftCorner` | The small X in the corner (`controls-close-top-left`) |
| `Entry — nothing waiting` / `a session waiting` / `a session and marks waiting` | `testPlayEntryScreenInEveryState` | The three reachable entry states (`entry-01`–`03`) |
| `Choose a photo — overview` / `oldest first` / `jumped to a month` | `testChoosePhotoExplainsItselfAndGroupsTheLibraryByMonth`, `testChoosePhotoCanJumpStraightToAMonth` | Explanation and traversals, oldest-first, and a jumped-to month (`choose-01`–`03`) |
| `Play — cluster position after relaunch` | `testPlayPreferencesSurviveRelaunch` | The position surviving a relaunch (`play-cluster-after-relaunch`) |
| `Play — buttons turned off` | `testPlayTurningTheButtonsOffKeepsSwipingWorking` | The viewer with the cluster and grip hidden (`play-buttons-off`) |
| `Play — Choose a photo grid columns` / `with a marked photo` / `direction wording` | `testPlayChoosePhotoCellsStayInTheirColumns`, `testPlayChoosePhotoRefusesToStartOnAMarkedPhoto`, `testPlayTheDirectionChoiceMatchesWhereChooseAPhotoWalks` | The grid's columns, the badged cell that refuses a tap, and the direction wording (`play-choose-*`) |
| `Play — home with an empty library` | `testPlayDeletingEverythingLeavesAnHonestEmptyApp` | Home after the whole library is deleted (`play-home-empty-library`) |
| `Play — select mode with two marks chosen` / `review emptied by restoring` | `testPlaySelectModeRestoresSeveralMarksAtOnce` | Select mode, and the empty state after restoring every mark (`play-review-*`) |
| `Play — statistics after two deletions` | `testPlayStatisticsCountConfirmedDeletionsOnly` | The inline lifetime count agreeing on 2 (`play-statistics-after-deletions`) |
| `Play — unreadable saved progress` / `saved progress from a newer version` | `testPlayUnreadableSavedProgressIsExplainedNotOverwritten`, `testPlaySavedProgressFromANewerVersionIsNotOverwritten` | The read-only banner and its Start fresh action (`play-*-progress`) |
| `Play — discarded decision notice` | `testPlayAFailedSaveCanBeDiscarded` | The notice that a discarded decision was left out |
| `Play — <screen> at the largest text size` (7) | `testPlayEveryScreenAtTheLargestAccessibilityTextSize` | Entry, viewer, tutorial, review, result, Choose a photo and Settings at AX5 (`play-*-ax5`), with the stacking that keeps labels whole |

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
