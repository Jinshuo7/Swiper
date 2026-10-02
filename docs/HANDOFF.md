# Handoff

> Stopping and resuming state. On resume read this file, then
> `docs/agents/OWNER-INSTRUCTIONS.md` and `docs/agents/PROJECT-BRIEF.md`.

## Current ticket

- **Ticket:** [#45 — V1-02c: Persist and reconcile the fixed filtered session pool](https://github.com/Jinshuo7/Swiper/issues/45)
- **Branch:** `deepseek/45-fixed-pool-persistence` (fresh worktree at `SWIPR-ticket-45`)
- **State:** Implemented and Codex-approved (normal review + extra
  persistence-safety review, 2 Codex steps). Local checks green — `git diff --check`,
  `Scripts/run-kit-tests.sh` (179 tests, 0 failures), `Scripts/typecheck-ios.sh`
  (`OK`), focused `SWIPRAppTests/AppModelTests` on the simulator (33 tests,
  0 failures). Opening the PR now.
- **Risky:** saved sessions and migration — covered by the extra review and the
  fake-library tests proving saved progress survives migration/relaunch and
  nothing is deleted without explicit confirmation.

## Open PRs

- **#37 — Add deterministic ticket controller** (open, author Jinshuo7):
  **prohibited — do not use, merge, or base work on it** (owner rule 8:
  `Scripts/ticket_controller.py` and PR #37 are off-limits).

## Recently merged

- **#49 — Implement #44: filter a mixed-media pool with pure domain logic**
  (merged), which closed **#44**.
- **#48 — Implement #43: expose mixed-media metadata through public APIs** (merged),
  which closed **#43**.
- **#42 — Setup #41: persist owner workflow and compact project brief**
  (merged as commit `4c775bd`), which added the Codex/DeepSeek guardrails and the ticket
  accounting log.

## What is next

1. Open the PR for #45 to `main` (`Closes #45`), then wait for CI with
   `gh pr checks <PR> --watch --fail-fast`. Merge only when safety rule 4 holds.
2. Continue with the next ticket from `docs/ROADMAP.md`.
