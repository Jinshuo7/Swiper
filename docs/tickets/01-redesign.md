# Bound the viewer and show complete photos

## Parent

#10

## What to build

Make the current viewer usable on the phone without waiting for the persistence redesign.

## Acceptance criteria

- [ ] Still and Live Photos are centered, fully visible at original aspect ratio against black; thumbnails remain appropriate for grids.
- [ ] Favorite, Undo, Close and all overlays stay inside viewport/safe-area bounds. Remove the unreadable permanent hint.
- [ ] Correctly proportioned fake assets with edge markers cover portrait, landscape, square and panorama; regression assertions catch cropping and offscreen controls.
- [ ] Preserve Live Photo playback, prefetch and cancellation. Inspect on-device screenshots if unlocked, otherwise record the validation blocker.
- [ ] Include focused tests and relevant behavior documentation updates.

## Blocked by

None (can start immediately).
