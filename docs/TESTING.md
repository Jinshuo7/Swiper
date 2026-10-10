# Testing

This document records the exact commands used to verify SWIPR and what a future
agent needs to re-run them. Keep it in sync when the test setup changes.

## Current production-v1 testing contract (issue #24)

Production v1 is specified by [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24)
and [`docs/SPEC.md`](SPEC.md). Testing follows its Testing Decisions: assert
externally observable behaviour and durable invariants; use the application-model
integration seam against fakes; extend fixtures to mixed photo/video, unavailable
previews, Skip and playback transitions; cover dock gesture arbitration, EN/zh-Hans
catalogues, and Dynamic Type through the largest accessibility category.

* **Former baseline failure, now fixed:** the largest-accessibility-text
  ("AX5") reachability case
  `PlaySessionUITests.testPlayEveryScreenAtTheLargestAccessibilityTextSize`
  could not scroll `choosePhoto.newest` at AX5. #58 fixed the traversal order in
  `assertReachable`, and #69 removed the CI `-skip-testing` exclusion, so the
  case runs on every PR and an all-green suite is now meaningful.
* **Legacy photo-only build.** Everything below records the as-built build from
  issues #10–#16. Its **grip/single-entry narrative is historical, not
  normative**: production v1 replaces the grip with direct whole-dock movement
  and replaces the single "Choose a photo" entry with Home + editable filters
  (see [`docs/SPEC.md`](SPEC.md) §§2–5). The exact commands remain useful.
* Automated tests never touch a real library; UI tests launch with
  `-uiTestingFakeLibrary`.

## GitHub Actions (CI)

Every pull request runs `.github/workflows/ci.yml` on GitHub's `xcode-27`
hosted runner (default `/Applications/Xcode.app` is Xcode 27, iOS 27 simulator
installed). A `workflow_dispatch` also works. The job, with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and a repository-local
derived-data path, runs exactly:

1. `git diff --check <PR base>...HEAD` — whitespace check over the PR diff
   (full-history checkout, so this is the PR's changes, not the clean tree).
2. `Scripts/run-kit-tests.sh` — pure-logic suite on macOS.
3. `Scripts/typecheck-ios.sh` — iOS compile check.
4. `xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR -destination
   'platform=iOS Simulator,name=iPhone 17,OS=27.0'` — the full simulator suite
   (kit, app and UI targets) against the fake library (`-uiTestingFakeLibrary`),
   never a real photo library.

**Nothing is skipped in CI.** The AX5 reachability case
`SWIPRUITests/PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize`
used to be excluded with `-skip-testing:` while it could not scroll
`choosePhoto.newest` at the largest accessibility text size. #58 fixed the
scroll and #69 removed the exclusion; the case now runs on every PR. No other
test is skipped or weakened.

**Gates GitHub cannot replace.** CI has no dedicated `SWIPR iPhone 11 Pro`
simulator, no connected iPhone, and no human eye. The owner's Mac still owns:
the full-simulator run and result-bundle/screenshot inspection documented below,
the physical-iPhone run (unlocked, developer mode, personal-team signing), and
the manual real-Live-Photo check.

### The launch/terminate handoff (#81)

The suite drives one installed app through ~50 test methods, so almost every
test crosses a launch or a terminate handoff, and every reported #81 failure is
one of those handoffs going wrong: `Failed to terminate
com.zhangjinshuo.swipr:<pid>: Failed to terminate com.zhangjinshuo.swipr:0`
raised from `XCUIApplication.launch()`, a Home that never appeared after a
launch, a viewer that never appeared after a relaunch, and a Home entry asserted
before the decision behind it had been saved.

Every launch, terminate and starting-point handoff now goes through
`SWIPRUITests/AppLaunchHandoff.swift`, which keeps three rules:

- the app is stopped through the one `XCUIApplication` that launched it.
  `terminate()` resolves the process through that instance's launch record, and a
  never-launched proxy is what reports the `:0` above;
- `stopAppUnderTest()` runs in `tearDown` and blocks until the system reports the
  process gone, so the next `launch()` begins from `notRunning` instead of having
  to terminate a dying app itself;
- `launch(_:firstScreen:)` then waits until the app is in the foreground with the
  screen that launch promises on screen, and `beginSession(_:in:)` waits for the
  grid to hand over to the viewer **or** to the `Start a new session?`
  confirmation a saved session raises, instead of guessing after one second and
  leaving the confirmation covering a viewer that never arrives.

This is synchronisation, not retry: no test is removed, skipped, shortened,
loosened or marked expected-failure. `testEveryLaunchRunsTheArgumentsItWasGiven`
launches the same way three times in a row and makes the app prove it read the
arguments of *that* launch, so the handoff cannot silently regress.

**Every lookup names the collection the element lives in** — `app.buttons[…]`,
`app.staticTexts[…]`, `app.images[…]`, `app.otherElements[…]`, `app.switches[…]`
— instead of `app.descendants(matching: .any)[…]`. The generic form asks the
snapshot service for the whole tree and then filters it, and it was the most
expensive query in the suite; the typed form hands the element kind over with the
request. A SwiftUI view takes the element its content makes it, which is not
always obvious: `viewer.photo` and `choosePhoto.cell.<id>` are `Image`s because
their content is a thumbnail, `viewer.cluster`, `viewer.mediaBadge` and
`replaceSession.confirmation` are `Other` because they are combined containers,
`settings.showButtons` is a `Switch`, and `persistence.readOnly` is the warning
`Image` inside the banner. Dump `app.debugDescription` and read the tree rather
than guessing; a wrong guess fails the test loudly rather than silently.

Two families are deliberately the exception, because their element kind follows
their content: the viewer canvas (`viewer.photo`) and the grid cells
(`choosePhoto.cell.<id>`) are an `Image` once the fixture has rendered and a
`ProgressView` or an empty container before that, so a typed query would miss
them in precisely the state `waitForExistence` is there to wait out. They — and
only they — are looked up by identifier. The suite has no generic `element(_:_:)`
helper any more, and `assertReachable`/`assertFullyOnScreen` take the identifier
plus the collection, so every call site still shows what it expects.

**What the fix does not remove.** The CI runner still loses the automation
session with the app about one run in three, and the two signatures seen so far
are both XCTest's own: `Failed to terminate com.zhangjinshuo.swipr:<pid>:
Failed to terminate com.zhangjinshuo.swipr:0` after a 68 s terminate wait, and
`Failed to get matching snapshots: Timed out while evaluating UI query` after
three 30 s accessibility-snapshot retries. Neither reproduced locally in four
full suites and ~800 app launches/terminates on `SWIPR iPhone 11 Pro`, while the
CI runner hits it about once every 75 handoffs, which is the rate #81 recorded
before this work. It is an XCTest/CoreSimulator stall, so it is parked with
`needs-owner` and its evidence rather than retried or skipped. The remaining cost
is the 66 app launches and terminates a run needs: every test sets its own launch
arguments, so a test cannot reuse the previous test's app without an app-side
reset seam inside the risky paths (and it would leak tutorial, store and session
state between tests), which is why the launch count is left alone.

#### Local reproduction loop for the flake

Two flakes in about six full CI runs is too rare to chase with single runs, so
run the tests that cross a handoff several times in a row. The loop the #81 fix
was developed and re-run against:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test-without-building -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS Simulator,id=71EAC83D-54D4-451A-AB32-74A8878C7869' \
  -derivedDataPath ./.derivedData-simulator \
  -only-testing:SWIPRUITests/SWIPRUITests/testCaptureViewerKindScreensInEveryAppearance \
  -only-testing:SWIPRUITests/SWIPRUITests/testKillingTheAppMidSessionRestoresPositionMarksAndUndo \
  -only-testing:SWIPRUITests/PlaySessionUITests/testPlayPreferencesSurviveRelaunch \
  -only-testing:SWIPRUITests/PlaySessionUITests/testPlayEntryScreenInEveryState \
  -only-testing:SWIPRUITests/PlaySessionUITests/testPlayTumblerVisitsEveryPhotoExactlyOnce \
  -test-iterations 6
```

`-test-iterations` only repeats the selection inside one local run; it is never
added to CI and it never hides a failure (`-retry-tests-on-failure` is not used
anywhere). The full-suite loop is the CI job's own command repeated:

```sh
for i in 1 2 3; do
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR \
    -destination 'platform=iOS Simulator,id=71EAC83D-54D4-451A-AB32-74A8878C7869' \
    -derivedDataPath ./.derivedData-simulator
done
```

### Focused simulator prototype check

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS Simulator,id=71EAC83D-54D4-451A-AB32-74A8878C7869' \
  -derivedDataPath ./.derivedData-simulator \
  -only-testing:SWIPRUITests/ViewerDockPrototypeTests
```

There are three test targets:

| Target | What it covers | Where it runs |
| --- | --- | --- |
| `SWIPRKitTests` | Pure logic: ordering, marks, undo, persistence and migration, reconciliation, statistics, layout | macOS, simulator or device |
| `SWIPRAppTests` | `AppModel` against `FakePhotoLibrary` and a controllable `InMemorySessionStore`: acknowledgement, failure/retry, restart, recovery, deletion outcomes | Simulator or device |
| `SWIPRUITests` | Real UI against the fake library: viewer bounds, drag feedback, tutorial, home/review navigation, screenshots — plus the exploratory `PlaySessionUITests` "play like a user" suite | Simulator or device |

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

## Full suite on the dedicated simulator

Xcode 27.0 has the iOS 27.0 arm64 runtime installed. The stable test device is
`SWIPR iPhone 11 Pro` (`71EAC83D-54D4-451A-AB32-74A8878C7869`).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS Simulator,id=71EAC83D-54D4-451A-AB32-74A8878C7869' \
  -derivedDataPath ./.derivedData-simulator
```

- Latest result (2026-09-27): 132 `SWIPRKitTests`, 31 `SWIPRAppTests`, and 53
  `SWIPRUITests` executed. **215 of 216 passed.** Result bundle:
  `.derivedData-simulator/Logs/Test/Test-SWIPR-2026.09.27_23-18-16-+0800.xcresult`.
- The one failure reproduces by itself:
  `PlaySessionUITests.testPlayEveryScreenAtTheLargestAccessibilityTextSize`
  cannot scroll `choosePhoto.newest` back from an offscreen frame at AX5. This
  is a test/app scrolling issue, not a simulator setup failure. **Fixed by
  #58** (`assertReachable` now walks the starting point top-down); **#69**
  removed the CI skip, so the case runs on every PR again.
- Simulator tests use local ad-hoc signing and do not need an Apple account,
  provisioning profile, connected phone or unlocked device.
- For a visible device window, open
  `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` and select
  `SWIPR iPhone 11 Pro`. Xcode 27 no longer bundles a standalone
  `Simulator.app` under the previous path.

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
would, entirely against the fake library: every preset, the dock at all three
places (bottom, left and right, moved by dragging its own controls and gaps),
marking,
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


### The control redesign (2026-09-23, third round) — historical as-built

> **Historical, not normative.** This describes the legacy photo-only build's
grip/puck/slot controls. Production v1 uses direct whole-dock movement; see
[`docs/SPEC.md`](SPEC.md) §5 and [ADR-0007](adr/0007-three-fixed-control-positions.md).

The viewer's controls were replaced again, following `docs/adr/0006`–`0009`:

- Close is fixed in the top left, drawn at 34 pt inside a 44 pt tap region. The
  Review entry shares the top strip, and the LIVE chip is centred between them.
- The cluster of three (Trash, Keep, Undo) now sits at exactly **three fixed
  positions** — a bottom row centred 20 pt above the bottom safe edge, and
  columns centred at 75% of the safe-area height 20 pt inside the left and right
  edges — stored as a three-way `ControlPosition`. The continuous position, the
  rail and the anchor migration are gone.
- Trash and Keep stay adjacent; Undo sits at an outer end chosen by the two-way
  `undoSide` setting, and the grip moves to the opposite end
  (`docs/adr/0011-undo-at-the-outer-end.md`).
- It is moved by dragging a **three-dot grip** in the tray's end opposite Undo,
  in a
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
`testTheClusterKeepsItsPlaceBetweenPhotos`, `testCloseIsSmallInTheTopLeftCorner`,
`testShowButtonsToggleHidesAndRestoresTheCluster` and
`testUndoSitsAtAnOuterEndAndMovesWithTheSetting`. The play suite adds
`testPlayEveryControlPosition`, which walks all three positions and checks at
reach that every control stays on screen, tappable, and clear of the top strip.

`SWIPRKitTests.ControlPreferencesTests` and `ControlClusterLayoutTests` cover the
storage and geometry: an old three-way rail becomes the matching fixed stop, an
unknown rail is still rejected, and the three centres, sizes and the dock frames
at each destination match the spec. `SWIPRKitTests.SessionPersistenceTests`
covers the version 3 state, including a version 2 session with a favourite undo
entry.

### Direct dock movement (2026-10-08, #76) — current

The grip, the puck and the phantom slots above are gone. The dock is now dragged
by its **whole surface**: a drag may begin on any control or in any gap in the
dock, roughly nine points of movement cancels that gesture's pending tap for
good, and the dock becomes a compact neutral token that follows the finger.
`SWIPRKit/DockGeometry` owns the arithmetic (tap-cancel threshold, bounded
capture radius with hysteresis, invalid-release return); the three destination
markers are drawn in the dock's own shape at `ControlClusterLayout.slotRect`.

Sharp edges for the next change here (`ViewerView.swift`):

- the drag reports its points in **window coordinates** (`DragGesture(...
  coordinateSpace: .global)`), because the dock changes shape and place while
  the gesture that started on it is still running, and a point must not change
  meaning halfway through;
- the gesture is a **`.simultaneousGesture`** on the dock's own container, so the
  controls keep their normal taps while the tray's padding becomes draggable too;
- a control's own action fires on the **same touch-up** that ends a drag, and
  SwiftUI gives no order between the two. `dockMoved` therefore outlives the
  gesture by one main-queue turn (`finishDockTouch()`), which is what makes "a
  move never decides" true rather than likely;
- a drop back on the destination the dock already occupies goes through
  `AppModel.moveDock(to:)`, which refuses a position that has not changed, so a
  drag that ends where it started writes nothing at all. (Writing preferences
  no longer re-pins the session's direction: see the #78 section below, where
  that re-pin became conditional on **Default direction** actually changing.)
- `DockGeometry.capture` checks the destination already captured against
  `releaseRadius` **before** considering a nearer one, because mid-way between the
  bottom row and a side column the nearest destination flips while the finger is
  still well inside the captured one's release radius;
- the visual state is `@State` and the cancellation reset is keyed off a
  `@GestureState`, so an interrupted gesture restores the source.

`SWIPRUITests` covers it with `testTheDockMovesToEachFixedPosition`,
`testEveryControlCanMoveTheDockToEveryDestination` (all three controls to all
three destinations, plus a drag that begins in the tray's padding),
`testNormalTapsStillDecideAtEveryPosition`, `testAShortDragCancelsTheTapWithoutDeciding`,
`testAReleaseOverNoDestinationRestoresTheSource`, `testAPlainSwipeNeverMovesTheCluster`,
`testTheDockIsATokenWhileItIsBeingMoved` (mid-hold media frame) and
`testThePhotoFrameIsIdenticalAtEveryControlPosition`. `SWIPRAppTests` covers the
model seam with `testMovingTheDockSavesItsPlaceImmediately` and
`testDroppingTheDockOnItsOwnPlaceLeavesTheSessionAlone`, and `DockGeometryTests`
adds `testEverySourceCanReachEveryDestination`,
`testAReleaseBackOnTheSourceLandsOnTheSource`,
`testAReleaseOverNoDestinationRestoresTheSource`,
`testTheNearestDestinationResolvesAnOverlap` and
`testACapturedDestinationHoldsUntilItsReleaseRadiusIsPassed`. The play suite adds
`testPlayEveryControlPosition` and `testDestinationMarkersWhileMovingTheDock`.
`testCaptureTheDockAtEveryPositionInEveryAppearance` produces the v1-04
dock-* screenshots in light, dark and at the largest text size.

### Neutral dock chrome and its two layouts (2026-10-09, #77) — current

`ControlClusterLayout` now gives the three fixed positions **two layouts**, and
the chrome of both is neutral:

- at the **bottom**, a labelled **Delete / Keep** pair inside one tray, with the
  separate Undo control drawn smaller beside it;
- at a **side**, three separate icon controls a non-action gap apart.

The labelled **Delete/Keep pair is the dock's anchor in both layouts**:
`ControlClusterLayout.centre` is the pair's centre at every position, and
`slotRect(for:in:undoSide:)` grows off that anchor by the one control and gap the
separate Undo adds — to the side it took at the bottom, above it at a side.
Changing which end Undo takes therefore moves only the Undo end of the dock, and
never shifts Delete and Keep under the thumb: "Before actions" (Undo left of the
bottom pair, above a side pair) and "After actions" mirror each other with one
mapping, asserted in both layouts before and after flipping the setting.

The dock's size is fixed **for a given screen width**, never by its content or
its state: 286 × 68 at the bottom and 56 × 196 at a side on a standard phone,
where the media never moves for chrome (ADR-0006). The one thing a screen width
changes is the bottom pills' width, one bullet below — so on a 320 pt layout that
same bottom dock is 248 × 68, still anchored on its pair.

Sharp edges for the next change here:

- **No state rests on colour.** The only red and green in the viewer are the
  `DockEdgeTint` rims — desaturated, 0.16 opacity, drawn only at a control's own
  edges and at the same strength in every state — plus the swipe wells' rim. The
  symbol, the word, the stroke and the weight carry every outcome, and
  `WellBackground`'s armed state is a heavier stroke (1 → 3 pt) and the drag's
  own opacity rather than a stronger fill.
- **The drag handle is the whole box.** `contentShape` is a lightly rounded
  rectangle (12 pt) over the dock's frame, so the 12 pt gap beside the separate
  Undo control and the tray's own padding both move the dock, and a drag that
  begins in either is still not a decision.
- **`Undo` at the bottom is 44 pt**, the smallest target the accessibility
  contract allows; at a side it is a full 56 pt control like the other two.
- **The pills narrow on a narrow screen, and nothing else moves.**
  `fittedPillWidth(in:)` gives the pills their 104 pt design width until the
  whole dock — the tray's other half plus the separate Undo — would run off a
  320 pt layout, which is the narrowest iOS 17 one (and what Display Zoom
  produces on a small phone). There they shrink to 85 pt, with a 76 pt floor, so
  the pair keeps its anchor and Undo keeps its full target. This is the one place
  the screen decides the dock's geometry: the dock is fixed for a given width, and
  the media never moves for chrome (ADR-0006).
- **The pill labels stop growing on purpose.** The dock's geometry is pinned, so
  `DecisionPill` caps its scaled font at 20 pt and never truncates an action —
  the AX5 screenshots show both labels whole. The full action name is always the
  control's accessibility label.

`SWIPRUITests` covers it with `testTheDockLayoutsAndTheOneUndoMapping` (both
layouts, the pill/circle shapes, the centred pair, Undo outside it and smaller,
Undo leading both layouts, then After actions moving only the Undo end), and the
dock tests above now assert the row's pair is centred rather than the whole dock.
When the column is on screen, `assertClusterIsAColumn` also asserts the
non-action gap and the safe-area inset. `ControlClusterLayoutTests` adds
`testTheTwoLayoutsHaveTheirOwnFixedSize`,
`testThePairKeepsTheAnchorWhicheverEndUndoTakes`,
`testANarrowLayoutFitsTheWholeDockWithoutMovingThePair` (320 pt, both Undo ends),
`testTheBottomPairStaysCentredWhenUndoChangesEnd`,
`testTheSideLayoutSeparatesItsControlsWithANonActionGap` and
`testEveryDestinationDrawsTheWholeDockAtItsOwnSize`; `DockGeometryTests` now
checks the real `slotRect` at both Undo ends. The v1-04 dock screenshots were
re-captured in light, dark and at the largest text size. The narrow-layout fit is
framework-tested only: the suite's simulator is a 375 pt `SWIPR iPhone 11 Pro`,
and no launch argument changes a device's point width.

### The four control preferences (2026-10-09, #78) — current

The dock's four choices are one stored struct, `SWIPRKit.ControlPreferences`, and
a Settings section that sets each one without a drag:

- **Control Position** — the three fixed places, as before;
- **Show Buttons** — whether the dock is drawn at all, as before;
- **Haptics** — new: `ControlPreferences.haptics`, default on, one switch;
- **Undo Position** — the same two-value `undoSide`, now named the way the spec
  names it: `UndoSide.title` is **Before actions** (the default, `.leading`) or
  **After actions**, read relative to the Delete/Keep pair rather than as a screen
  side, so the same wording is true of the bottom row and of a side column.

`haptics` is an additive, backward-compatible key: `init(from:)` reads it with
`decodeIfPresent(Bool.self, forKey: .haptics) ?? true`, so every payload written
before the setting existed loads with haptics on and nothing is migrated,
rewritten or lost. The key order in `encode(to:)` is unchanged in effect — every
field is written by name.

**Haptics are one pure mapping, one gate.** `HapticFeedback.response(to:enabled:)`
answers for every optional moment — nothing on pickup, one light response the
first time a destination is captured, nothing while it stays captured, one soft
response on a valid landing, nothing on an invalid release or a cancelled touch,
and one light response for a swipe crossing the commit threshold (docs/SPEC.md
§4.4) and for a press on a control. `ViewerView` has one `giveHaptic(_:)` that
asks that function with `model.preferences.haptics`, so "Haptics off" cannot be
honoured at one call site and missed at another. A destination that stays
captured is asked for **by name** (`.captureHeld`) rather than skipped by a
`guard`, which is what keeps "no repeats while captured" the mapping's rule.

**The current position is announced, not just listed.** Each Settings choice row
carries `.accessibilityValue("Selected")` and the `.isSelected` trait when it is
the current one, so VoiceOver says which place the dock is in and which Undo
position is set, and placement never needs a drag. The dock itself still carries
`accessibilityValue("Docked <place>")` and the "Move to the next position"
action.

**Only Default direction re-points a running session.** `AppModel.updatePreferences`
used to re-pin the engine's direction from the saved default on *every* preference
write, and save that. That is harmless for a session walking the default way and a
silent reversal for one the user began with an explicit **Newest first** or
**Oldest first**, which is exactly what Codex round 1 caught on this PR: toggling
the new Haptics switch would have turned the walk around. The write now re-pins
only when `preferences.defaultDirection` itself changed, so the other four
preferences leave the running session and the saved session alone.

Covered by `SWIPRKitTests.HapticFeedbackTests` (the move contract, the two other
optional moments, and every event silenced when the preference is off),
`ControlPreferencesTests` (defaults including `haptics` on, the round-trip with
`haptics: false`, the Before/After names, and a payload with no `haptics` key
defaulting to on), `SWIPRAppTests`
(`testControlPreferencesStartAtTheDocumentedDefaults`,
`testEveryControlPreferenceSurvivesRelaunchWithoutDisturbingSavedWork` — all four
saved, all four back after a relaunch, and the marked photo, the position and
Undo untouched by the write — and `testEveryControlPreferenceReachesTheViewer`),
and `SWIPRUITests` (`testSettingsAnnouncesTheCurrentPositionAndTheUndoPosition`,
`testSettingsOffersHapticsAndRemembersIt` across a relaunch, and the haptics row
added to `testSettingsOffersTheThreePositionsAndAReset` and to the AX5
reachability list). `SWIPRAppTests` also covers the re-pin rule:
`testChangingAControlPreferenceNeverReversesTheRunningSession` walks all four
preferences past a session pinned to `.newer` and asserts the walk and the saved
session do not move (verified by restoring the old unconditional re-pin, which
fails it four times), and
`testChangingTheDefaultDirectionRePointsAndSavesTheRunningSession` keeps the
direction choice working. `testCaptureTheSettingsControlsInEveryAppearance`
produces the v1-04 `settings-controls-*` and `settings-undo-position-*`
screenshots.

Sharp edges for the next change here:

- **The row's mark and the row's spoken value are one comparison.**
  `positionRow`/`undoPositionRow` compute `isCurrent` once and use it for the
  filled mark, the accessibility value and the trait, so the picture and the
  announcement cannot disagree.
- **Haptics is asked for, never played directly.** Anything that would buzz goes
  through `ViewerView.giveHaptic(_:)`; calling a `UIImpactFeedbackGenerator`
  directly would bypass the one preference.
- **Settings is a scrolling list.** New rows belong inside `settingSection` and,
  if they are added near the bottom, must be added to the AX5 reachability list
  in `PlaySessionUITests`, which only ever scrolls downward.

These screenshots go to `docs/screenshots/milestones/v1-04/`. Settings is still
pinned dark (the Appearance setting is a later ticket), so its light and dark
captures render identically; the pair is kept because the milestone asks for both.

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
| `Controls — bottom centre` / `left edge column` / `right edge column` | `testTheDockMovesToEachFixedPosition`, `testPlayEveryControlPosition` | The dock at each of the three fixed positions (`controls-bottom`, `controls-left-column`, `controls-right-column`) with the photo frame unchanged |
| `Controls — moving, with the three destination markers` | `testTheDockIsATokenWhileItIsBeingMoved` | The compact token held at a destination and the three subtle markers, captured mid-gesture because they exist only while the finger is down |
| `Design — destination markers mid-move` | `testDestinationMarkersWhileMovingTheDock` (play suite) | The same mid-move state next to the approved references |
| `dock-<place>-<appearance>` (12) | `testCaptureTheDockAtEveryPositionInEveryAppearance` | The dock at bottom, left and right in light, dark and at the largest text size, plus the held mid-move state — committed under `docs/screenshots/milestones/v1-04/` |
| `settings-controls-<appearance>` / `settings-undo-position-<appearance>` (6) | `testCaptureTheSettingsControlsInEveryAppearance` | The four control preferences in Settings — Show buttons, Haptics and the three places, then the Undo position and the reset row — in light, dark and at the largest text size, committed under `docs/screenshots/milestones/v1-04/` |
| `Controls — close in the top left` | `testCloseIsSmallInTheTopLeftCorner` | The small X in the corner (`controls-close-top-left`) |
| `Entry — nothing waiting` / `a session waiting` / `a session and marks waiting` | `testPlayEntryScreenInEveryState` | The three reachable entry states (`entry-01`–`03`) |
| `Choose a photo — overview` / `oldest first` / `jumped to a month` | `testChoosePhotoExplainsItselfAndGroupsTheLibraryByMonth`, `testChoosePhotoCanJumpStraightToAMonth` | Explanation and traversals, oldest-first, and a jumped-to month (`choose-01`–`03`) |
| `Play — cluster position after relaunch` | `testPlayPreferencesSurviveRelaunch` | The position surviving a relaunch (`play-cluster-after-relaunch`) |
| `Play — buttons turned off` | `testPlayTurningTheButtonsOffKeepsSwipingWorking` | The viewer with the dock hidden (`play-buttons-off`) |
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
