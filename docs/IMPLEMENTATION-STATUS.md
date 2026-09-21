# Implementation status checkpoint

Durable resume point for the autonomous implementation of GitHub issues #11–#16
(parent spec #10). Read this together with `docs/IMPLEMENTATION-PROMPT.md`,
`docs/specs/photo-cleaning-redesign.md` and the active issue on GitHub.

## Current ticket

**#15 — Minimal swipe feedback and replayable teaching** (checking, commit next).

## Environment notes (learned this session)

- The DSH file sandbox is `workspace-write`; `xcodebuild` writing to the default
  `~/Library/Developer/Xcode/DerivedData` is denied. Always pass
  `-derivedDataPath ./.derivedData`.
- SwiftUI macros fail with "…StateMacro could not be found … produced malformed
  response" inside a nested sandbox. Pass
  `-Xfrontend -disable-sandbox` (for `xcodebuild`:
  `OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'`). Recorded in
  `AGENTS.md`; `Scripts/typecheck-ios.sh` sets it itself.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` must prefix Xcode
  commands.
- **Device availability is intermittent.** The iPhone 11 Pro
  (`00008030-000669DE3408802E`) showed `booted` at the start of the session, then
  flipped to `unavailable` during the first UI-test run, which then hung for 35
  minutes with no xcresult progress and had to be killed. No simulator runtime
  exists (`xcrun simctl list runtimes` is empty), so UI and app integration tests
  cannot run anywhere else. Device-dependent checks are re-attempted at ticket
  boundaries and reported honestly.

## Ticket #11 — DONE (commit c61491f)

Changed:

- `SwiperKit/PhotoLayout.swift` (new): pure contain-fit geometry
  (`fittedSize`, `fittedRect`, `fitsWithoutCropping`).
- `SwiperKit/DeletionWording.swift` (new): one vocabulary for
  "N photos marked for deletion", "Review · N", "Nothing deleted yet.".
- `SwiperKit/Models.swift`: `AssetDescriptor.aspectRatio`.
- `Swiper/Views/ViewerView.swift`: the canvas is framed to exactly the fitted
  rectangle (so the `viewer.photo` frame *is* the photo bounds), stills and Live
  Photos are contained (`scaleAspectFit`), the permanent gesture hint is gone,
  and a compact `Review · N` control sits inside the safe area.
- `Swiper/PhotoLibrary/FakePhotoLibrary.swift`: demo fixtures cycle landscape /
  portrait / square / panorama and draw border, four corner blocks and a label.
- `SwiperUITests/SwiperUITests.swift`: the provisional pixel-sampling test was
  replaced by frame assertions (contained in the screen, own aspect ratio, never
  the screen ratio, controls on screen).
- `SwiperKitTests/PhotoLayoutTests.swift`,
  `SwiperKitTests/DeletionWordingTests.swift` (new).
- Docs: `docs/SPEC.md` §3, `CONTEXT.md`, `AGENTS.md`.

Checks actually run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh`
  → **88 tests, 0 failures** (on the commit, verified in a clean git worktree).
- `… Scripts/typecheck-ios.sh` → `OK`.
- `xcodebuild build-for-testing -destination 'generic/platform=iOS'` →
  `** TEST BUILD SUCCEEDED **`.
- Device UI suite: **NOT RUN — blocked**, phone `unavailable`.

## Ticket #12 — DONE (commit 86e00bc), issue left OPEN

Decisions:

- Persisted shape is now `PersistedState { schemaVersion, marks, session,
  updatedAt }` with `schemaVersion = 2`. The deletion list moved out of
  `PersistedSession` to the top level so #13 can give it a lifetime independent
  of a sorting session. The file name (`session.json`) is unchanged; the
  unversioned legacy shape is decoded and migrated, so no user data is lost.
- `SessionLoadResult` distinguishes `absent` / `loaded` / `migrated` /
  `unreadable` / `unsupportedVersion`. Writes are refused while unreadable or
  newer-version bytes are in the way; `quarantineUnreadableState()` preserves
  them under `session-unreadable-<stamp>.json` and unblocks writing.
- `SessionStoring` writes now `throw`, so a failed save can never be silent.
- `AppModel` applies a decision to a copy, saves it, and only then publishes and
  advances. A failed save parks a `PendingDecision` (engine + effects + message),
  pauses input and offers Retry (persistence only, so no effect is repeated) or
  Discard. All mutations run on one serial chain.
- Overlap with old issue #1: #12 implements the substance of #1 (version field,
  distinguishable unreadable/future state) but not its "refuse loudly, invent no
  UI" constraint, which the new spec supersedes with migration plus visible
  recovery. #1 and #8 are left open and untouched; ADR-0004 covers #8's decision.

Not verified: the `SwiperAppTests` cases and all UI tests have not executed
(device unavailable). The issue stays open until they run.

## Ticket #13 — DONE (commit 96abcb2), issue left OPEN

Decisions:

- `SessionEngine` keeps `decidedIDs` and the durable marks as one
  "unavailable" set, so every sorting entry point (sequential both directions,
  Tumbler, `upcomingIDs`, `remainingCount`, `jump(to:)`) skips a marked photo.
  `jump` refuses a mark outright, and Start Here badges marked cells.
- `AppModel.startSession` seeds the new engine with the durable marks instead of
  clearing them. A new session still resets traversal, in-session decisions and
  Undo.
- `SessionEngine.restore` now also inserts the restored id into `decidedIDs`, so
  a restored photo is kept for the current session and can return in a later one.
  Conflicting Undo entries were already dropped on restore.
- `AppModel.restore` works with no active session (home → review → restore only
  unmarks and saves).
- Review tracks `reviewOrigin`, so Back returns to the viewer, home or the result
  it came from. `performConfirmedDeletion` now works from `markedIDs` rather than
  requiring an engine, keeps unsuccessful items marked and never double-counts.
- Home shows `Continue sorting` and `Review & delete · N` with the
  marked-not-deleted footer; `docs/adr/0005` records the lifetime decision;
  CONTEXT/SPEC/VISION/ROADMAP updated.

Checks: 110 SwiperKit tests 0 failures; typecheck `OK`; build-for-testing
`TEST BUILD SUCCEEDED`.

Not verified: `SwiperAppTests` and UI tests have still not run (device
unavailable). #13 stays open until they do.

## Ticket #14 — DONE (commit 98a6f36), issue left OPEN

Decisions:

- `closeViewer()` makes leaving the viewer explicit: every decision was already
  saved before it was acknowledged, so Close navigates home and never discards.
- `continueAfterResult()` routes after a commit: an active session resumes at its
  sorting position, an exhausted session with marks left lands in review, and no
  session goes home. The result button label follows the same rule.
- Comparison of a cancelled deletion: the fake library can now submit assets
  without removing them (`-uiTestingFailDeletion`), which is exactly what a
  cancelled system confirmation looks like. Marks stay, statistics stay at zero,
  and the result says nothing was deleted.
- Interrupted commit (PhotoKit effect succeeded, local save failed) is exercised
  by failing writes after the delete and relaunching over the same store: the
  vanished mark is reconciled away and the deletion is counted once, never twice.
- SPEC §6 gained the explicit recovery policy and the safety invariant that an
  acknowledged decision is saved first.

Checks: 110 SwiperKit tests 0 failures; typecheck `OK`; build-for-testing
`TEST BUILD SUCCEEDED`.

Not verified: app/UI tests still have not run (device unavailable).

## Ticket #15 — in progress

Decisions:

- The viewer's drag now reveals feedback-only lower-corner wells (trash left,
  check right) built from `ultraThinMaterial` plus a tinted fill and stroke; the
  layer is `allowsHitTesting(false)` and `accessibilityHidden`, so it never
  swallows the drag and is never announced as a control.
- The commit threshold (90 pt horizontal) is visible (the well arms) and felt
  (one light `UIImpactFeedbackGenerator` at the crossing only). Releasing below
  the threshold, releasing a vertical drag, or a short drag makes no decision.
- Reduce Motion removes the spring-back and the well's scale change; symbol,
  wording and stroke still carry the meaning.
- `TutorialView` explains marking, keeping, review confirmation and automatic
  saving, adapting its wording to the selected preset. It is shown with the first
  photo, dismissed once (in-memory guard so a launch argument cannot resurrect
  it), and replayable from Settings → How to use. Tutorial state lives in an
  injectable `UserDefaults`, so app tests use an isolated suite.
- The viewer photo now carries a spoken description (photo, date, marked or not)
  so the image is not an unlabelled element.

Checks: kit tests 0 failures; typecheck `OK`; build-for-testing
`TEST BUILD SUCCEEDED`.

Next steps: commit #15, comment on it, then #16 (integrated verification,
screenshots, docs sync, final checkpoint).
