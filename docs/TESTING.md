# Testing

This document records the exact commands used to verify Swiper and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

There are three test targets:

| Target | What it covers | Where it runs |
| --- | --- | --- |
| `SwiperKitTests` | Pure logic: ordering, marks, undo, persistence and migration, reconciliation, statistics, layout | macOS **or** device |
| `SwiperAppTests` | `AppModel` against `FakePhotoLibrary` and a controllable `InMemorySessionStore`: acknowledgement, failure/retry, restart, recovery, deletion outcomes | Device only |
| `SwiperUITests` | Real UI against the fake library: viewer bounds, drag feedback, tutorial, home/review navigation, screenshots — plus the exploratory `PlaySessionUITests` "play like a user" suite | Device only |

Automated tests never touch a real photo library: unit tests use fakes, and every
UI test launches with `-uiTestingFakeLibrary`.

## Pure-logic suite (macOS, always available)

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

- Latest result (2026-09-22, Xcode 27.0): **127 tests, 0 failures**, exit 0.
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
- **Status 2026-09-22 02:30: RUN GREEN.** The full suite ran on the iPhone 11 Pro
  (`00008030-000669DE3408802E`, iOS 26.2.1), `** TEST SUCCEEDED **`:

  | Target | Tests | Result |
  | --- | --- | --- |
  | `SwiperKitTests` | 127 | 0 failures |
  | `SwiperAppTests` | 31 | 0 failures |
  | `SwiperUITests` | 47 | 0 failures |

  205 tests, 0 failures. `SwiperUITests` is 33 cases plus the 14
  `PlaySessionUITests` cases described below; the control redesign replaced the
  rail-order case and added six cluster cases.
- Previously, 2026-09-21 21:09: **188 tests, 0 failures** (126 + 31 + 31), result
  bundle `.derivedData/final4.xcresult`.
- The interrupted-session case runs on the device too:
  `testKillingTheAppMidSessionRestoresPositionMarksAndUndo` terminates the app
  mid-flow, relaunches it, and checks that Continue sorting, the mark and Undo all
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
- The original `SwiperUITests` cases take about 6 minutes because each test
  relaunches the app and several hold a drag for 1.5 s; the play suite below adds
  about 10 minutes.
- Inside a restricted sandbox the run fails before any test starts:
  launching a device test host needs a pseudo-terminal, so without full file
  access Xcode reports
  `IDEPseudoTerminalDomain … ErrorCode: 7 Errno: 1` (EPERM). Full file access is
  the only thing that unblocks it.

## Playing the app like a user (device)

`SwiperUITests/PlaySessionUITests.swift` walks the app the way a curious person
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
xcodebuild test -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS,id=00008030-000669DE3408802E' \
  -derivedDataPath ./.derivedData -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
  -only-testing:SwiperUITests/PlaySessionUITests
```

- Latest result (2026-09-22): **14 tests, 0 failures**, about 6 minutes. The
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


### The control redesign (2026-09-22, second round)

The viewer was redesigned after the owner used it on the phone:

- Close is fixed in the top left, drawn at 34 pt inside a 44 pt tap region. The
  heart and the Review entry share the top right, and the LIVE chip is centred
  between them.
- The five-control rail became a **cluster of three** (Trash, Undo, Checkmark)
  inside a tray that the user holds and drags. It docks to the bottom (a row), the
  left edge or the right edge (a column), slides continuously along that edge, and
  is remembered. Settings gains **Reset control position**, and the cluster's
  accessibility actions step the dock round the edges for anyone who cannot drag.
- The preset list now decides only whether swipe gestures decide anything and
  whether a tap keeps. `Extended` survives as a decoding alias for `Swipe` and is
  no longer offered; order-on-the-rail is gone with the rail.
- The drag wells read **Delete** and **Keep**. The review copy still says
  "marked for deletion", because that is the screen where deletion is real.

Three things about the move gesture are easy to get wrong again:

- The move gesture lives on the **tray**, which is a sibling *behind* the three
  controls, not on the container around them. A `.gesture` on the container was
  never recognised at all (the hold left the cluster idle), and
  `.simultaneousGesture` on it worked but swallowed the buttons' taps, so tapping
  Trash stopped marking anything.
- The move state is a **`@GestureState`**, which resets when a gesture ends *or is
  cancelled*. With a plain `@State` an interrupted drag left the cluster stuck
  reporting "Moving", scaled up, with its buttons refusing to work.
- The accessibility frame of the cluster is whatever its children report, so the
  tests grab the tray beside the first control rather than trusting a computed
  edge, and both `dragCluster` helpers assert that frame is smaller than the
  screen before dragging.

`SwiperUITests` covers this with `testTheClusterDocksToEitherSideAndBecomesAColumn`,
`testAPlainDragNeverMovesTheCluster` (a plain drag must not shove the buttons, and
a move must not decide), `testADockedSideClusterDoesNotCoverThePhoto`,
`testSwitchingPresetDoesNotMoveTheCluster`, `testCloseIsSmallInTheTopLeftCorner`
and `testTheHeartIsInTheTopStripAndStillFavorites`. The play suite adds
`testPlayEveryClusterDock`, which drags the cluster to all three edges and slides
it along the bottom, checking at each stop that every control stays on screen,
tappable, and clear of the top strip.

`SwiperKitTests.ControlPreferencesTests` covers the storage: a legacy anchor or
placement becomes a continuous position, an old `order` key is ignored rather
than rejected, and a position is clamped to 0...1 (a non-finite one falls back to
the centre).

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
| `Controls — fixture step 0…3` | `testControlRailDoesNotMoveBetweenPhotos` | The bottom cluster in the same place for every aspect ratio (`controls-01-bottom-cluster.png`) |
| `Controls — docked to the right edge` | `testTheClusterDocksToEitherSideAndBecomesAColumn` | The cluster rotated to a column at the right edge, with the photo fitted beside its lane (`controls-02-right-edge-column.png`) |
| `Controls — docked to the left edge` | same | The same column at the left edge (`controls-03-left-edge-column.png`) |
| `Controls — close in the top left` | `testCloseIsSmallInTheTopLeftCorner` | The small X in the corner (`controls-04-close-top-left.png`) |
| `Controls — heart in the top strip` | `testTheHeartIsInTheTopStripAndStillFavorites` | The heart on the right of the strip (`controls-05-heart-top-strip.png`) |
| `Settings — statistics row` | `testStatisticsIsReachedFromSettings` | Statistics now inside Settings, reached from a row |
| `Start Here — explanation, months, jump and sort` | `testStartHereExplainsItselfAndGroupsTheLibraryByMonth` | The explanation, month sections with sticky headers, the month menu and the order toggle |
| `Start Here — oldest first` | same | The order toggle actually reversing the month sections |
| `Start Here — jumped to a month` | `testStartHereCanJumpStraightToAMonth` | A month reached by the menu, far beyond one screen of scrolling |
| `Play — cluster docked bottom / left / right`, `Play — cluster slid along the bottom edge` | `testPlayEveryClusterDock` | The cluster at each of the three docks and slid along the bottom, with a Live Photo badge and a Review entry in the top strip and every control clear of both (`play-cluster-*.png`) |
| `Play — cluster dock after relaunch` | `testPlayPreferencesSurviveRelaunch` | The dock surviving a relaunch (`play-cluster-after-relaunch.png`) |
| `Play — tap-to-keep preset` | `testPlayEachPresetDoesWhatSettingsPromises` | The preset that keeps on a tap and ignores drags (`play-tap-to-keep.png`) |
| `Play — Start Here direction wording` | `testPlayTheDirectionChoiceMatchesWhereStartHereWalks` | Start Here naming the direction the user chose (`play-starthere-newer-first.png`) |
| `Play — Start Here grid columns` | `testPlayStartHereCellsStayInTheirColumns` | Every cell one column wide, including the 4:1 panorama thumbnails (`play-starthere-grid-columns.png`) |
| `Play — Start Here with a marked photo` | `testPlayStartHereRefusesToStartOnAMarkedPhoto` | The badged, dimmed cell that refuses to start a session (`play-starthere-marked.png`) |
| `Play — home with an empty library` | `testPlayDeletingEverythingLeavesAnHonestEmptyApp` | Home after the whole library is deleted, with every photo-dependent entry disabled (`play-home-empty-library.png`) |
| `Play — select mode with two marks chosen` / `Play — review emptied by restoring` | `testPlaySelectModeRestoresSeveralMarksAtOnce` | Select mode ticking individual cells — and the review grid's own columns — then the empty state after restoring them all (`play-review-select-mode.png`) |
| `Play — statistics after two deletions` | `testPlayStatisticsCountConfirmedDeletionsOnly` | This-session and lifetime counts agreeing on 2 (`play-statistics-after-deletions.png`) |
| `Play — unreadable saved progress` / `Play — saved progress from a newer version` | `testPlayUnreadableSavedProgressIsExplainedNotOverwritten`, `testPlaySavedProgressFromANewerVersionIsNotOverwritten` | The read-only banner and its Start fresh action |
| `Play — discarded decision notice` | `testPlayAFailedSaveCanBeDiscarded` | The notice that says a discarded decision was left out |
| `Play — <screen> at the largest text size` (8) | `testPlayEveryScreenAtTheLargestAccessibilityTextSize` | The app at AX5: home scrolling rather than clipping its footer (`play-home-ax5.png`), the tutorial scrolling with Got it pinned (`play-tutorial-ax5.png`), and the review and result screens readable (`play-review-ax5.png`) |

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
