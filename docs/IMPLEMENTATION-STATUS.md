# Implementation status checkpoint

Durable resume point for the autonomous implementation of GitHub issues #11–#16
(parent spec #10). Read this together with `docs/IMPLEMENTATION-PROMPT.md`,
`docs/specs/photo-cleaning-redesign.md` and the active issue on GitHub.

## Current ticket

**#12 — Persist accepted decisions and surface recovery failures** (in progress).

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

## Ticket #12 — in progress

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

Next steps: run the checks, commit, comment on #12, then start #13
(cross-session deletion list, skip marked assets, home wording, ADR-0005).
