# Cleanup redesign decision draft

Status: design interview in progress. Records agreed future behavior, not the
current implementation. No implementation or tracker publication yet.

## Visual direction

Photo Atelier composition: photographic Everything card above Photos and Videos
cards, list-style category filters. Orange & Porcelain palette: light background
`#F8F8F6`, surface `#FFFFFF`, accent `#C05A20`, ink `#272724`; dark background
`#191A18`, surface `#2C2D29`, accent `#F2A66B`. Colors are provisional until
contrast and device verification. Support light/dark and multilingual layouts.

## Agreed flow

Home → filter pool → choose a starting item → sorting → review → explicit deletion
confirmation. Home selections provide editable defaults, not restrictions.

Home exposes Settings, Everything, Photos and Videos. Continue sorting resumes
the saved session and Undo history. Review marked items is a separate secondary
action into the persistent deletion list, which can span multiple sessions.

## Interview round 1 — approved

- Starting-point screen: Order menu offers Newest first and Oldest first. A
  tappable month heading opens the month picker. Random is a separate quiet
  shuffle action in the navigation bar. Tapping a grid item begins there.
- Newest first traverses toward older items; Oldest first toward newer items.
  Reaching the end completes that traversal without wrapping.
- Merely browsing filters or the grid preserves the saved session. Starting a
  replacement while an unfinished session exists requires confirmation:
  “Start a new session?” / “Your current position and Undo history will be
  replaced. Marked items stay in Review.” Actions: “Keep current session” and
  “Start new session”.
- Viewer has Home at top left and Review with marked count at top right when
  marks exist. Home preserves the session without a prompt. Review provides a
  return to sorting. Neither navigation action initiates deletion.

## Interview round 2 — approved

- Tapping a category row toggles it without changing the other selections.
  Its Only action selects that category and deselects everything else, including
  videos. A plain-language summary describes the resulting pool.
- An excluded category wins when an item belongs to multiple categories. Other
  photos means photos outside the named categories. Each item appears once.
- Each Home entry starts with all items of its media type selected: Photos means
  all photo categories, Videos means all videos, Everything means both. Previous
  exclusions are not silently reused. Continue sorting retains the saved
  session's filters.
- Editing filters from the grid returns to the filter screen with current
  selections preserved. Continue updates the grid and retains its order choice.
  An empty pool shows “No matching items”, offers Change filters and disables
  Random. With no categories selected, Continue is disabled and the filter
  screen says “Select something to sort.”

## Interview round 3 — approved

- Videos initially show a still preview, a Play button, and a Video label with
  duration. Playback is user-initiated and starts muted with an explicit sound
  control.
- Dragging the picture keeps the same sorting behavior as a photo, both paused
  and playing. Only the dedicated playback timeline seeks. Place that timeline
  near the top, clear of the decision buttons; exact layout remains to be
  verified in the refined mockup. Playback controls do not initiate sorting
  decisions. Keep/Mark buttons remain available during playback.
- Begin with one Videos selection; video subcategories are deferred.
- Photos and videos share one deletion review. Video thumbnails show a play
  symbol and duration. Inspection supports playback and Restore. Mixed-media
  confirmation uses “Delete N items” and a photo/video count breakdown.
  Restoring and cancelling retain the existing safety behavior.

## Interview round 4 — approved

- Beginning a sorting drag pauses a playing video. Cancelling the drag resumes
  playback only if it was playing before the drag. Committing stops playback
  and advances. Timeline gestures seek without moving the picture.
- Undo and session resume return to a paused video. Playback position is retained
  within the app session; after relaunch the clip may start from its beginning.
  Durable sorting position and marks remain preserved independently.

## Interview round 5 — accepted direction

- A session's pool stays fixed when new library items arrive. New items become
  eligible in a new session; deleted or inaccessible items drop out safely.
- Settings offers System / Light / Dark, defaulting to System.
- Initial languages are English and Simplified Chinese, following the system's
  app-language preference. Settings provides an entry to system app settings.
  Translate accessibility and recovery/error copy as part of the same work.
- User requests a small fireworks celebration after confirmed deletion, showing
  storage saved, plus a possible lifetime achievement summary on Home. This
  deliberately revisits the earlier quiet-home/no-gamification direction.
  Presentation, trigger for partial success, and Home placement remain under
  discussion. Reaching the traversal end is distinct from deleting marked items.

## Interview round 6 — approved

- A fully successful confirmed deletion produces a short, one-time fireworks
  burst around the result, then settles. Show confirmed item count and estimated
  storage freed (for example “24 items deleted” / “About 320 MB freed”). No sound,
  forced wait, or repeating animation. Reduce Motion uses a gentle fade. Offer
  Continue sorting when a session remains, otherwise Back to Home.
- Home gains a quiet Your impact section below the primary actions and the
  separate Continue sorting/Review entries. Show lifetime confirmed deletion
  count and estimated storage freed through Swiper. Hide until the first
  successful deletion; tapping opens statistics in Settings.
- Partial deletion reports confirmed successes and items still marked, counts
  only confirmed savings, and offers review/retry without fireworks. Cancelled
  or failed deletion gets no celebration.

## Interview round 7 — approved, control movement still open

- Keep media inspection lightweight: a usable preview is enough to allow sorting
  while video playback loads. Show loading state and retain Home/Review access.
  With no usable preview, offer Retry and Skip for now. Skipping makes no
  Keep/Mark decision and leaves the item eligible for a future session.
- Remember mute/unmute during the current sorting visit; each clip still needs
  Play. Returning from Home or relaunching starts muted again.
- Preserve three control positions (bottom centre, left edge, right edge),
  optional button visibility, primary Keep/Mark emphasis, and a quieter Undo
  with a comfortable tap area. The complete image does not resize for controls.
  User explicitly rejects the current three-dot grip/overlapping slot experience;
  choose a new movement interaction before treating this portion as final.
- Add one Haptics setting, on by default. Use light feedback for selection
  changes and meaningful swipe thresholds. Follow system Reduce Motion and
  Reduce Transparency. Animation never delays the next action.

## Interview round 8 — initial control movement (visuals superseded below)

- Use lift-and-dock with a small ridged grip integrated into the glass tray,
  replacing the three-dot grip. Drag carries a compact handle, not the buttons.
  Three compact destination markers replace simultaneous full tray outlines;
  only the nearest eligible destination expands into a control preview.
- Dropping on a destination settles the tray there with one light haptic;
  dropping elsewhere cancels. The photo stays fixed. Tapping the grip offers
  explicit Left / Bottom / Right choices. Settings and accessibility actions
  retain equivalent placement controls.
- User requests fluid, Apple-guided Liquid Glass behavior. Tracking stays direct
  under the finger; destination changes and landing use short interruptible
  transitions without repeated bouncing or input delays. Reduced-motion and
  reduced-transparency alternatives preserve the same controls and meaning.
- Prefer native glass behavior on supported systems and an appropriate material
  fallback on older supported iOS versions. The custom docking interaction is
  our design, not an Apple-provided standard component. Verify its feel on device.
- This revises ADR-0007's grip and full-slot presentation, while retaining its
  three fixed positions and display-only movement semantics.

References: [Apple motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion),
[materials](https://developer.apple.com/design/human-interface-guidelines/materials),
[custom Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

## Viewer revision — owner feedback after mockup review

Other screen directions are accepted. Redesign the viewer as follows; these
requirements supersede round 8's ridged grip and expanded destination preview.

- Fit the complete asset to the full display canvas, preserving aspect ratio.
  Home, Review, media indicators, playback timeline and decision controls float
  over it inside safe touch bounds; none reserves a header/footer or shrinks the
  photo. Letterboxing is allowed only when needed by the asset's aspect ratio.
- Use a much smaller glass dock. Trash and Keep dominate; Undo is a tiny visual
  glyph with a comfortable non-overlapping touch target. The grip is three dots,
  without its own large button circle. It also retains a comfortable touch area.
- Drag the three-dot grip toward one of the three fixed destinations. Show only
  the active destination's subtle edge/landing cue, inspired by swipe outcome
  feedback; no full tray outlines or expanded control previews. Use a neutral or
  amber cue so placement cannot be mistaken for deletion. Magnetic capture
  changes the cue, not the finger-tracking position; release inside the target
  settles the dock with a light haptic, release elsewhere cancels.
- Preserve the tap-to-place alternative and Settings/accessibility placement
  actions. The current dock stays at its source until release. A grip gesture
  cannot decide the current item.
- Live/Video is a small informational reminder, not a prominent button.
  Playback controls are compact floating overlays; photo/video geometry stays
  fixed when they appear.
- Prototype must verify safe-area clearance, independent hit targets, photo
  aspect fit, target capture/cancellation, and actual perceived motion. Static
  images illustrate this intent rather than define exact dimensions.

## Viewer refinement — neutral chrome and handle research

- Owner accepts the full-screen media canvas and glass material, but requests
  neutral viewer chrome: remove orange from Review, media labels and placement
  cues. Keep red/green for Mark/Keep. Orange & Porcelain remains the surrounding
  app identity; the viewer is intentionally quieter.
- Live/Video should sit in a small neutral glass capsule beneath Home or Review,
  without a colored dot. Exact placement awaits the next viewer refinement.
- The visible three-dot grip and docking treatment are still too large. Research
  ellipsis and drag affordance conventions before choosing the next handle.
  Preserve comfortable independent touch targets even when glyphs are tiny.

## Remaining decisions (updated)

## Viewer reference update — 2026-09-26

- Owner moves the neutral LIVE/Video capsule beneath Review, aligned to the
  trailing edge, rather than beneath Home. Preserve the small glass capsule and
  remove the colored status dot.
- Owner rejects the large dot-grid handle; three dots would suffice if a handle
  is needed, and supplies a Windows app recording demonstrating a toolbar with
  no dedicated handle. See [reference analysis](../research/windows-app-dock-reference.md).
- Proposed next interaction to prototype: direct tray movement, collapsing into
  a neutral token while moving and expanding at the selected fixed destination.
  This replaces the previous source-tray-plus-separate-grip candidate if accepted.
  Drag recognition must cancel button actions; ordinary taps still Keep/Mark/Undo.
  Exact gesture initiation and discoverability remain prototype questions.

## Remaining decisions (latest)

## Magnetic landing — approved for prototype

Owner accepts handle-free movement inspired by the Windows app reference. While
dragging, three small neutral edge markers identify fixed destinations; the
nearest grows subtly, and the token has a bounded magnetic attraction. Entering
capture gives one light haptic. Moving away releases attraction. Releasing
commits placement and expands the token into the three controls together with a
brief soft spring; release outside a destination restores the prior position.
No staggered buttons or input delay. Prototype tunes capture, pull and gesture
arbitration on device; those constants are not yet production decisions.

See [native prototype instructions](orange-porcelain/PROTOTYPE.md).

## Remaining decisions (after prototype)

Completion states and final layout details; final review of shared understanding.
Final spec must reconcile the new Home impact summary and
celebration with earlier scope documents.

Video support revisits ADR-0003's v1 exclusion. The new entry flow revisits
ADR-0008's entry contract. Reconcile affected ADRs and shipped behavior docs when
the final spec is agreed; this draft does not silently supersede them.
