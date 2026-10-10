# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Setup facts

- **CI runner:** `xcode-27` is a **GitHub-hosted** runner using a custom
  `xcode-27` label (jobs run in the "GitHub Actions" runner group;
  `gh api repos/Jinshuo7/SWIPR/actions/runners` returns `total_count 0`).
  Branch protection on `main` requires the `checks` status, strict (up to date
  with `main`), with force-push and deletion blocked.
- **Driver mode:** the owner replaced Codex with this Pi driver session
  (deepseek-flash, effort high). See the Roles section of
  `docs/agents/OWNER-INSTRUCTIONS.md`.
- **Agent base repo:** `/Users/beastmini/GitHub/Jinshuo7/SWIPR` (renamed from
  `SWIPR-agent`; the old owner folder is gone and this is the main repo now).
  Ticket worktrees live under `/Users/beastmini/GitHub/Jinshuo7/SWIPR-worktrees/`.
- **Risky-PR review workflow:** any PR labelled `needs-strong-review` gets up to
  5 `@codex review` rounds (see `AGENTS.md` → *Risky PR review workflow*). The
  owner has **delegated** approval: add `strong-review-passed` and merge ("Create
  a merge commit", `--match-head-commit <full SHA>`) only when the checks are
  green on that head, a Codex review of that exact head reports no P1, and
  nothing (test, workflow, `risky-paths.txt`, gate) was removed, skipped,
  weakened or loosened. Never merge with an open P1, and never remove
  `needs-strong-review`.

## Current ticket

- **None in progress.** **#78** is delivered and merged (see *Recently merged*
  below); its closing issue **#78** is closed. The remaining V1-04 subticket is
  **#79** (accessibility, screenshots and real-device tuning for the dock).
  **#73** (a migrated Tumbler plan whose cursor vanished) is still not started.

## Open PRs

- **#74 — fix: keep marked photos through Limited Photos access (#70)**
  (`driver/70-limited-marks`, head **`32bf650`**). Risky, `needs-strong-review`,
  **parked `owner-blocked`** with issue **#85**: five Codex rounds found real
  problems and fixed them, an approved sixth round found two more (a hidden pool
  with no visible cursor stopped counting as resumable; the hidden-marks notice
  could bury a later save error), both are fixed on `32bf650` with tests verified
  by breaking the fix, and that head has **no Codex review of its own**. It is not
  broken and not merged; `#70` itself stays open. Do not merge until that head
  has a no-P1 review.
- **#37 — Add deterministic ticket controller** (author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#78 — V1-04d: Persist Control Position, Show Buttons, Haptics, Undo
  Position** (PR #90, merge commit `0151bf6`). The dock's four choices are now
  one stored struct exposed in Settings, and the optional haptics are one pure
  contract behind a new switch. `ControlPreferences.haptics` (default on) is an
  additive key read with `decodeIfPresent(…, forKey: .haptics) ?? true`, so a
  payload written before the setting existed loads with haptics on. **Undo
  Position** is named the way `docs/SPEC.md` §5.6 names it — **Before actions**
  (the default) or **After actions**, relative to the Delete/Keep pair instead of
  Left/Right — while the persisted `undoSide` key and the dock geometry are
  untouched. `SWIPRKit.HapticFeedback` owns every optional response (nothing on
  pickup, one light on the first capture, nothing while a destination stays
  captured, one soft on a valid landing, nothing on an invalid release or a
  cancelled touch, one light for a threshold crossing and a control press), and
  `ViewerView.giveHaptic(_:)` is the only place a haptic is played. Each Settings
  choice row announces the current one through its accessibility value and the
  selected trait, so placement never needs a drag. Two Codex rounds: round 1
  found a real **P1** — every preference write re-pinned the running session's
  direction from the saved default, so toggling the new switch would have
  reversed a walk started with an explicit "Newest first"/"Oldest first" and
  saved the reversal; `AppModel.updatePreferences` now re-pins and writes the
  session only when `defaultDirection` itself changed (fixed in `78d2a92`, with
  `testChangingAControlPreferenceNeverReversesTheRunningSession` failing four
  times when the old re-pin is restored), and round 2 — of that exact head —
  reported no issues. Full local suite green on `SWIPR iPhone 11 Pro`: 233 kit +
  55 app + 75 UI = 363 tests, 0 failures; CI `checks` green. Screenshots:
  `docs/screenshots/milestones/v1-04/` (6: controls and Undo position ×
  light/dark/AX5; Settings is still pinned dark, so its light capture matches the
  dark one).
- **#77 — V1-04c: Neutral decision-dock chrome and side layouts** (PR #88, merge
  commit `7654936`). The dock now has its two neutral layouts: the labelled
  **Delete/Keep pair** inside one stadium tray with a **separate smaller Undo**
  (44 pt) beside it at the bottom, and three **separate icon controls** a 14 pt
  non-action gap apart at the sides. The labelled pair is the dock's anchor in
  both layouts — `ControlClusterLayout.centre` is the pair's centre and
  `slotRect(for:in:undoSide:)` grows off it by the control and gap Undo adds — so
  "Before actions" (Undo left of the bottom pair, above a side pair) and "After
  actions" mirror each other and Delete and Keep never shift under the thumb. The
  red Trash and green Keep buttons are gone: the only red and green left are
  `DockEdgeTint` rims (desaturated, 0.16 opacity, a control's own edges, the same
  strength in every state), the swipe wells wear the same rim and arm by stroke
  weight rather than a tinted fill, and symbols, wording, stroke and weight carry
  every outcome. The dock is a fixed size for a given screen width — the pills
  narrow to 85 pt on a 320 pt layout so the whole dock stays on screen — and the
  media still never moves for chrome (ADR-0006). Five Codex rounds: four P2s
  found (a pair-anchor/doc mismatch, a saturated well fill, the clipped 320 pt
  dock, a stale "fixed size" claim), all fixed on the PR; round 5, of the merged
  head `5da18ea`, reported no findings. Full local suite green on
  `SWIPR iPhone 11 Pro`: 229 kit + 50 app + 72 UI = 351 tests, 0 failures; CI
  `checks` green (one run on that head failed with the known launch stall in #84
  before any assertion, and the re-run was green). Screenshots:
  `docs/screenshots/milestones/v1-04/` (12, re-captured: bottom/left/right/moving
  × light/dark/AX5).

- **#76 — V1-04b: Wire direct dock movement into the viewer** (PR #86, merge
  commit `2e56f87`). The legacy grip/puck/phantom-slot control is replaced by
  direct whole-dock movement: a drag may begin on any control or in any gap,
  roughly 9 pt of movement cancels the pending tap for good, the dock becomes a
  compact neutral token, three subtle markers drawn in the dock's own shape show
  the only destinations, a valid release lands and an invalid one restores the
  source. `dockMoved` outlives the gesture by one main-queue turn (what makes "a
  move never decides" true rather than likely), and a drop on the place the dock
  already occupies goes through `AppModel.moveDock(to:)`, which refuses a
  position that has not changed — writing the preferences re-pins the session's
  direction from the saved default. `DockGeometry.capture` now holds a captured
  destination until its release radius is left. Two Codex rounds: round 1 found
  exactly those two problems, both fixed in `9680607` with tests verified by
  breaking the fix; round 2, on that head, reported no findings. Full local
  suite green — 225 kit + 50 app + 71 UI = 346 tests, 0 failures on
  `SWIPR iPhone 11 Pro`; CI `checks` green. Screenshots:
  `docs/screenshots/milestones/v1-04/` (12: bottom/left/right/moving ×
  light/dark/AX5).

- **#83 — test: stabilise the flaky UI launch/terminate handoff (#81)** — the
  launch/terminate handoff helpers, the scoped UI queries and the rules in
  `docs/TESTING.md`; closes **#81**. Four consecutive CI runs and three
  consecutive local full suites green; the two stalls #81 recorded did not
  recur, and `needs-owner` #84 keeps that evidence.
- **#82 — docs: record full autonomy until V1 and delegated risky-PR approval**
  (merge commit `1d73a1b`).
- **#80 — feat: add pure direct-move dock geometry (#75)** (merge commit
  `01e57f6`).
- **#74/#72/#71/#70/#66** — see the ticket log in
  `docs/IMPLEMENTATION-STATUS.md`; #72 (AX5 re-enable, merge commit `8efd39e`)
  and #66 (damaged save file, merge commit `c2af5f5`) both merged after the
  owner's approval. #74 is still open (risky).
- **#67 — docs: record the risky-PR Codex review workflow and Code Review
  Rules** (merge commit `881aff7`).
- **#65 — ci: add the strong-review gate for risky paths** (merge commit
  `251b6a6`).
- **#61 — Implement #56: replace an unfinished session only after
  confirmation** (merge commit `286ec04`), which closed **#56**.
- **#60 — Implement #58: make the starting point reachable at the largest text
  size** (merge commit `25e6418`), which closed **#58**.
- **#59 — Implement #55: offer both named traversals and finish without
  wrapping** (merge commit `ddaba0f`), which closed **#55**.
- **#52 — Implement #46: wire Home and editable filters into a fixed session**
  (merge commit `907f12a`), which closed **#46**.

## Queue (owner-requested, 2026-10-05)

- **#68 — Ops: Sync docs/HANDOFF.md to the current state** — done (PR #71,
  merged as `67967ad`).
- **#69 — V1-08a: Re-enable the skipped AX5 large-text UI test** — done (PR #72,
  merged as `8efd39e`). The AX5 case runs on every PR.
- **#70 — V1-06a: Keep marked photos through Limited Photos access** — PR #74 is
  open and **`owner-blocked`**; issue **#85** holds the question. #70 stays
  open.
- **#73 — V1-03e: Keep the Tumbler order when a migrated plan's cursor has
  vanished** — not started.

## What is next

1. **#79** (VoiceOver placement actions, Reduce Motion/Transparency, contrast,
   real-device tuning) is the last V1-04 subticket. It inherits one open finding
   from #78: at the largest text size the Settings rows are taller than the
   screen and the pre-existing "Reset control position" title hyphenates mid-word
   (`docs/screenshots/milestones/v1-04/settings-undo-position-ax5.png`).
2. **#73** (the migrated Tumbler plan's vanished cursor) is still not started.
3. Keep `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.

### Note: the UI suite's launch handoff (#81)

Every `SWIPRUITests` launch, terminate and starting-point handoff goes through
`SWIPRUITests/AppLaunchHandoff.swift`. Add new UI tests through those helpers
rather than calling `app.launch()` directly. What they give you: the app is
stopped through the one `XCUIApplication` that launched it, a stop blocks until
the system reports the process gone, and a launch or a starting point returns
only once the screen it promises is on screen.

Every lookup names the collection the element lives in, too:
`app.buttons[…]`, `app.staticTexts[…]`, `app.images[…]`, `app.otherElements[…]`,
`app.switches[…]` rather than `app.descendants(matching: .any)[…]`, which fetched
the whole accessibility tree for every query. Two families are the deliberate
exception — the viewer canvas (`viewer.photo`) and the grid cells
(`choosePhoto.cell.<id>`), whose element kind follows whether their thumbnail has
rendered yet — and they are found by identifier. Dump `app.debugDescription` to
see what kind an identifier turns into before typing a new query.

The stalls #81 was opened for (a 68 s terminate wait; three 30 s snapshot
retries) did not recur after that: four consecutive CI runs and three consecutive
local full suites are green. Whether the runner is now clean or simply quieter is
not proved; `needs-owner` #84 keeps the evidence and the options.

### Note: the AX5 skip is gone (#69)

The CI job carried
`-skip-testing:SWIPRUITests/PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize`.
#58 fixed the scroll and **#69** removed the line in **PR #72** (risky because
it edits `.github/workflows/ci.yml`, so it waits for the owner's approval). The
AX5 case now runs on every PR.

### Note: the two named traversals never wrap

`SessionEngine` still turns around (`testFlipsDirectionAtEndOfLibrary`) when a
session is jumped into the middle of the pool; that engine fallback is outside
#55's file list. The two named starts begin at an end and walk one way, and
`isUnavailable` excludes every decided photo, so a `Newest first` or `Oldest
first` run visits its whole pool once and then finishes at the visible
completion overlay rather than revisiting the first photo.

### Note: how the viewer tests reach a video

`FakePhotoLibrary.demo()` appends three extra assets (photo, Live Photo, video)
when the launch argument `-uiTestingMixedMediaLibrary` is present. The argument
is only read while a fake library is already in use, so a real library run can
never see it, and the ordinary 24-item demo fixture every other test counts on is
left untouched.

### Note: appearance seam for the Home and filter screens

The app follows the iPhone's appearance by default. `RootView` reads two UI-test
launch arguments, `-uiTestingForceLight` / `-uiTestingForceDark`, which override
the `colorScheme` environment for the porcelain Home and filter screens. Every
other screen keeps its dark viewer chrome, so only Home and filters follow the
system. The milestone screenshots were captured through the seam. A later
appearance ticket adds the System / Light / Dark setting.

### Note: the replacement confirmation

The gate lives in `AppModel.requestSession`: when `hasUnfinishedSession` is
false the start runs immediately, otherwise the request is parked as a
`PendingReplacement` and the overlay explains that position and Undo history are
replaced while marked items stay in Review. `startFrom` still refuses a marked
item before any of this, so tapping a marked cell cannot become a replacement
request. The confirmation is a purpose-built card (not a system alert) so the
explanation and both actions stay legible in light and dark and at large text
sizes; the light/dark captures go through the existing `-uiTestingForceLight` /
`-uiTestingForceDark` seam.
