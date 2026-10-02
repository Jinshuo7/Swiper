# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Setup facts

- **CI runner:** `xcode-27` is a **self-hosted** runner (not a GitHub-hosted
  `macos-*` label). Branch protection on `main` requires the `checks` status,
  strict (up to date with `main`), with force-push and deletion blocked.
- **Driver mode:** the owner replaced Codex with this Pi driver session
  (deepseek-flash, effort high). See the Roles section of
  `docs/agents/OWNER-INSTRUCTIONS.md`.
- **Agent base repo:** `/Users/beastmini/GitHub/Jinshuo7/SWIPR-agent`; ticket
  worktrees live under `/Users/beastmini/GitHub/Jinshuo7/SWIPR-worktrees/`.
  Never touch the owner's folder `/Users/beastmini/GitHub/Jinshuo7/SWIPR`.

## Current ticket

- **Ticket:** none in progress. The V1-03 (#29) work is implemented up to two
  risky PRs that now await the owner's Codex review and must **not** be
  auto-merged:
  - **#56 — V1-03b: replace an unfinished session only after confirmation** —
    branch `driver/56-replace-session`, **PR #61**, labelled
    `needs-strong-review`; two independent reviewers both said ACCEPT.
  - **#57 — V1-03c: keep Random deterministic, repeat-free and reconciled** —
    branch `driver/57-tumbler`, **PR #62**, labelled `needs-strong-review`; two
    independent reviewers both said ACCEPT. One correction round fixed a
    reserved-cursor leak on `start()` and made the two-Undo and reconciliation
    tests reserve-sensitive, plus two doc test counts.
- **Next up:** after the owner merges #61 and #62, start V1-04 (#26, the neutral
  direct-move decision dock). #55 (PR #59) and #58 (PR #60) are already merged,
  so V1-03a (both named traversals) and V1-03d (AX5 starting point) are done.
- The V1-02 milestone report was posted as issue #54.

### Note: the AX5 skip belongs to #32

The CI job still carries
`-skip-testing:SWIPRUITests/PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize`.
#58 does not touch it; removing that line is ticket #32's job now that the case
passes locally.

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
this ticket's file list). `RootView` therefore reads two UI-test launch
arguments, `-uiTestingForceLight` / `-uiTestingForceDark`, which override the
`colorScheme` environment for the porcelain Home and filter screens only. The
light milestone screenshots were captured through that seam. A later appearance
ticket replaces it with the System / Light / Dark setting.

## Open PRs

- **#61** (#56) and **#62** (#57): open, `needs-strong-review`, awaiting the
  owner's Codex review; both have two ACCEPT reviews.
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#60 — Implement #58: make the starting point reachable at the largest text
  size** (merged as commit `25e6418`), which closed **#58**.
- **#59 — Implement #55: offer both named traversals and finish without
  wrapping** (merged as commit `ddaba0f`), which closed **#55**.
- **#52 — Implement #46: wire Home and editable filters into a fixed session**
  (merged as commit `907f12a`), which closed **#46**.
- **#51 — Driver bootstrap** (Roles section in `OWNER-INSTRUCTIONS.md` + this
  HANDOFF update) — merged as commit `4188fa3`.
- **#50 — Implement #45: persist and reconcile the fixed filtered session pool**
  (merged), which closed **#45**.
- **#49 — Implement #44: filter a mixed-media pool with pure domain logic**
  (merged), which closed **#44**.
- **#48 — Implement #43: expose mixed-media metadata through public APIs**
  (merged), which closed **#43**.
- **#42 — Setup #41: persist owner workflow and compact project brief**
  (merged as commit `4c775bd`), which added the guardrails and the ticket
  accounting log.

## What is next

1. Owner reviews and merges **PR #61** (#56) and **PR #62** (#57); both are
   `needs-strong-review`, so the driver left them open.
2. Start the next milestone, V1-04 (#26 — the neutral direct-move decision dock).
3. Keep `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.
