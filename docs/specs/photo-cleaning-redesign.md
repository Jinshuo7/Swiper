# Swiper: durable, intuitive photo cleaning

## Problem Statement

The phone viewer expands beyond the viewport, crops photos and puts controls offscreen. Low-contrast instructions are unreadable. People cannot readily tell that swiping only marks a photo, find deletion review during sorting, or trust that interruptions and new sessions preserve their choices. Persistence currently hides failures.

## Solution

Show complete photos against black in a correctly bounded viewer. Teach sorting once, then use minimal predictive swipe feedback and accessible button alternatives. Preserve one deletion list across sessions, acknowledge decisions only after saving, and make review reachable from home and the viewer. Never delete while swiping.

## User Stories

1. As a user, I want to see the complete photo without cropping, so I can judge it accurately.
2. As a user, I want controls within the phone screen, so I can reach Favorite and Undo.
3. As a user, I want Live Photos to retain playback, so fitting the image does not remove motion.
4. As a user, I want a first-photo tutorial, so I understand left, right, and final confirmation.
5. As a user, I want to replay help from Settings, so I can relearn without permanent overlays.
6. As a user, I want the photo to follow my drag, so the interaction feels direct.
7. As a user, I want clear left/right outcome feedback, so I can predict my decision.
8. As a user, I want short or interrupted drags to do nothing, so hesitation is safe.
9. As a user, I want button alternatives, so I need not perform swipe gestures.
10. As a user, I want every acknowledged decision saved, so closing or interruption does not erase accepted work.
11. As a user, I want a visible save failure and Retry, so I never mistake unsaved work for saved work.
12. As a returning user, I want my current position and Undo restored, so I can continue sorting.
13. As a user, I want marked photos preserved across new sessions, so changing modes does not discard deletion choices.
14. As a user, I want marked photos skipped while sorting, so I do not repeatedly decide them.
15. As a user, I want existing saved data migrated safely, so an app update does not erase my work.
16. As a user, I want Review accessible before reaching the end, so I can delete a small batch.
17. As a user, I want to restore marked photos individually or in batches, so marking remains reversible.
18. As a user, I want Close to save and return home, so leaving is predictable and non-destructive.
19. As a user, I want cancelled deletion to preserve marks, so I can reconsider later.
20. As a user, I want unsuccessful deletions left marked, so failures are not hidden.
21. As a user, I want to return to my sorting position after review/results, so cleanup does not reset my place.
22. As a user, I want only confirmed deletions counted, so reported results remain honest.
23. As a user, I want externally removed photos reconciled, so missing assets do not block sorting or inflate statistics.
24. As a user with accessibility needs, I want legible controls, meaningful labels and reduced motion, so the flow remains usable.

## Implementation Decisions

- Retain a Foundation-only decision engine and public PhotoKit adapter. Prefer existing seams; do not mandate the unrelated three-controller refactor in the old backlog.
- Bound the photo canvas and overlays to the viewport. Contain still images and Live Photos at original aspect ratio, centered against black; thumbnails may retain fill behavior. Preserve playback, prefetch and cancellation.
- Use gesture-first defaults and existing button presets. Reveal feedback-only lower-corner wells during horizontal drag: trash left, check right. Restrained native gradients/materials, crisp symbols and readable brief labels; no color-only meaning. No separate drop targets.
- Indicate the commit threshold visually and with a light haptic on crossing, not every update. Release below threshold, vertical gestures and cancellation make no decision. Respect Reduce Motion and iOS 17 compatibility.
- Maintain one ordered deletion list independent of sorting-session lifetime. New sessions reset traversal and Undo, never marks. Skip marked assets. Undo belongs to the current session and survives relaunch.
- Restore removes the mark and keeps the photo for the current session; future sessions may show it. Invalidate conflicting Undo history so stale entries cannot unexpectedly reapply restored marks.
- Stage a pure decision, save it successfully, then acknowledge/advance. Serialize input during saving. On error retain a recoverable pending decision, pause input and offer Retry without duplicate effects.
- Version persisted state and migrate legacy sessions atomically. Preserve previous data until success. Distinguish absent, corrupt and future-version data; never overwrite unreadable state as an empty session. Keep dependent state coherent rather than independently committing pieces.
- Local persistence and PhotoKit are not one transaction. Reconcile favorites/deletions interrupted at effect boundaries; retries must not duplicate effects or statistics. Do not promise immunity to hardware loss or app removal.
- Use user wording “N photos marked for deletion” and “Nothing deleted yet.” Home exposes Continue sorting and Review & delete · N; viewer exposes compact Review · N when marks exist.
- Close saves and returns home without a discard popup. New sorting sessions preserve marks without warning.
- Review preserves inspection and single/batch restore. Only explicit review confirmation invokes deletion and the system confirmation. Cancellation preserves marks; unsuccessful items remain; only confirmed deletions count.
- Back from review and continuation from results return to the active sorting position or completion if exhausted. With no active sorting session, return home.
- First-photo tutorial explains marking, keeping, confirmation, and automatic saving; replay via Settings → How to use. Adapt instruction to selected preset and isolate tutorial state in automated tests.

## Testing Decisions

- Test observable outcomes, not internal class structure. Primary integration seam: AppModel operations against fake photo-library and controllable persistence implementations. This reaches decision, effect, persistence and routing behavior without a real library.
- Reuse existing framework engine/persistence/reconciliation tests for focused state invariants and temporary-directory migration checks. Add app integration tests where framework-only tests cannot cover side effects or navigation.
- Reuse the device UI-test entry point with the fake-library launch flag. Improve fixtures to represent portrait, landscape, square and panorama images, with visible edge markers. Never automate against real photos.
- Cover migration, failed write/retry, restart, input serialization, cross-session marks, Undo, restore, external changes, cancelled/partial deletion, result continuation and effect-boundary recovery.
- Verify actual canvas/control frames and full-image visibility. Prior evidence: a 375 × 812-point viewport contained an 812 × 812 photo, with Favorite and Undo outside the screen. Existing red tests are preliminary; refine rather than blindly enforcing provisional labels.
- Inspect screenshots of tutorial, viewer, partial left/right drags, review and Settings, including bright/dark imagery and accessibility settings. Passing smoke tests alone does not establish visual correctness.
- Physical-device UI validation requires an unlocked phone. If unavailable, complete local tests/typechecking/builds and explicitly report device checks blocked; no simulator installation or security bypass.

## Out of Scope

Immediate swipe deletion; multiple saved sorting sessions; custom zoom; ordinary video support; new dependencies or private APIs; unrelated architectural rewrites; disabling phone security; simulator reinstallation; remote push or release without authorization.

## Further Notes

The user delegated remaining ordinary design choices and approved these testing defaults; do not reopen the product interview. Existing never-delete-while-swiping policy remains. Cross-session deletion-list lifetime needs a new ADR. Old persistence-versioning and documentation issues overlap this work but are not extra tasks or mandatory blockers; inspect current code, reconcile the overlap, and do not close or modify old issues or the parent spec automatically. All implementation slices must include their own tests and relevant documentation updates.
