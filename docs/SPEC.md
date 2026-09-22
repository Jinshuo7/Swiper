# Behavioural specification

This is the contract a build must satisfy. It describes behaviour, not code.

## 1. Access

1. On first launch SWIPR asks for read-write photo access, because both
   favouriting and deleting mutate the library. SWIPR never requests more than
   this.
2. Before asking, SWIPR explains what access is for and that all data stays on
   the device.
3. Limited-library access is supported: SWIPR shows the visible subset and
   offers a control to select more photos.
4. If access is denied or restricted, SWIPR explains how to change it in
   Settings and does not present the library.

## 2. Entry

The entry screen offers exactly these choices:

* **Continue sorting** — shown only when unfinished session state exists, and
  resumes it at the saved position with its Undo history.
* **Review & delete · N** — shown whenever N photos are marked for deletion, and
  opens deletion review directly from home.
* **Recent** — start a sequential session at the newest asset, traversing
  toward older photos. Recent is about where it starts, so it begins at the
  newest asset whatever the default direction is set to.
* **Start Here** — open a lazily loaded grid of the whole library, grouped into
  calendar months with the newest first, and begin at the chosen asset. The
  screen states what it is for (choosing where to begin, after which SWIPR walks
  in the default direction and skips anything already decided or marked). A month menu
  jumps straight to any point in the library, and a control flips the order
  between newest and oldest, so no one has to scroll in from one end. Only
  visible thumbnails are decoded; full images are not loaded. Photos already
  marked for deletion are badged and cannot be started on.
* **Tumbler** — begin a randomised, repeat-free session.

Home always states the marked count with the wording "N photos marked for
deletion" and "Nothing deleted yet.", so a leftover mark is never mistaken for a
completed deletion.

A subtle statistics icon opens the statistics page; a settings icon opens
settings. Statistics are not otherwise visible.

## 3. The full-screen viewer

1. The viewer contains the complete asset at its original aspect ratio, centred
   against black and as large as the display allows. It is never cropped merely
   to fill the screen; unused area stays black. Live Photos show their still and
   can play their motion.
2. A Live Photo is labelled as one — a "LIVE" chip centred in the top strip, with
   the `livephoto` symbol and the word, plus a spoken hint that press-and-hold
   plays the motion — so the asset kind is never something the user has to infer.
3. Only the current asset's display image and a small prefetch window of
   neighbours are requested. Requests for assets that are no longer current are
   cancelled.
4. Every control and overlay stays inside the viewport and its safe area, so
   Close, the heart and the three decision controls are always reachable. There
   is no permanent instruction text over the photo.
5. Whenever photos are marked for deletion, the viewer shows a compact
   `Review · N` control that opens deletion review without ending the session.
6. Default Swipe preset gestures. The photo follows the finger, and the drag
   reveals a feedback-only well in the lower corner it is heading for: trash on
   the left, check on the right. The wells are never separate tap targets.
   * drag left past the threshold and release → mark for deletion and advance;
   * drag right past the threshold and release → keep and advance.
7. The commit threshold is visible — the well arms with a brighter fill and a
   stronger stroke — and is confirmed with a single light haptic at the moment it
   is crossed, not on every update. Releasing below the threshold, releasing a
   vertical drag and cancelling all make no decision.
8. Reduce Motion removes the spring-back animation and the well's scale change;
   the meaning is still carried by symbol, wording and stroke, never by colour or
   motion alone.
9. A heart control in the top strip marks the asset as an Apple Photos favorite,
   keeps it and advances. It is always available, so nobody has to perform a
   gesture, and it costs the decision controls no space.
10. Undo reverses the most recent decision of this session, including removing a
   just-marked photo from the deletion list, and returns to that photo. Undo
   never deletes.
11. Traversal moves in the preferred direction, skipping assets already decided
   in this session and assets marked for deletion. At the end of the library it
   continues in the other direction if undecided assets remain.
12. Nothing is ever deleted from the viewer.

## 4. The control cluster and presets

Every decision control lives on **one cluster of three**: Trash, Undo and
Checkmark, in that order. Nothing about the current photo, the number of marks or
the active preset moves it. The way out, the favorite and the review entry live in
the top strip instead.

* **Close** is always the top left corner, drawn smaller than the decision
  controls, the way a Back button is on every other screen. **Favorite** and the
  compact `Review · N` entry share the top right, and a Live Photo's **LIVE** chip
  is centred between them.
* The cluster **docks to the lower part of one of three edges**: the bottom as a
  row, or the left or right edge as a column. It never reaches into the top strip.
* The user moves it by **touching and holding the bar behind the controls**, then
  dragging. The controls themselves claim their own taps, so the bar around and
  between them is the handle, and it is drawn so the thing that moves is visible.
  A plain drag never moves the cluster, because a plain drag on the photo is how a
  decision is made. Dropping it docks it to whichever of the three edges its
  centre is nearest, and the position along that edge is continuous, so it can be
  parked where a particular thumb reaches.
* The dock and the position are persisted immediately, and **Reset control
  position** in Settings brings the cluster back to the bottom centre. The dock
  can also be stepped through from the cluster's accessibility actions, for
  anyone who cannot drag.
* A side-docked cluster reserves a lane: the photo is fitted beside it, so a
  control never sits on top of the photo.
* The cluster **fades to 55%** after five seconds without a touch, and comes back
  on the next one. It never hides: the buttons are the non-gesture way to decide.
* The preset decides only how a decision can be made, never which controls exist:

| Preset | Swipe gestures | Tap to keep |
| --- | --- | --- |
| Swipe (default) | yes | no |
| Buttons only | no | no |
| Tap to keep | no | yes |

* **Swipe** also offers the drags: left past the threshold marks for deletion,
  right past it keeps, and the wells read **Delete** and **Keep**. In **Buttons
  only** and **Tap to keep** a drag decides nothing, so a stray swipe can never
  mark a photo. In **Tap to keep**, tapping the photo keeps it.
* Preferences written when the controls varied by preset, or when the rail had
  three anchors, still load: `Extended` behaves as `Swipe`, and an old anchor or
  placement becomes a continuous position.
* A Live Photo is labelled in the top strip; the review entry appears there once
  photos are marked.

## 4a. Teaching

1. The first time a photo is presented, SWIPR explains the flow once: how to
   mark for deletion, how to keep, that nothing is deleted until review is
   confirmed, and that accepted decisions are saved as they are made.
2. The explanation matches the selected preset: the Swipe preset describes the
   drag, the button presets describe the buttons and never tell the user to
   swipe.
3. Dismissing it is permanent until the user replays it from Settings → How to
   use. It is teaching state, not saved work, and never blocks sorting again
   after it is dismissed.

## 5. Resume and persistence

1. Progress (current asset, direction, decisions, undo history, Tumbler order)
   is saved on device and offered as Continue sorting.
2. The deletion list is stored separately from the sorting session and survives
   starting a new session, switching mode and relaunching. See
   [ADR-0005](adr/0005-deletion-list-outlives-sessions.md).
3. Persistence stores stable PhotoKit local identifiers only, never images.
4. On resume, identifiers that no longer exist in the library are dropped and
   the current asset falls back to the nearest still-present asset in the
   preferred direction. Externally removed assets are never counted as deletions,
   and the user is told that they were removed from the list rather than left to
   wonder where a mark went.
5. Tumbler never repeats an asset within a session.
6. A new session resets traversal position, in-session decisions and Undo; it
   never clears a mark. Photos marked for deletion are skipped by every sorting
   entry point, so a photo is decided once.
7. Stored state carries a schema version. Data written by a newer version of
   SWIPR, or data that cannot be read, is reported to the user and is never
   overwritten as if the session were empty. See
   [ADR-0004](adr/0004-schema-versioned-session-persistence.md).
8. A decision is acknowledged only after it has been saved. A failed save pauses
   sorting, keeps the decision recoverable and offers an explicit retry; the
   session never advances on an unsaved decision.

## 6. Deletion review

1. The review shows the marked photos as a grid of thumbnails. It is reachable
   from home and from the viewer at any time, not only at the end of a session.
2. Tapping a thumbnail opens full-screen inspection.
3. A single photo can be restored. Selection mode lets the user drag across
   thumbnails to select a batch, and restore the selected batch.
4. Restoring removes a photo from the deletion list, so a later session may
   present it again, and keeps it for the current session so it is not
   immediately re-presented. Undo entries that would reapply a restored mark are
   dropped.
5. No statistics or reclaimed-storage totals are displayed during review.
6. Tapping Delete in review is the explicit final action; it asks the system to
   delete the remaining marked photos. SWIPR adds **no confirmation dialog of
   its own** — the single confirmation is the system's, which PhotoKit always
   presents and which is the only thing that authorises the deletion. The review
   screen states what the commit will do, since that explanation no longer lives
   in a dialog.
7. After the commit, only assets that are confirmed gone count as deleted.
   Unsuccessful or cancelled deletions stay marked and are not counted.
8. Leaving review returns to the place it was opened from, or home when there is
   no active sorting session.
9. Local storage and PhotoKit are not one transaction. SWIPR never claims a
   deletion it did not confirm: after a commit it re-reads the library, removes
   only confirmed-deleted assets from the list, keeps unsuccessful ones marked,
   and re-checks stored state against the library on the next launch. Assets that
   vanished outside SWIPR are dropped from the list without being counted as
   deletions, and a retry never re-requests or re-counts an asset that is already
   gone.

## 7. Result and statistics

1. After a successful deletion, a dismissible result reports the number of
   photos deleted and approximately how much storage was reclaimed.
2. A separate statistics page shows current-session and lifetime totals for
   confirmed deletions, plus the number of completed cleanup sessions.
3. Only confirmed deletions are ever counted.
4. Units scale naturally: bytes → KB → MB → GB → TB.
5. Storage is presented as approximate. See
   [ADR-0002](adr/0002-public-api-storage-estimates.md).

## 8. Safety invariants

* SWIPR never deletes while swiping.
* Deleting requires two deliberate acts: tapping Delete in review, then allowing
  it in the system prompt. SWIPR never adds a third.
* A marked photo is reversible until the final commit.
* Restored photos become kept and leave the deletion list.
* An acknowledged decision is always saved first; a failed save is visible and
  retryable, and is never presented as success.
* Statistics only reflect confirmed successful changes.
* Automated tests never touch a real library.
