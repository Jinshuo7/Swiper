# Swiper

Swiper exists to make cleaning a photo library fast, physical and safe on an
iPhone. After granting photo access, one photo fills the screen and a small,
configurable gesture or button decides its fate. Nothing is deleted while the
user is swiping: deletions only happen after an explicit, system-backed final
confirmation in a dedicated review.

The first product version handles still photos and Live Photos only. Ordinary
videos are deliberately out of scope.

## Why

Photo libraries grow past the point where sorting through them is pleasant.
Most cleaners optimise for gamification, statistics and aggressive deletion.
Swiper optimises for three things instead:

1. **Low thumb effort.** The decision is a swipe or a button near the thumb.
2. **Reversibility.** Marking is not deleting. Marks survive mode changes and
   relaunches, Undo is one tap away, and restored photos leave the list.
3. **Honesty.** Storage numbers are labelled as estimates and only confirmed
   deletions ever count.

## Experience in one paragraph

Open Swiper, grant access, and decide: **Continue sorting** if an unfinished
session exists, **Review & delete · N** if photos are already marked, **Recent**
to start at the newest photo, **Start Here** to pick a starting point from a
scrollable grid, or **Tumbler** for a repeat-free random walk. Decide each photo
with swipe left (mark for deletion), swipe right (keep), or a heart (favorite,
keep, advance), or switch to a button preset. Traversal remembers the preferred
direction and defaults toward older photos, and skips photos already marked.

Marking is not deleting, and it is not session state: one deletion list carries
across modes and relaunches, home and the viewer both open review, and only an
explicit confirmation in review asks the system to delete. There, marked photos
are inspected full-screen, restored one at a time or as a drag-selected batch,
and a dismissible result then reports how many photos were deleted and
approximately how much storage was reclaimed.

## Documentation map

| Document | Purpose |
| --- | --- |
| [`CONTEXT.md`](CONTEXT.md) | The project's domain glossary. |
| [`docs/VISION.md`](docs/VISION.md) | Product vision and the boundaries of v1. |
| [`docs/SPEC.md`](docs/SPEC.md) | Behavioural specification of the shipped flow. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Vertically sliced delivery plan. |
| [`docs/adr/`](docs/adr) | Hard-to-reverse decisions and why they were made. |
| [`README.md`](README.md) | Build, run and safe manual verification. |
