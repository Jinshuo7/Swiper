# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Current ticket

- **Ticket:** [#41 — Setup: persist owner workflow and compact project brief](https://github.com/Jinshuo7/Swiper/issues/41)
- **Branch:** `deepseek/41-owner-brief` (fresh worktree at `SWIPR-ticket-41`)
- **PR:** [#42](https://github.com/Jinshuo7/Swiper/pull/42)
- **State:** awaiting CI.

## Open PRs

- **#42 — Setup #41: persist owner workflow and compact project brief** (this
  ticket, awaiting CI).
- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

Merged for context only: **#40 — Add DeepSeek workflow guardrails and GitHub
Actions** (merged 2026-10-02), which added the Codex/DeepSeek guardrails and the
ticket accounting log.

## What is next

1. Wait for CI on #42 (`gh pr checks 42 --watch --fail-fast`).
2. After merge, continue with the next ticket from `docs/ROADMAP.md`.
