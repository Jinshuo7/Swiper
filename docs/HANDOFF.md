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

- **Ticket:** [#46 — V1-02d: Wire Home and editable filters into a fixed
  session](https://github.com/Jinshuo7/Swiper/issues/46) — **implemented** on
  branch `driver/46-home-filters` by the worker. All mandatory checks are green
  (276 tests, 0 failures on the iPhone 17 / iOS 27.0 simulator with the existing
  AX5 skip), and the six milestone screenshots are committed. **No PR opened
  yet** — the driver opens it after review.
- **Next up:** open the PR for #46, wait for `checks`, merge, then run the next
  roadmap ticket (#29 V1-03) through the same worker/reviewer flow.

### Note: appearance seam for the Home and filter screens

The app is still pinned to dark in `SWIPRApp.swift` (a viewer-era choice outside
this ticket's file list). `RootView` therefore reads two UI-test launch
arguments, `-uiTestingForceLight` / `-uiTestingForceDark`, which override the
`colorScheme` environment for the porcelain Home and filter screens only. The
light milestone screenshots were captured through that seam. A later appearance
ticket replaces it with the System / Light / Dark setting.

## Open PRs

- None from this worker. #46's branch is ready for the driver to open a PR.
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

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

1. Open the PR for #46, wait for `checks`, and merge if the diff only touches
   the ticket's files and every acceptance criterion is met.
2. Run ticket #29 (V1-03) through the worker/reviewer flow from the roadmap
   order in `PROJECT-BRIEF.md`; keep `docs/IMPLEMENTATION-STATUS.md` and this
   file current after every ticket.
