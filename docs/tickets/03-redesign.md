# Preserve marked photos across sorting sessions

## Parent

#10

## What to build

Allow switching Recent, Start Here and Tumbler without losing photos marked for deletion.

## Acceptance criteria

- [ ] One durable ordered deletion list survives session replacement and migration; marked assets are skipped by all sorting entry points.
- [ ] New sessions reset traversal and session Undo only; reopening the same session retains Undo.
- [ ] Home exposes Continue sorting and Review & delete · N, with marked-not-deleted wording.
- [ ] Restore keeps an item for the current session and permits it in future sessions; stale Undo cannot unexpectedly reapply marks.
- [ ] Reconcile external removals without attributing deletions to Swiper. Test cross-session marks, restart, restore and Undo interactions end to end.
- [ ] Update glossary and behavior docs and add the cross-session deletion lifetime ADR.

## Blocked by

- #12
