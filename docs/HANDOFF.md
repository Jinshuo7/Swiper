# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Current ticket

- **Ticket:** [#43 — V1-02a: Expose mixed-media metadata through public APIs](https://github.com/Jinshuo7/Swiper/issues/43)
- **Branch:** `deepseek/43-media-metadata` (fresh worktree at `SWIPR-ticket-43`)
- **State:** Codex approved (review 2 of 2). Local checks green — `git diff --check`,
  `Scripts/run-kit-tests.sh` (148 tests, 0 failures), `Scripts/typecheck-ios.sh` (`OK`).
- **PR:** [#48](https://github.com/Jinshuo7/Swiper/pull/48) — awaiting CI.

## Open PRs

- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

Merged for context only: **#42 — Setup #41: persist owner workflow and compact project brief**
(merged as commit `4c775bd`), which added the Codex/DeepSeek guardrails and the ticket
accounting log.

## What is next

1. Wait for CI on #48 (`gh pr checks 48 --watch --fail-fast`).
2. Merge only when safety rule 4 holds (green checks, diff touches only the ticket's files,
   every acceptance criterion met). Do not merge now.
3. Continue with the next ticket from `docs/ROADMAP.md`.
