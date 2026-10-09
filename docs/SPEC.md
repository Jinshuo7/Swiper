# Behavioural specification (production v1)

> **Authoritative source: [issue #24](https://github.com/Jinshuo7/Swiper/issues/24).**
> This document is the in-repo, human-readable contract a production-v1 build
> must satisfy. It is a **target**: much of it is not built yet. As-built legacy
> behaviour is tracked separately in
> [`IMPLEMENTATION-STATUS.md`](IMPLEMENTATION-STATUS.md); read the two together.
> Where the legacy contract in this file's history, an ADR, a mock or a prototype
> conflicts with #24, #24 wins.

This describes behaviour, not code. Numeric interaction constants may be tuned
on real hardware without changing the contract.

## 1. Access and privacy

1. On first launch SWIPR explains, before asking, why it needs **read-write**
   photo access (favouriting is out of scope; deletion mutates the library) and
   that all media stays on the device.
2. SWIPR operates without accounts, tracking, analytics, advertising or uploaded
   media. It never requests more than read-write access.
3. **Limited-library access** is supported: SWIPR sorts the visible subset and
   offers **Select More Photos**.
4. If access is denied or restricted, SWIPR explains how to change it in Settings
   and offers a route to system Settings; it does not present the library.

## 2. Home, entry and filters

1. Home uses the approved **Orange & Porcelain** composition: Settings and a
   round 44 pt **Review** trash button in stable mirrored top-corner positions,
   photographic **Everything**, **Photos** and **Videos** choices, a conditional
   **Continue sorting** action, and a quiet conditional **Your impact** section.
   The Review button shows a small red count badge once anything is marked, and
   no badge at zero; it never spells out "Review".
2. **Continue sorting** (resume) is distinct from starting a new session, and
   **Review marked items** is distinct from both; reviewing never changes a
   session.
3. Each media choice opens **editable filters**:
   * **Everything** initially selects all photo categories *and* videos.
   * **Photos** initially selects all photo categories.
   * **Videos** initially selects the single video category.
   * Previous exclusions are not silently reused for a new session; Continue
     sorting always keeps its saved session filters.
4. Photo categories are **Screenshots, Live Photos, Panoramas, Other Photos**;
   there is exactly one general **Videos** selection. **Other Photos** means
   still photos outside the named categories, so every still photo has an
   understandable category.
5. A category row toggles without disturbing other choices, an **Only** action
   isolates one category, and **exclusions win when categories overlap**, so the
   result is deterministic.
6. Every matching library item appears **once**; overlapping categories never
   create duplicates. A plain-language pool summary lets the user verify it.
7. **Continue** is disabled when nothing is selected. An empty pool explains that
   nothing matches and offers **Change filters**. Returning from the
   starting-point grid preserves filters.

## 3. Starting point and the fixed session pool

1. The starting-point grid is grouped by month and supports month navigation.
2. Order choices are **Newest first** (walks older) and **Oldest first** (walks
   newer), plus tapping a specific grid item as the start.
3. **Random** creates a persisted, deterministic, repeat-free **Tumbler** order.
4. Traversal **completes rather than wraps** at the end of the selected
   traversal; there is a clear boundary.
5. A session captures a **fixed set of stable library identifiers** at creation.
   New library arrivals wait for a new session; missing or newly inaccessible
   identifiers reconcile safely.
6. Browsing filters and the grid leave an unfinished session untouched. Starting
   a replacement session requires a confirmation that position and Undo history
   will be replaced **while marked items remain**, and never clears the deletion
   list.

## 4. The full-screen viewer

1. The viewer shows the **complete current asset at its original aspect ratio**,
   centred and as large as the display allows. It is never cropped to fill the
   screen; unused area is letterboxed. Chrome never changes the media's size,
   position or crop ([ADR-0006](adr/0006-photo-never-moves-for-chrome.md)).
2. Overlays float over the media inside safe areas. A small neutral **Live
   Photo / Video** badge sits in the top bar row, vertically centred with Close;
   a plain photo carries no badge. Home, Review, media labels, playback controls
   and decisions stay inside safe touch bounds.
3. The palette is adaptive **neutral glass/material** over the Orange & Porcelain
   application. Red and green are limited to extremely faint desaturated edge
   illumination; symbols, wording, stroke and weight carry meaning.
4. Swipe decisions are **always available** regardless of button visibility
   ([ADR-0009](adr/0009-swipe-always-buttons-optional.md)). The media follows the
   finger. **Dragging left past the threshold marks for deletion; dragging right
   past the threshold keeps.** The commit threshold is confirmed by strengthened
   outline/symbol weight rather than saturation, with one light haptic at the
   crossing. The Delete/Keep feedback appears in the **upper third**, just below
   the top bar, so the thumb doing the swipe never covers it. Below-threshold,
   vertical and cancelled drags decide nothing.
5. **Undo** reverses the most recent decision of this session, including removing
   a just-marked item from the deletion list, and returns to that item. Undo never
   deletes, and it is the only way to reverse an individual decision. Its position
   is described as Before actions or After actions (see §5.6).

## 5. The decision dock

1. There are exactly **three fixed destinations**: left edge, bottom centre and
   right edge ([ADR-0007](adr/0007-three-fixed-control-positions.md)). Bottom is
   a centred **Delete / Keep** pair of labelled pills with a separate smaller
   **Undo** control; side positions are separate icon controls with a functional
   non-action gap and safe-area insets.
2. The **complete dock is directly draggable** from its buttons or gaps — there is
   no permanent grip and no long press. A normal tap performs its action with no
   movement delay.
3. Moving a finger roughly **9 pt cancels the pending tap permanently** for that
   gesture and morphs the dock into a compact neutral token. Three subtle
   destination markers appear; the nearest strengthens without saturated colour.
4. Recommended tuning starts near an 85 pt capture radius, 12 pt maximum
   attraction and 15 pt hysteresis; these may change without changing the
   contract. A valid release lands and restores all controls together; an invalid
   release returns to the source with no haptic.
5. Haptics: none on pickup, one light response on entering capture, one soft
   response on valid landing, none on invalid release, and no repeats while
   captured. A **Haptics** preference disables all optional responses.
6. Dock position is persisted **immediately**. **Control Position** is also in
   Settings, so placement never depends on dragging. **Undo position** is
   described as **Before actions** (default; left of the bottom pair, above a side
   pair) or **After actions**. Delete and Keep never move relative to each other
   ([ADR-0011](adr/0011-undo-at-the-outer-end.md)).
7. Stored preferences are: Control Position, Show Buttons, Haptics, Appearance,
   Language handoff and Undo Position. **Swipe decisions remain available when
   buttons are hidden.**

## 6. Video playback

1. Ordinary videos begin with a **still preview, duration and Play control** —
   every clip requires an explicit Play action; advancing never auto-plays.
2. Playback starts **muted** with an explicit sound control; the **mute
   preference is remembered during the current sorting visit** only, so returning
   from Home starts muted again.
3. A dedicated **timeline** seeks without moving the media. Keep and Delete
   remain available during playback.
4. Beginning a sorting drag **pauses** a playing video; cancelling that drag
   resumes **only if it was previously playing**; committing a decision stops
   playback and advances. Undo and session resume return to a **paused** video.
5. Playback position is retained during the current **app visit** but is **not
   durable sorting state**. Mute scope (sorting visit) and playback-position
   scope (app visit) are deliberately different.
6. A usable preview permits sorting while full playback loads. If no usable
   preview can be obtained, offer **Retry** and **Skip**; **Skip records neither
   Keep nor Mark for deletion** and leaves the item eligible later.

## 7. Deletion review, commit and results

1. Photos and videos share **one durable deletion list** that outlives sorting
   sessions and relaunches ([ADR-0005](adr/0005-deletion-list-outlives-sessions.md)).
   Items in the list are skipped by sorting.
2. Review is reachable from Home and the viewer. Thumbnails expose media kind and
   video duration; tapping opens full-screen inspection with playback.
   Individual and batch **Restore** are supported, including drag-selection.
3. Restoring removes an item from the list and keeps it for the current session
   so it is not immediately re-presented. Undo entries that would reapply a
   restored mark are dropped. No statistics are shown during review.
4. Tapping Delete in review is the explicit final action. SWIPR adds **no
   confirmation dialog of its own** — the single confirmation is the system's,
   which PhotoKit always presents and which is the only thing that authorises
   deletion. Review copy states the total item count and a photo/video breakdown.
5. **Actual deletion happens only from review and only after the system
   confirmation** ([ADR-0001](adr/0001-never-delete-while-swiping.md)). Sorting
   never mutates the library. Cancelling the system prompt retains every mark and
   changes no statistics.
6. Local storage and PhotoKit are not one transaction. After a commit SWIPR
   re-reads the library: only **confirmed** deletions count, unsuccessful items
   stay marked and are never re-counted, and retry is safe. Assets removed
   outside SWIPR are reconciled without being credited as SWIPR deletions.
7. A **fully successful** deletion shows one short no-sound fireworks moment
   around the result, then settles into a result reporting confirmed count and
   **estimated** storage freed ([ADR-0002](adr/0002-public-api-storage-estimates.md)).
   **Reduce Motion** replaces it with a gentle fade. Cancelled, failed and
   partial outcomes never celebrate.
8. Statistics are a read-only block inline in Settings. A quiet **Your impact**
   summary appears on Home after the first success and routes to those stats.
   Only confirmed deletions are ever counted; units scale naturally.

## 8. Persistence

1. Position, filters, order, decisions, Tumbler order and Undo are restored so
   **Continue sorting** is truthful.
2. An acknowledged decision is **saved before the session advances**. A failed
   save pauses input, parks a recoverable pending decision, blocks further input
   and offers **Retry** without duplicate effects.
3. Stored state carries a **schema version** and migrates atomically
   ([ADR-0004](adr/0004-schema-versioned-session-persistence.md)). Unreadable or
   newer-version data is reported and **never overwritten** as if empty. Only
   stable identifiers and logical, playback-independent session state are
   persisted — never image or video data.

## 9. Appearance, accessibility and languages

1. **System, Light and Dark** appearances ship. Prefer native Liquid Glass where
   available, with a deliberate **iOS 17 opaque/material fallback** of identical
   geometry and semantics.
2. Accessibility is part of the contract: minimum 44 pt touch targets, no
   colour-only meaning, responsive **Dynamic Type** without truncation or
   disappearing actions, individual **VoiceOver** elements with meaningful
   labels and hints, direct placement accessibility actions that announce the
   result, stable **Voice Control** names, Reduce Motion, Reduce Transparency,
   sufficient contrast and safe-area containment.
3. **English and Simplified Chinese ship complete.** Application and domain-layer
   copy each use the correct resource bundle; safety, error, recovery, plural,
   accessibility, store, privacy and support copy are included. A fluent human
   reviews Simplified Chinese before release. See
   [`LOCALIZATION.md`](LOCALIZATION.md).
4. **Accessibility baseline:** the former largest-accessibility-text ("AX5")
   reachability failure is fixed (#58) and its CI skip was removed (#69), so the
   suite including AX5 is green. Release still requires a green suite on the
   release-candidate commit.

## 10. App Store release

1. Product name **SWIPR** (if available), recommended subtitle "Clean photos and
   videos", Photo & Video category, free, no accounts/ads/analytics/tracking/
   purchases/subscriptions.
2. Minimal Orange & Porcelain app icon with one clear stacked-media/swipe mark,
   no text. **The owner approves the final rendered asset before submission.**
3. Localized store metadata and **five screenshots** covering Home, Filters,
   Viewer, mixed Review and successful impact. No promotional App Preview video.
4. A bilingual privacy policy and a support page with contact information.
   Declare "no data collected" only after auditing the final binary and
   dependencies, with accurate required-reason API declarations and
   privacy-manifest output.
5. Validate the minimum iOS 17 fallback and the latest supported iOS; use
   simulator widths plus at least one physical iPhone. **A locked or unavailable
   device is a blocked manual gate, never bypassed.**
6. Build and validate a distribution archive, upload the exact release candidate
   to App Store Connect and complete internal TestFlight validation. The owner
   completes at least three full cleanup sessions; a fluent reviewer completes
   the Simplified Chinese pass.
7. **Release manually after App Review. The submitted binary must be built from
   the exact tested release-candidate commit**, and it must carry no known crash,
   data-loss risk, deletion-safety defect, correctness defect or accessibility
   blocker. A purely cosmetic defect may ship only through an explicit recorded
   waiver.

## 11. Safety invariants

* SWIPR never deletes while sorting.
* Deleting requires two deliberate acts: the final Delete action in review, then
  the system confirmation. SWIPR never adds a third.
* A marked item is reversible until the final commit; restored items become kept
  and leave the deletion list.
* An acknowledged decision is always saved first; a failed save is visible and
  retryable and is never presented as success.
* Statistics reflect only confirmed successful changes.
* Automated tests never touch a real photo library.
