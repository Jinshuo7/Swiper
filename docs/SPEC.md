# Behavioural specification

This is the contract a build must satisfy. It describes behaviour, not code.

## 1. Access

1. On first launch Swiper asks for read-write photo access, because both
   favouriting and deleting mutate the library. Swiper never requests more than
   this.
2. Before asking, Swiper explains what access is for and that all data stays on
   the device.
3. Limited-library access is supported: Swiper shows the visible subset and
   offers a control to select more photos.
4. If access is denied or restricted, Swiper explains how to change it in
   Settings and does not present the library.

## 2. Entry

The entry screen offers exactly these choices:

* **Continue sorting** — shown only when unfinished session state exists, and
  resumes it at the saved position with its Undo history.
* **Review & delete · N** — shown whenever N photos are marked for deletion, and
  opens deletion review directly from home.
* **Recent** — start a sequential session at the newest asset, traversing
  toward older photos.
* **Start Here** — open a lazily loaded grid of the whole library, grouped into
  calendar months with the newest first, and begin at the chosen asset. The
  screen states what it is for (choosing where to begin, after which Swiper walks
  toward older photos and skips anything already decided or marked). A month menu
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
2. A Live Photo is labelled as one — a "LIVE" chip beside Close, with the
   `livephoto` symbol and the word, plus a spoken hint that press-and-hold plays
   the motion — so the asset kind is never something the user has to infer.
3. Only the current asset's display image and a small prefetch window of
   neighbours are requested. Requests for assets that are no longer current are
   cancelled.
4. Every control and overlay stays inside the viewport and its safe area, so
   Close, Favorite and Undo are always reachable. There is no permanent
   instruction text over the photo.
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
9. A heart control marks the asset as an Apple Photos favorite, keeps it and
   advances. It is always available, so nobody has to perform a gesture.
10. Undo reverses the most recent decision of this session, including removing a
   just-marked photo from the deletion list, and returns to that photo. Undo
   never deletes.
11. Traversal moves in the preferred direction, skipping assets already decided
   in this session and assets marked for deletion. At the end of the library it
   continues in the other direction if undecided assets remain.
12. Nothing is ever deleted from the viewer.

## 4. Control rail and presets

Every control lives on **one rail**. Nothing about the current photo, the number
of marks or the active preset moves a control: the rail is anchored to the screen,
not to the photo, and the review entry sits in the separate top strip rather than
in the rail.

* The rail runs along one edge: **Bottom**, **Left side** or **Right side**.
  This is the handedness choice — a right thumb reaches the bottom or right rail,
  a left thumb the bottom or left one.
* Along that edge it is anchored at the start, centre or end (left/centre/right on
  a bottom rail; top/middle/bottom on a side rail).
* Order is fixed from least to most thumb-accessible: Close, then Favorite, then
  Undo, then the decision pair with Keep last. On a side rail Close is at the top
  and Keep at the bottom; on a bottom rail Close is at the leading end.
* The preset decides which controls exist, never where they are:

| Preset | Keep | Delete | Favorite | Undo | Swipe gestures |
| --- | --- | --- | --- | --- | --- |
| Swipe | gesture | gesture | rail | rail | yes |
| Thumb | rail | rail | rail | rail | no |
| Delete only | advancing | rail | rail | rail | no |
| Extended | rail | rail | rail | rail | no |

* In **Delete only**, advancing (tapping the photo) keeps it; only the Delete
  control marks it.
* The rail, its anchor, the preset and the direction are persisted immediately,
  and no choice ever removes the full-screen photo.
* A Live Photo is labelled in the top strip; the review entry appears there once
  photos are marked.

## 4a. Teaching

1. The first time a photo is presented, Swiper explains the flow once: how to
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
   Swiper, or data that cannot be read, is reported to the user and is never
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
   delete the remaining marked photos. Swiper adds **no confirmation dialog of
   its own** — the single confirmation is the system's, which PhotoKit always
   presents and which is the only thing that authorises the deletion. The review
   screen states what the commit will do, since that explanation no longer lives
   in a dialog.
7. After the commit, only assets that are confirmed gone count as deleted.
   Unsuccessful or cancelled deletions stay marked and are not counted.
8. Leaving review returns to the place it was opened from, or home when there is
   no active sorting session.
9. Local storage and PhotoKit are not one transaction. Swiper never claims a
   deletion it did not confirm: after a commit it re-reads the library, removes
   only confirmed-deleted assets from the list, keeps unsuccessful ones marked,
   and re-checks stored state against the library on the next launch. Assets that
   vanished outside Swiper are dropped from the list without being counted as
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

* Swiper never deletes while swiping.
* Deleting requires two deliberate acts: tapping Delete in review, then allowing
  it in the system prompt. Swiper never adds a third.
* A marked photo is reversible until the final commit.
* Restored photos become kept and leave the deletion list.
* An acknowledged decision is always saved first; a failed save is visible and
  retryable, and is never presented as success.
* Statistics only reflect confirmed successful changes.
* Automated tests never touch a real library.
