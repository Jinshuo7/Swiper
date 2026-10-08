# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Setup facts

- **CI runner:** `xcode-27` is a **GitHub-hosted** runner using a custom
  `xcode-27` label (jobs run in the "GitHub Actions" runner group;
  `gh api repos/Jinshuo7/Swiper/actions/runners` returns `total_count 0`).
  Branch protection on `main` requires the `checks` status, strict (up to date
  with `main`), with force-push and deletion blocked.
- **Driver mode:** the owner replaced Codex with this Pi driver session
  (deepseek-flash, effort high). See the Roles section of
  `docs/agents/OWNER-INSTRUCTIONS.md`.
- **Agent base repo:** `/Users/beastmini/GitHub/Jinshuo7/SWIPR-agent`; ticket
  worktrees live under `/Users/beastmini/GitHub/Jinshuo7/SWIPR-worktrees/`.
  Never touch the owner's folder `/Users/beastmini/GitHub/Jinshuo7/SWIPR`.
- **Risky-PR review workflow:** any PR labelled `needs-strong-review` gets up to
  5 `@codex review` rounds (see `AGENTS.md` → *Risky PR review workflow*). The
  owner has **delegated** approval: add `strong-review-passed` and merge ("Create
  a merge commit", `--match-head-commit <full SHA>`) only when the checks are
  green on that head, a Codex review of that exact head reports no P1, and
  nothing (test, workflow, `risky-paths.txt`, gate) was removed, skipped,
  weakened or loosened. Never merge with an open P1, and never remove
  `needs-strong-review`.

## Current ticket

- **#76 — V1-04b: Wire direct dock movement into the viewer** (branch
  `driver/76-direct-dock`, PR #86). The legacy grip/puck/phantom-slot control is
  replaced by direct whole-dock movement: a drag may begin on any control or in
  any gap, roughly 9 pt cancels the pending tap for good, the dock becomes a
  compact neutral token, three subtle markers (the dock's own shape) show the
  only destinations, a valid release lands and an invalid one restores the
  source. `dockMoved` outlives the gesture by one main-queue turn, which is what
  makes "a move never decides" true rather than likely. Destination markers and
  the token are neutral (no saturated colour); the labelled/icon chrome and the
  side-layout wording are #77's, and the persisted preferences are #78's.
  Milestone screenshots: `docs/screenshots/milestones/v1-04/` (12: bottom/left/
  right/moving × light/dark/AX5). Full local suite green — 224 kit + 49 app + 71
  UI = 344 tests, 0 failures on `SWIPR iPhone 11 Pro`.
- The next V1-04 subtickets are **#77** (neutral dock chrome and side layouts,
  blocked by #76), **#78** (persist the four control preferences) and **#79**.
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

1. **#77** (neutral dock chrome and side layouts — labelled Delete/Keep pair at
   the bottom, icon controls with a non-action gap at the sides) is now
   unblocked by #76; then **#78** (persist Control Position, Show Buttons,
   Haptics, Undo Position) and **#79**.
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

The app is still pinned to dark in `SWIPRApp.swift` (a viewer-era choice outside
the V1-03 file list). `RootView` therefore reads two UI-test launch arguments,
`-uiTestingForceLight` / `-uiTestingForceDark`, which override the `colorScheme`
environment for the porcelain Home and filter screens only. The light milestone
screenshots were captured through that seam. A later appearance ticket replaces
it with the System / Light / Dark setting.

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
