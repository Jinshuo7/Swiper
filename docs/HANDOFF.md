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

- **None in progress.** The V1-03 milestone is merged (PRs #59–#62) and the
  strong-review gate is in place (#65, docs #67). The next milestone is
  **V1-04 (#26, the neutral direct-move decision dock)**, unblocked (#25 is
  closed). Break it into subtickets before implementing.

## Open PRs

- **#66 — fix: keep a damaged save file instead of replacing it with empty
  progress** (`driver/damaged-save`, head `8d965fb`). Risky
  (`SWIPRKit/SessionPersistence.swift`), `needs-strong-review`, open, **waiting
  for the owner**. The owner gave conditional approval and asked for one final
  `@codex review` on `8f9f608`; that round found two more problems (a mark
  bypassed the Tumbler-mode consistency check, and blank IDs inside a Tumbler
  plan's `remaining`/`handled` were accepted), both fixed on `8d965fb`. No
  further review round was requested and no merge happened. **Do not add
  `strong-review-passed` without a fresh owner approval.**
- **#72 — test: re-enable the AX5 large-text UI case in CI (#69)**
  (`driver/69-ax5-reenable`). Risky because it edits
  `.github/workflows/ci.yml` (every workflow file is risky), so the owner must
  approve it; labelled `needs-strong-review`.
- **#37 — Add deterministic ticket controller** (author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#67 — docs: record the risky-PR Codex review workflow and Code Review
  Rules** (merge commit `881aff7`), which added the standing workflow to
  `AGENTS.md` and `docs/agents/OWNER-INSTRUCTIONS.md`.
- **#65 — ci: add the strong-review gate for risky paths** (merge commit
  `251b6a6`), which labels risky PRs `needs-strong-review` and fails until the
  owner adds `strong-review-passed`.
- **#64 — docs: correct the CI runner label and note the #50 review gap**
  (merge commit `46e593b`).
- **#61 — Implement #56: replace an unfinished session only after
  confirmation** (merge commit `286ec04`), which closed **#56**.
- **#60 — Implement #58: make the starting point reachable at the largest text
  size** (merge commit `25e6418`), which closed **#58**.
- **#59 — Implement #55: offer both named traversals and finish without
  wrapping** (merge commit `ddaba0f`), which closed **#55**.
- **#52 — Implement #46: wire Home and editable filters into a fixed session**
  (merge commit `907f12a`), which closed **#46**.

## Queue (owner-requested, created 2026-10-05)

- **#68 — Ops: Sync docs/HANDOFF.md to the current state** (`ready-for-agent`).
- **#69 — V1-08a: Re-enable the skipped AX5 large-text UI test**
  (`ready-for-agent`); removes the `-skip-testing` line in
  `.github/workflows/ci.yml`.
- **#70 — V1-06a: Keep marked photos through Limited Photos access**
  (`ready-for-agent`).

## What is next

1. Finish the owner's decisions on the risky PRs: **#66** (conditional
   approval round found problems, now fixed on `8d965fb`) and **#72** (AX5
   re-enable; needs approval because it edits a workflow).
2. Land **#68** (this handoff), then implement **#70** (Limited Photos marks).
3. Start the next milestone, **V1-04 (#26 — the neutral direct-move decision
   dock)**, split into subtickets.
4. Keep `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.

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
