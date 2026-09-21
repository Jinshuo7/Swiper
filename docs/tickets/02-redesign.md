# Persist accepted decisions and surface recovery failures

## Parent

#10

## What to build

Make one sorting decision durable before advancing, with reliable resume and a visible recoverable failure path.

## Acceptance criteria

- [ ] Version and atomically migrate legacy saved state; distinguish absent, corrupt and future-version data without overwriting unreadable data.
- [ ] Stage decisions and serialize input; only acknowledge and advance after successful save. Failed writes pause sorting with Retry and retain a recoverable pending operation.
- [ ] Normal restart restores accepted position and current-session Undo. Short/cancelled drags create no decision.
- [ ] Test write failure/retry, restart, migration and effect-boundary recovery through app operations with fake library and controllable persistence; avoid duplicate favorite effects.
- [ ] Inspect overlap with existing issue #1 but do not blindly implement its old constraints or close it. Keep the existing deletion path functional during this slice.
- [ ] Include user-visible error handling and documentation, not just a storage-layer refactor.

## Blocked by

None (can start immediately).
