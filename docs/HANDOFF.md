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

- **Ticket:** [#57 — V1-03c: Keep Random deterministic, repeat-free and
  reconciled](https://github.com/Jinshuo7/Swiper/issues/57) — **implemented** on
  branch `driver/57-tumbler` by the worker. `TumblerPlan` gained `reserve(_:)`
  and `SessionEngine` now reserves the cursor whenever it is placed outside the
  plan's own `next()` (restore, reconciled recovery, direct jump), closing the
  one latent repeat path. The new kit tests prove a fixed seed and pool always
  produce the same order, the whole pool is walked without repeats (plain, after
  Undo, after a jump, and after reconciliation), a terminated-and-relaunched
  session resumes the exact saved order and position, and reconciliation drops
  vanished members while crediting no deletion and touching no photo. Kit maths
  is 186 tests with 0 failures; `SWIPRAppTests` is 42 tests with 0 failures. The
  CI AX5 `-skip-testing` line is untouched. **No PR opened yet** — the driver
  opens it after review.
- **Next up:** open the PRs for #58 and #57, wait for `checks`, merge, then run
  the remaining V1-03 sub-ticket (#56 replacement confirmation) through the same
  worker/reviewer flow.

### Note: the AX5 skip belongs to #32

The CI job still carries
`-skip-testing:SWIPRUITests/PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize`.
#58 does not touch it; removing that line is ticket #32's job now that the case
passes locally.

### Note: 58 is implemented but unmerged

[#58](https://github.com/Jinshuo7/Swiper/issues/58) is implemented on branch
`driver/58-ax5` (the AX5 `assertReachable` traversal now walks the starting
point top-down) but its PR is not open yet. It is unrelated to the Tumbler
work.

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

- None from this worker. #58's branch is ready for the driver to open a PR.
  (#55 was merged as PR #59, commit `ddaba0f`; #47 as PR #53, commit
  `10aa678`.)
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

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

1. Open the PR for #58, wait for `checks`, and merge if the diff only touches
   the ticket's files and every acceptance criterion is met.
2. Run the remaining #29 (V1-03) sub-tickets (#56, #57) through the
   worker/reviewer flow from the roadmap order in `PROJECT-BRIEF.md`; keep
   `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.
