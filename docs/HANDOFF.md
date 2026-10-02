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

- **Ticket:** none in progress. Driver bootstrap PR (Roles section) is open.
- **Next up:** [#46 — V1-02d: Wire Home and editable filters into a fixed
  session](https://github.com/Jinshuo7/Swiper/issues/46). A half-done branch
  `deepseek/46-home-filters` exists with **no commits** beyond `main`; do not
  reuse it — start a fresh worktree/branch.

## Open PRs

- Driver bootstrap PR (Roles section in `OWNER-INSTRUCTIONS.md` + this
  HANDOFF update) — awaiting CI, merge when `checks` is green.
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

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

1. Merge the driver bootstrap PR once `checks` is green.
2. Run ticket #46 through the worker/reviewer flow from the roadmap order in
   `PROJECT-BRIEF.md`; keep `docs/IMPLEMENTATION-STATUS.md` and this file
   current after every ticket.
