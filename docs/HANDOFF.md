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
  3 `@codex review` rounds (see `AGENTS.md` → *Risky PR review workflow*). Leave
  it open for the owner; never add `strong-review-passed` and never merge it
  unless the owner approves it by number.

## Current ticket

- **#81 — V1-12a: Stabilise the flaky UI app-termination test** —
  (`driver/81-flaky-ui`, PR #83, `owner-blocked`). The launch/terminate handoff
  is fixed in the test harness (`SWIPRUITests/AppLaunchHandoff.swift`), but the
  CI runner still loses its automation session with the app about one full run in
  three, in XCTest's own terminate and snapshot timeouts. That is the rate the
  issue recorded before the work and it does not reproduce locally, so it is
  parked for the owner with the evidence rather than retried or skipped. See
  `docs/TESTING.md` and the `needs-owner` issue filed for it.
- The next milestone after this is **V1-04 (#26, the neutral direct-move
  decision dock)**, split into subtickets #76–#79.

## Open PRs

- **#83 — test: stabilise the flaky UI launch/terminate handoff (#81)**
  (`driver/81-flaky-ui`, head `c6d8e7c`). Test-only plus docs, so it is not a
  risky path. Two consecutive CI runs were green (38m20s, 43m39s) and the third
  hit the residual XCTest snapshot timeout, so it is labelled `owner-blocked` and
  **not merged**. Decide whether to take it and how to handle the residual.
- **#74 — fix: keep marked photos through Limited Photos access (#70)**
  (`driver/70-limited-marks`, head `ff118ee`). Risky, `needs-strong-review`,
  open, **waiting for the owner**. Do not add `strong-review-passed` without the
  owner's approval.
- **#37 — Add deterministic ticket controller** (author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

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
  open and risky, waiting for the owner.
- **#73 — V1-03e: Keep the Tumbler order when a migrated plan's cursor has
  vanished** — not started.

## What is next

1. Decide **#81**: PR #83 is green on the harness fix, but the CI runner still
   stalls the automation session about one run in three; the `needs-owner` issue
   has the evidence and the options.
2. Implement **#73** (the migrated Tumbler plan's vanished cursor), then the
   **V1-04** subtickets #76–#79.
3. Keep `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.

### Note: the UI suite's launch handoff (#81)

Every `SWIPRUITests` launch, terminate and starting-point handoff goes through
`SWIPRUITests/AppLaunchHandoff.swift`. Add new UI tests through those helpers
rather than calling `app.launch()` directly. What they give you: the app is
stopped through the one `XCUIApplication` that launched it, a stop blocks until
the system reports the process gone, and a launch or a starting point returns
only once the screen it promises is on screen.

They do not remove the runner-level stall. The CI runner still loses its
automation session with the app about one full run in three, as XCTest's own
`Failed to terminate …:0` (a 68 s terminate wait) or `Failed to get matching
snapshots: Timed out while evaluating UI query` (three 30 s snapshot retries).
Those are the flakes #81 was opened for, and they did not reproduce in four full
local suites and ~800 launches/terminates on `SWIPR iPhone 11 Pro`.

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
