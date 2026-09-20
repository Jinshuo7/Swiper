# Round 2 workflow log

Started: 2026-09-20 08:51 UTC

## Goal

Fix the three known correctness issues with bounded context, then compare quality,
time, token use, and coordination overhead with the earlier multi-agent pass.

## Provider accounting

- DeepSeek calls through the Jenspark LLM proxy consume credits.
- Luna and Sol calls through OpenAI Codex do not consume Jenspark credits; track their
  dollar usage from OpenAI's usage page.
- This run currently uses `gpt-5.6-sol` through OpenAI Codex at medium reasoning.
- DeepSeek/Jenspark calls: 0. Luna calls: 0. JEV calls: 0.

## Baseline

- Working tree clean.
- `Scripts/run-kit-tests.sh`: 66 tests, 0 failures, 6 seconds.
- `Scripts/typecheck-ios.sh`: green.

## Work

### T-1.1 — Tumbler undo

- Scope read: `TumblerPlan`, `SessionEngine`, and `SessionEngineTests`.
- Added the missing coverage assertion first; it failed on the current code.
- Fix: requeue the undone asset as well as the displaced asset.
- Verification: 66 tests, 0 failures; iOS typecheck green.
- Commit: `6913345`.

### T-1.3 — favorite write input policy

- Scope read: `AppModel` and `ViewerView`.
- Chosen policy: block controls and photo gestures while a favorite mutation is in flight.
- Verification: 66 tests, 0 failures; iOS typecheck green.
- Gap: no executable app-level regression test exists for this state yet.
- Commit: `f8e1743`.

### T-1.4 — deletion/library-change race

- Scope read: `AppModel`, the fake library, persistence, project test layout, and UI tests.
- Fix: fetch the refreshed order, then re-read the current engine after the final await
  before applying the deletion outcome, so an older snapshot cannot overwrite it.
- Verification: 66 tests, 0 failures; iOS typecheck green.
- Gap: the repository has no runnable app-model test path in the fallback test script;
  `xcodebuild` is blocked by first-launch/licence setup, so the required race regression
  test is still open.
- Commit: `2eb19e5`.

## Cost checkpoint

From the Pi session records since Round 2 began: 25 Sol calls, approximately $1.72,
41,910 uncached input tokens, 9,821 output tokens, 5,014 reasoning tokens, and
2,431,616 cached-input tokens. This includes reading orchestration skills and attempting
to discover `bb`, not just implementation. OpenAI's usage page is authoritative.

## Workflow observations

- `bb` is not installed or visible in this shell, so no isolated workers or independent
  reviewer could be launched from here.
- Reading the full `bb-cli` skill before discovering that the executable was absent was
  avoidable context cost. Future runs should check tool availability first when possible.
- The bounded product work itself required only the named implementation files and their
  direct tests/callers.
- JEV remains a proposed shadow router; no TypeSafe credential or local integration is
  visible in this environment.
