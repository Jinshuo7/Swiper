# Fixed control positions and the puck move

## Parent

#17

## What to build

Replace the free-docking tray with three fixed positions, moved deliberately, and
stop the controls from disturbing the photo.

- Positions, safe-area relative: a row centred on the screen width `20 pt` above
  the bottom safe edge; columns centred at `75%` of the safe-area height `20 pt`
  inside the left and right edges. Nothing between them.
- A three-dot grip in the tray's leading end, in a `44 x 44 pt` hit region,
  labelled "Move controls".
- Dragging the grip lifts a translucent puck (a small circle holding the three
  dots) that tracks the finger one-to-one. The cluster stays where it is.
- Phantom slots for the three positions appear once the drag passes about three
  points; the nearest is highlighted one at a time by border weight and
  brightness. Releasing in a slot moves the cluster there; releasing elsewhere
  changes nothing.
- Haptics on pickup, on slot change, and on landing only.
- The photo's fitted frame is identical at all three positions and never changes
  during or after a move.
- The rail, anchor and continuous position preferences go, replaced by the
  three-way position.

## Acceptance criteria

- [ ] Each of the three positions matches the spec's geometry on a 375 pt wide
      phone, verified by assertion rather than by eye.
- [ ] The cluster's frame is identical between photos of every fixture aspect
      ratio, and identical when a mark appears.
- [ ] The photo's frame is byte-identical across all three positions, and does not
      change at any point during a move.
- [ ] A drag of the grip to each slot lands there; a drag released away from every
      slot changes nothing; neither decides a photo, with the photo's identity and
      the mark count asserted unchanged.
- [ ] The tracked offset carries no animation, and the landing spring uses
      `spring(duration:bounce:)` with bounce at or below `0.2`.
- [ ] Reduce Motion follows the gesture directly and tightens the landing.
- [ ] Settings offers the three positions and a reset; the removed settings no
      longer appear.
- [ ] Screenshots of all three positions are committed and inspected by eye.
- [ ] The suite is green on the device, and the rail matrix in the play suite is
      replaced by a three-position matrix.

## Blocked by

`09-redesign.md`.
