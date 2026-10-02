# SWIPR

> **Status: production-v1 target, not yet fully implemented.** This document
> describes the product v1 the owner approved in
> [issue #24](https://github.com/Jinshuo7/Swiper/issues/24), which is the
> **authoritative production-v1 specification**. Everywhere it conflicts with
> older docs, ADRs or prototypes, #24 wins. See
> [`IMPLEMENTATION-STATUS.md`](IMPLEMENTATION-STATUS.md) for what is actually
> built today.

SWIPR exists to make cleaning a photo library fast, physical and safe on an
iPhone. One library item fills the screen and a neutral set of controls decides
its fate. Nothing is deleted while sorting: deletion only happens from deletion
review after the system's mandatory confirmation.

Production v1 handles **photos, Live Photos and ordinary videos**.

## Why

Photo libraries grow past the point where sorting through them is pleasant.
Most cleaners optimise for gamification, statistics and aggressive deletion.
SWIPR optimises for three things instead:

1. **Low effort.** The decision is a swipe or a control near the thumb; the
   whole control dock moves directly between three fixed positions.
2. **Reversibility.** Marking is not deleting. Marks survive mode changes,
   session replacement and relaunches; Undo is one tap away; restored items
   leave the deletion list.
3. **Honesty.** Storage numbers are labelled as estimates and only confirmed
   deletions ever count.

The interface is deliberately neutral and media-led so the asset is never
competing with the app chrome.

## Experience in one paragraph

Open SWIPR, grant access (read-write, because deletion mutates the library; all
media stays on device). Home offers **Everything**, **Photos** and **Videos**.
Each choice opens **editable filters** with sensible defaults. The resulting
filter pool is fixed when the session begins, and traversal completes at the end
rather than wrapping. A starting-point grid then lets you pick order (**Newest
first** / **Oldest first**), a month, a specific item, or **Random** for a
repeat-free Tumbler walk. In the
viewer the complete asset is shown at its original aspect ratio with floating
controls that never resize it. Drag left to mark for deletion or right to keep —
or use the neutral dock, which morphs into a token and can be moved directly to
the left, bottom or right position. Videos start on a still preview, play muted
on request, and never autoplay. **Undo** reverses the latest session decision and
its position is a **Before actions / After actions** setting. Marking is not
deleting: one durable deletion list carries across sessions, **Review marked
items** is reachable from Home and the viewer, and only the system confirmation
in review authorises deletion. A dismissible result then reports the confirmed
count and estimated storage freed, and a quiet **Your impact** summary appears on
Home afterwards.

## Production v1 boundaries

* iPhone only, portrait application layout, iOS 17 minimum. Landscape media is
  fully visible within the portrait interface; iPad, a landscape layout and
  macOS are not introduced.
* English and Simplified Chinese, both **complete**. No other languages.
* No accounts, ads, analytics, tracking, subscriptions or in-app purchases.
* Ordinary video is in scope; video categories, trimming, editing, transcoding
  and automatic playback are not.
* Dock has exactly three fixed positions and direct whole-dock dragging; no
  free-form placement, custom gesture editor or permanent grip.
* Release is manual after App Review, from the exact tested release-candidate
  commit. See the App Store section of [`SPEC.md`](SPEC.md).

## Documentation map

| Document | Purpose |
| --- | --- |
| [Issue #24](https://github.com/Jinshuo7/Swiper/issues/24) | **Authoritative production-v1 specification.** |
| [`CONTEXT.md`](../CONTEXT.md) | The project's domain glossary. |
| [`docs/VISION.md`](VISION.md) | This document: product vision and v1 boundaries. |
| [`docs/SPEC.md`](SPEC.md) | Behavioural contract v1 must satisfy (target, not as-built). |
| [`docs/ROADMAP.md`](ROADMAP.md) | The v1 ticket map (#25–#36) and legacy history. |
| [`docs/LOCALIZATION.md`](LOCALIZATION.md) | English + Simplified Chinese plan and blockers. |
| [`docs/IMPLEMENTATION-STATUS.md`](IMPLEMENTATION-STATUS.md) | As-built legacy state vs. required v1. |
| [`docs/adr/`](adr) | Hard-to-reverse decisions and why they were made. |
| [`README.md`](../README.md) | Build, run and safe manual verification. |
