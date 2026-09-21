# Complete review, deletion recovery and return-to-sorting flow

## Parent

#10

## What to build

Review or delete a batch at any time and return to the same sorting position safely.

## Acceptance criteria

- [ ] Viewer Review · N and home Review & delete · N reach the same durable marks. Close saves and returns home without discarding decisions.
- [ ] Review preserves inspection and single/batch restore; only explicit confirmation requests system deletion.
- [ ] Cancellation preserves marks; confirmed-deleted assets leave the list, unsuccessful assets remain; statistics never double-count after retry/restart.
- [ ] Handle interruption between PhotoKit effects and local persistence explicitly with reconciliation/recovery; no false success on failed saving.
- [ ] Review Back/result continuation returns to current sorting position, completion if exhausted, or home if no active session.
- [ ] Fake-library integration/UI checks demonstrate cancellation, partial failure, retry, restore and return navigation. Update user-facing docs.

## Blocked by

- #11
- #13
