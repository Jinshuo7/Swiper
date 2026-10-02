# Ordinary videos are excluded from v1

**Status: SUPERSEDED** by the production-v1 decision in
[issue #24](https://github.com/Jinshuo7/Swiper/issues/24) (2026-10-01). Ordinary
video is now in scope for v1 and is sorted, played and reviewed alongside photos,
Live Photos and screenshots. The exclusion below was correct for the earlier
tracer bullet and is kept as history, not as a current rule. See
[`docs/SPEC.md`](../SPEC.md) §6 and [`CONTEXT.md`](../../CONTEXT.md).

## Original decision (historical, no longer normative)

Swiper v1 handles still photos and Live Photos only. Ordinary videos are not
fetched, not shown, not queued and not counted in any statistic, even though
video is often the largest thing in a library.

Video brings a materially different experience — playback, trimming, different
storage arithmetic, different review behaviour — that would slow the first
tracer bullet without proving the core decision loop. Excluding it outright, all
the way down to `MediaKind` having no video case, keeps the first slice small
and keeps statistics honest. Adding it later is a deliberate forward slice; see
`docs/ROADMAP.md`.

Consequence for future work: adding video support means extending `MediaKind`,
the PhotoKit fetch predicate, the viewer, and the size estimator together, not
just loosening a filter.
