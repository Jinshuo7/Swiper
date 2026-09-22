# Entry screen, Start Here and Settings

## Parent

#17

## What to build

The front of the app becomes one obvious action, Start Here becomes the only door
into sorting, and Settings opens with what the user has achieved.

- Entry screen: settings gear leading, the SWIPR wordmark dead centre, and a
  deletion-review chip trailing that appears only when photos are marked. Body:
  the wordmark at Large Title size, one circular action `64` to `72 pt` across
  with a glyph inside and `Start here` beneath it in Body, and `Resume` as a
  secondary text button only while a session is waiting. No footer.
- With no photos: same layout, the circle disabled with a neutral fill, one line,
  "No photos to sort."
- Start Here: `Newest` and `Random` as a row of two between the explanation and
  the grid, starting the sessions the old Recent and Tumbler started. Opening the
  screen leaves a resumable session alone; choosing a photo replaces it.
- Settings: a `Show buttons` toggle (on by default, hiding the cluster and its
  grip) with swipe gestures always available and stated as such; the three
  position choices and a reset; an inline read-only statistics section at the very
  top with lifetime deleted, lifetime storage reclaimed, sessions completed, and a
  this-session row only while a session is active; Help and Default direction
  unchanged; `Tap to keep` and the preset list gone.
- Tutorial copy follows the new controls and the removal of favouriting, and
  teaches how to move the cluster.

## Acceptance criteria

- [ ] The entry screen presents at most two prominent actions in every state:
      none waiting, session waiting, marks waiting, and both.
- [ ] `Resume` appears only when a session is waiting, and the review chip only
      when photos are marked, each with its count stated.
- [ ] The wordmark is centred to within a point on a 375 pt wide phone, checked
      against the gear and the chip rather than assumed.
- [ ] Every number in the statistics section is read-only, and each matches the
      value the statistics store holds after a scripted run.
- [ ] `Newest` and `Random` start the same sessions the removed entries started,
      proven by the photo the viewer opens on.
- [ ] A resumable session survives opening Start Here and is replaced only by
      choosing a photo.
- [ ] The disabled empty state shows exactly one line of copy and no enabled
      action.
- [ ] Screenshots of the entry screen in all four states and of Settings are
      committed and inspected by eye, at default and largest text sizes.
- [ ] The full suite is green on the device.

## Blocked by

`10-redesign.md`.
