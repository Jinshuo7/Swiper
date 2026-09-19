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

* **Continue** — shown only when unfinished session state exists and resumes it.
* **Recent** — start a sequential session at the newest asset, traversing
  toward older photos.
* **Start Here** — open a lazily loaded grid of the whole library and begin at
  the chosen asset. Only visible thumbnails are decoded; full images are not
  loaded.
* **Tumbler** — begin a randomised, repeat-free session.

A subtle statistics icon opens the statistics page; a settings icon opens
settings. Statistics are not otherwise visible.

## 3. The full-screen viewer

1. One photo occupies the whole screen against black, edge to edge, preserving
   aspect ratio. Live Photos show their still and can play their motion.
2. Only the current asset's display image and a small prefetch window of
   neighbours are requested. Requests for assets that are no longer current are
   cancelled.
3. Default Swipe preset gestures:
   * swipe left → queue for deletion and advance;
   * swipe right → keep and advance;
4. A heart control marks the asset as an Apple Photos favorite, keeps it and
   advances.
5. Undo reverses the most recent decision, including removing a just-queued
   photo from the deletion queue, and returns to that photo. Undo never deletes.
6. Traversal moves in the preferred direction, skipping assets already decided
   in this session. At the end of the library it continues in the other
   direction if undecided assets remain.
7. Nothing is ever deleted from the viewer.

## 4. Control presets and placement

| Preset | Keep | Delete | Favorite | Undo | Swipe gestures |
| --- | --- | --- | --- | --- | --- |
| Swipe | gesture | gesture | top bar | top bar | yes |
| Thumb | button | button | top bar | top bar | no |
| Delete only | advancing | button | top bar | top bar | no |
| Extended | button | button | button | button | no |

* In **Delete only**, advancing (tapping the photo) keeps it; only the Delete
  control queues it.
* Floating controls can be placed left, centered or right.
* The choice is persisted immediately and never removes the full-screen photo.

## 5. Resume and persistence

1. Progress (current asset, direction, decisions, deletion queue, undo history,
   Tumbler order) is saved on device and offered as Continue.
2. Persistence stores stable PhotoKit local identifiers only, never images.
3. On resume, identifiers that no longer exist in the library are dropped and
   the current asset falls back to the nearest still-present asset in the
   preferred direction. Externally removed assets are not counted as deletions.
4. Tumbler never repeats an asset within a session.

## 6. Deletion review

1. The review shows the queued photos as a grid of thumbnails.
2. Tapping a thumbnail opens full-screen inspection.
3. A single photo can be restored. Selection mode lets the user drag across
   thumbnails to select a batch, and restore the selected batch.
4. Restoring removes a photo from the deletion queue; it becomes kept.
5. No statistics or reclaimed-storage totals are displayed during review.
6. Only after an explicit final confirmation does Swiper ask the system to
   delete the remaining queued photos. The system presents its own confirmation
   as well.
7. After the commit, only assets that are confirmed gone count as deleted.
   Failed or cancelled deletions stay queued and are not counted.

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
* A queued photo is reversible until the final commit.
* Restored photos become kept.
* Statistics only reflect confirmed successful changes.
* Automated tests never touch a real library.
