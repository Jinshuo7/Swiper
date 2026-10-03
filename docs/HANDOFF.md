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

- **Ticket:** [#56 — V1-03b: Replace an unfinished session only after
  confirmation](https://github.com/Jinshuo7/Swiper/issues/56) — **implemented**
  on branch `driver/56-replace-session`. A start while an unfinished session
  exists (Newest, Oldest, Random, or a specific item) no longer replaces it
  silently: `AppModel` parks a `PendingReplacement`, `ChoosePhotoView` shows the
  `ReplacementConfirmationView` card, and only **Start new** discards the
  position and session Undo. **Keep current** clears the request without writing
  anything, and the durable deletion list is only ever read, never cleared, so
  marked items stay marked and skipped. The gate is `resumableSession != nil`,
  matching the Home **Continue sorting** offer; a first start still happens with
  no confirmation. The full simulator suite is green (179 kit + 46 app + 64 UI,
  0 failures) with the existing AX5 skip in place, and
  `docs/screenshots/milestones/v1-03-starting-point/replace-session-light.png` /
  `replace-session-dark.png` show the confirmation in both appearances.
  **PR #61 is open**, labelled `needs-strong-review`, with two independent
  reviewers both ACCEPT; it is not auto-merged and awaits the owner's review.
- **The other V1-03 risky PR:** [#57 — V1-03c: keep Random deterministic,
  repeat-free and reconciled](https://github.com/Jinshuo7/Swiper/issues/57) —
  branch `driver/57-tumbler`, **PR #62**, labelled `needs-strong-review`, two
  independent reviewers both ACCEPT (one correction round fixed a reserved-cursor
  leak on `start()` and made the two-Undo and reconciliation tests
  reserve-sensitive, plus two doc test counts).
- **Next up:** the owner reviews and merges PR #61 and PR #62, then V1-04 (#26,
  the neutral direct-move decision dock) starts. #55 (PR #59) and #58 (PR #60)
  are already merged, so V1-03a (both named traversals) and V1-03d (AX5 starting
  point) are done. The V1-02 milestone report was posted as issue #54.

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
  owner's Codex review; both have two ACCEPT reviews. #56's branch was merged up
  to the latest `main` (docs-only conflict).
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#60 — Implement #58: make the starting point reachable at the largest text
  size** ("Fix AX5 starting-point reachability", merged as commit `25e6418`),
  which closed **#58**.
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
