# SWIPR: a narrower product with ergonomic controls

The design record behind this spec is `docs/research/entry-and-dock-design.md`
(Apple HIG and WWDC sources, with the places the evidence does not settle a
choice marked). Read it before changing motion values or control geometry.

## Problem Statement

The app is for getting rid of photos quickly. Three things get in the way of that.

The entry screen offers five stacked buttons and two lines explaining gestures, so
the one thing a person wants to do is buried in options and instructions.

The viewer's three controls live in a tray the user drags to dock along three
edges, and the drag is janky: it lifts late, the cluster jumps when it lands, and
moving it refits and shifts the photo, so the image is never where it was.
Favouriting is a fourth action that costs the three real actions attention and
space, and it belongs to a different intent: reviewing photos, not clearing them.

Statistics, the only record of what the user has actually cleared, are behind a
row with a chevron.

## Solution

- The product is **SWIPR**, on the phone and in the project.
- A **decision** is keep or mark for deletion. Favourite leaves the product.
- The **entry screen** is a wordmark, one circular `Start here` action, `Resume`
  only while a session is waiting, and a deletion-review chip in the top bar.
- **Choose a photo** absorbs the old Recent and Tumbler entries as `Newest` and
  `Random`, so it is the single door into sorting.
- The viewer's controls sit at **three fixed positions**, moved by a three-dot
  grip that detaches into a puck. The photo never moves for chrome.
- **Swipe gestures are always available**; the button cluster is an option.
- **Settings** opens with a read-only statistics section, and Help and Default
  direction are unchanged.

## User Stories

1. As the owner, I open the app and one action is obvious, so I start sorting
   without reading anything.
2. As the owner, I can resume the session I was in the middle of, and I can see
   at a glance that there are photos waiting in deletion review.
3. As the owner, when I want the newest photos or a random order, I find both
   inside Choose a photo rather than on the front page.
4. As the owner, I move the controls to the hand I am using, and the photo does
   not move or resize while I do it.
5. As the owner, I put the controls where I am about to reach, and the app
   remembers it.
6. As the owner, I swipe when I feel like swiping and press a button when I do
   not, and neither one disables the other.
7. As the owner, I open Settings and immediately see what I have cleared so far.
8. As the owner, I never lose a mark to a display toggle or an accidental drag.

## Implementation Decisions

### 1. Rename to SWIPR

- Framework module `SWIPRKit` becomes `SWIPRKit`, and every `import` follows.
- Source directories, targets, scheme and product names become `SWIPR`,
  `SWIPRKit`, `SWIPRAppTests`, `SWIPRKitTests`, `SWIPRUITests`.
- Bundle identifiers change, including the app's:
  `com.zhangjinshuo.swipr`. The phone therefore starts empty: marks, session,
  statistics and preferences live in the app container keyed by bundle id. The
  old install stays until it is deleted by hand.
- `Scripts/generate_project.rb` is the source of truth for all of this, and the
  project is regenerated from it.
- Docs prose says SWIPR. The git and GitHub repository names stay as they are,
  because the checkout path is referenced by tooling.

### 2. Favourite leaves the product

- `SessionAction.favorite`, `SessionEffect.setFavorite`, the favourite undo entry,
  `PhotoLibraryProviding.setFavorite`, the fake's favourite faults and write log,
  and `PhotoKitLibrary.setFavorite` all go.
- A decision therefore has no library effect. `AppModel` keeps its save-then-
  acknowledge path and its failure and retry handling; the effect-performing path
  it had for favouriting goes.
- Persisted sessions can contain favourite undo entries, so `PersistedState`
  schema version becomes 3, with a migration that drops those entries and keeps
  the asset recorded as kept. A v2 payload with a favourite entry must still load.
- Statistics never counted favourites and do not change.

### 3. Three fixed control positions

- Positions are safe-area relative: a row centred on the screen width sitting
  `20 pt` above the bottom safe-area edge; and columns centred at `75%` of the
  safe-area height, `20 pt` inside the left or right edge.
- Nothing between the positions. The old continuous position, the rail, anchor
  and order settings all go.
- The tray is `286 x 88 pt` for a row at the current control size: the three
  buttons, the grip's `44 pt` slot and the tray's padding. A `375 pt` wide phone
  leaves about `45 pt` clear at each bottom corner. (The earlier `228 pt` figure
  predated putting the grip inside the tray and could not hold it.)
- The photo is fitted to the full safe area and is never resized or shifted by
  the controls. This reverses the earlier lane behaviour, recorded in an ADR.

### 4. Moving the cluster

- A three-dot grip sits in the tray's end opposite Undo, in a `44 x 44 pt` hit region,
  with the accessibility label "Move controls".
- Dragging the grip lifts a translucent puck (a small circle holding the three
  dots) that tracks the finger one-to-one. The cluster itself does not move.
- The three positions appear as phantom slots as soon as the drag passes about
  three points. One slot is highlighted at a time, nearest to the puck, and the
  highlight is carried by border weight and brightness, not colour alone.
- Releasing in a slot moves the cluster there and hides the phantoms. Releasing
  anywhere else changes nothing and the puck returns.
- Haptics: one impact when the grip is picked up, one when the highlighted slot
  changes, and one rigid impact on landing. Nothing on every movement.
- A drag on the grip is never a decision, and a decision is never a move.

### 5. Motion

- The tracked offset is never animated: the puck is exactly under the finger.
- Only the landing animates, as a spring that carries the release velocity:
  `spring(duration:bounce:)` with bounce at or below `0.2`, and bounce `0` for
  the frequent slot-crossing highlight.
- Movement is an offset, never a layout change, so nothing on screen reflows
  during a drag.
- Reduce Motion tightens the springs and follows the gesture directly.

### 6. Entry screen

- Top bar: settings gear leading, the SWIPR wordmark dead centre, deletion-review
  chip trailing, present only when photos are marked.
- Body: the wordmark at Large Title size (`44 pt` with `52 pt` leading), one
  circular action `64` to `72 pt` across with a glyph inside, and the label
  `Start here` beneath it in Body (`17 pt`).
- `Resume` is a secondary text button shown only while a session is waiting. Two
  prominent actions is the maximum.
- No explanatory footer. The tutorial teaches the gestures.
- With no photos: the same layout, the circle disabled with a neutral fill, and
  one line, "No photos to sort."
- Text contrast is at least `4.5:1` against the background.

### 7. Choose a photo

- Gains `Newest` and `Random` as a row of two buttons between the explanation and
  the grid. `Newest` starts the session the old Recent did; `Random` is the
  Tumbler. The month sections, the jump menu and the order toggle are unchanged.
- Opening Choose a photo leaves a resumable session alone. Choosing a photo replaces
  it. The deletion list is never at risk.

### 8. Settings

- `Controls`: a `Swipe gestures` note, a `Show buttons` toggle (on by default,
  hiding the cluster and its grip), the three position choices, and `Reset
  control position`.
- Statistics: an inline, read-only section at the very top, no chevron, showing
  lifetime photos deleted, lifetime storage reclaimed, sessions completed, and a
  this-session row only while a session is active.
- `Help` and `Default direction` are unchanged. `Tap to keep` and the preset list
  are gone.

## Testing Decisions

- `SWIPRKitTests`: the favourite removal, the v2 to v3 migration dropping
  favourite undo entries, and the preference shape for fixed positions.
- `SWIPRAppTests`: the save-failure and retry paths after the effect path is
  removed.
- `SWIPRUITests`: the three positions and their geometry; a drag of the grip to a
  slot landing there; a cancelled drag changing nothing; a move never deciding; the
  photo's frame identical across all three positions; the entry screen showing at
  most two prominent actions and the disabled empty state; Settings with no
  Tap to keep and the statistics present; the largest-text-size invariants.
- Screenshots of the new entry screen and all three docks are committed and
  inspected by eye.
- The existing play suite keeps its coverage; the rail matrix is replaced by a
  three-position matrix.

## Out of Scope

- Favouriting anywhere, including as a hidden gesture.
- Ordinary videos (`docs/adr/0003-exclude-ordinary-videos-in-v1.md`).
- Free placement of the controls, and the rail, anchor and order settings.
- Renaming the git or GitHub repository.
- Localisation; the inventory in `docs/LOCALIZATION.md` still applies.
- Real Live Photo playback, which needs a device with a real Live Photo.

## Further Notes

- Five ADRs come out of this: the photo never moves for chrome; three fixed
  positions with the puck move; Choose a photo owns every entry; swipe is always
  available and buttons are optional; favourite is out of scope.
- The previous round's research on the movable bar,
  `docs/research/movable-controls.md`, is superseded for placement decisions by
  `docs/research/entry-and-dock-design.md` and stays as history.
- `CONTEXT.md` at the time of writing still defines *Control preset* as "Swipe,
  Thumb, Delete only, Extended" and *Control placement* as "left, center or
  right"; both are already stale and are corrected by the first ticket.
