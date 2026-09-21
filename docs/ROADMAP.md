# Roadmap

Swiper is delivered as vertical slices. Each slice is a working, testable path
through the product; later slices are not started until the previous one builds
and is proven on a device.

## Slice 1a — durable, intuitive cleaning *(current)*

The redesign in [issue #10](https://github.com/Jinshuo7/Swiper/issues/10), added
on top of the tracer bullet:

* A viewer that shows the complete photo, with controls always inside the
  viewport.
* A deletion list that survives every sorting session, skips marked photos and is
  reachable from home and the viewer.
* Decisions acknowledged only after they are saved, with visible recovery when a
  save fails and versioned, migratable stored state.
* Minimal predictive swipe feedback and a replayable first-photo tutorial.

## Slice 1 — the tracer bullet *(done)*

The smallest end-to-end path that proves the core idea:

> permission → library snapshot → one real full-screen photo → decide
> (keep / queue for deletion / favorite) → reversible deletion queue →
> explicit deletion review → system-backed commit → result feedback

In scope for this slice:

* PhotoKit access (including limited library) with a clear privacy explanation.
* Photos and Live Photos; ordinary videos excluded everywhere.
* Entry: Continue, Recent, Start Here (lazy grid), Tumbler.
* Full-screen viewer with the four control presets and left/center/right
  placement.
* Undo, persisted session and deletion queue, stale-asset reconciliation.
* Deletion review with single restore and drag-select batch restore.
* Result feedback plus current-session and lifetime statistics.
* `SwiperKit` logic framework with unit tests; UI test of the fake-library flow.

Proven when the path above runs on a real iPhone and in the Simulator, and the
logic tests pass.

## Slice 2 — session ergonomics

* Richer progress affordances that are not cleanup statistics.
* Better large-library navigation (jump to month/date, search).
* Refined swipe physics and animations.
* Accessibility pass: Dynamic Type, reduced motion (VoiceOver labels for the
  photo and controls begin in slice 1a).

## Slice 3 — deletion confidence

* Undo immediately after a commit where the system still allows it.
* Clearer handling of partial failures and retry.
* Optional pre-deletion summary per album/month.

## Slice 4 — optional video support

* Add ordinary videos to traversal, review and statistics.
* `MediaKind` gains a video case; size estimates get a duration-based term.
* This slice is explicitly deferred; see
  [ADR-0003](adr/0003-exclude-ordinary-videos-in-v1.md).

## Explicitly out of scope

Cloud services, accounts, analytics, subscriptions, achievements, and a fully
custom gesture editor. None of these are needed to prove the core path.
