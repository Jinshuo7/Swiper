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

- **Ticket:** [#55 — V1-03a: Offer both named traversals and complete without
  wrapping](https://github.com/Jinshuo7/Swiper/issues/55) — **implemented** on
  branch `driver/55-traversals` by the worker. The starting point now offers
  **Newest first** (`choosePhoto.newest`, walks older) and **Oldest first**
  (`choosePhoto.oldest`, walks newer) as start actions alongside the unchanged
  **Random** action, and tapping a grid item still starts at that item in the
  saved default direction. The grid's **Newest first / Oldest first** order
  toggle and **Jump to month** still work. `AppModel.startOldest()` pins the
  `.newer` direction, matching the pinned `.older` of `startNewest()`. The
  focused `SWIPRUITests` class is green (45 tests, 0 failures), including a new
  both-directions test and a full Oldest-first traversal that proves the
  session reaches the completion boundary without repeating a photo. **No PR
  opened yet** — the driver opens it after review.
- **Next up:** open the PR for #55, wait for `checks`, merge, then run the
  remaining V1-03 sub-tickets (#56 replacement confirmation, #57 Tumbler,
  #58 AX5 starting point) through the same worker/reviewer flow.

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

- None from this worker. #55's branch is ready for the driver to open a PR.
  (#47 was merged as PR #53, commit `10aa678`.)
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

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

1. Open the PR for #55, wait for `checks`, and merge if the diff only touches
   the ticket's files and every acceptance criterion is met.
2. Run the remaining #29 (V1-03) sub-tickets (#56, #57, #58) through the
   worker/reviewer flow from the roadmap order in `PROJECT-BRIEF.md`; keep
   `docs/IMPLEMENTATION-STATUS.md` and this file current after every ticket.
