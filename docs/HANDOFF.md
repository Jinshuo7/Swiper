# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Current ticket

- **Ticket:** [#44 — V1-02b: Filter a mixed-media pool with pure domain logic](https://github.com/Jinshuo7/Swiper/issues/44)
- **Branch:** `deepseek/44-media-filter` (fresh worktree at `SWIPR-ticket-44`)
- **State:** Codex approved (review 1 of 1). Local checks green — `git diff --check`,
  `Scripts/run-kit-tests.sh` (167 tests, 0 failures), `Scripts/typecheck-ios.sh` (`OK`).
- **PR:** [#49](https://github.com/Jinshuo7/Swiper/pull/49) — awaiting CI.

## Open PRs

- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#48 — Implement #43: expose mixed-media metadata through public APIs** (merged),
  which closed **#43**.
- **#42 — Setup #41: persist owner workflow and compact project brief**
  (merged as commit `4c775bd`), which added the Codex/DeepSeek guardrails and the ticket
  accounting log.

## What is next

1. Wait for CI on #49 (`gh pr checks 49 --watch --fail-fast`).
2. Merge only when safety rule 4 holds (green checks, diff touches only the ticket's files,
   every acceptance criterion met). Do not merge now.
3. Continue with the next ticket from `docs/ROADMAP.md`.
