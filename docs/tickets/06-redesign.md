# Verify and deliver interruption-safe photo cleaning

## Parent

#10

## What to build

Deliver a coherent, verified app rather than a collection of independently passing changes.

## Acceptance criteria

- [ ] Run full framework/app/UI suites as available, fixing integration regressions across both old and new flows.
- [ ] Exercise the full journey from migrated session through sorting, interrupted save/retry, mode switch, review/restore, cancelled/partial deletion and continuation.
- [ ] Inspect final fake-library screenshots and accessibility behavior; explicitly distinguish real Live Photo manual checks from fake-library automated coverage.
- [ ] If phone is locked, finish all safe local checks and record UI validation blocked rather than declaring this acceptance complete. Never bypass security or redownload simulators.
- [ ] Ensure SPEC, VISION, ROADMAP, TESTING, glossary and ADRs match shipped behavior. Check no debug instrumentation or contradictory draft instructions remain.
- [ ] Leave intentional local commits and a checkpoint with commands, results, screenshots and remaining risks. Do not push, publish the app, or close the parent/old backlog issues.

## Blocked by

- #13
- #14
- #15
