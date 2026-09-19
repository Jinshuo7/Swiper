# Ordinary videos are excluded from v1

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
