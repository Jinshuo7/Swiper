# Roadmap

> **Production v1 is specified by [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24)
> and delivered as tickets [#25–#36](https://github.com/Jinshuo7/SWIPR/issues/24).
> #24 is authoritative.** The legacy slices below are history, kept for context
> only; their photo-only scope and grip interaction are superseded.

## Production v1 tickets (#25–#36)

Delivery is ticket-based, not one whole-spec implementation. Ticket titles are
the source of truth for their own contents; this file does not restate them.
Track and sequence them from the [parent spec #24](https://github.com/Jinshuo7/SWIPR/issues/24)
and the GitHub issue list, not from this page.

| Ticket | Title |
| --- | --- |
| [#25](https://github.com/Jinshuo7/SWIPR/issues/25) | V1-01: Make the production-v1 contract durable |
| [#26](https://github.com/Jinshuo7/SWIPR/issues/26) | V1-04: Ship the neutral direct-move decision dock |
| [#27](https://github.com/Jinshuo7/SWIPR/issues/27) | V1-02: Start a filtered mixed-media session |
| [#28](https://github.com/Jinshuo7/SWIPR/issues/28) | V1-05: Play and sort ordinary videos |
| [#29](https://github.com/Jinshuo7/SWIPR/issues/29) | V1-03: Choose a starting point and replace sessions safely |
| [#30](https://github.com/Jinshuo7/SWIPR/issues/30) | V1-06: Review and delete mixed media safely |
| [#31](https://github.com/Jinshuo7/SWIPR/issues/31) | V1-07: Celebrate confirmed cleanup and show impact |
| [#32](https://github.com/Jinshuo7/SWIPR/issues/32) | V1-08: Make the complete journey accessible and adaptive |
| [#33](https://github.com/Jinshuo7/SWIPR/issues/33) | V1-09: Ship complete English and Simplified Chinese experiences |
| [#34](https://github.com/Jinshuo7/SWIPR/issues/34) | V1-11: Prepare the localized App Store identity and listing |
| [#35](https://github.com/Jinshuo7/SWIPR/issues/35) | V1-10: Prove on-device privacy and publish support materials |
| [#36](https://github.com/Jinshuo7/SWIPR/issues/36) | V1-12: Validate and deliver the release candidate |

Every ticket lands on the release candidate commit only when its acceptance
criteria and required tests/human gates pass. Release is manual after App Review,
from the exact tested release-candidate commit (see [`SPEC.md`](SPEC.md) §10).

## What v1 must change from the legacy build

The legacy build (issues #10–#16 and the audit rounds) delivered durable
deletion safety and persistence, but its mutable product behaviour is
superseded:

* Ordinary **video** is now in v1. [ADR-0003](adr/0003-exclude-ordinary-videos-in-v1.md)
  is **superseded** (production-v1 decision, 2026-10-01); it is retained as
  history.
* **Home and editable filters precede** the starting-point grid; the single
  "Choose a photo" entry contract is **superseded**
  ([ADR-0008](adr/0008-choose-a-photo-owns-every-entry.md)).
* The session pool is **fixed and non-wrapping**.
* The grip/slot control movement is replaced by **direct whole-dock movement**
  between the same three fixed positions
  ([ADR-0007](adr/0007-three-fixed-control-positions.md) is **amended** to keep
  the destinations and drop the grip/puck/slot mechanism).
* Undo is described as **Before actions / After actions**
  ([ADR-0011](adr/0011-undo-at-the-outer-end.md) is **amended**).
* The glossary is media-neutral ([`CONTEXT.md`](../CONTEXT.md) reconciled; the
  pre-reconciliation copy is archived under
  [`docs/history/production-v1-reconciliation/`](history/production-v1-reconciliation/README.md)).
* English **and Simplified Chinese** both ship complete.
* An **App Store manual release** gate is required.

Preserved invariants: never deleting while swiping, public-API storage estimates,
versioned persistence, deletion-list lifetime, media never moving for chrome,
swipe always available, and confirmed-only statistics.

## Legacy slices *(history only — superseded)*

The earlier vertical-slice plan is retained only as historical context:

* **Slice 1a — durable, intuitive cleaning** (issue #10): complete-photo viewer,
  durable deletion list, save-before-acknowledge persistence, minimal swipe
  feedback and a replayable tutorial. Durable substance kept; product surface
  superseded by #24.
* **Slice 1 — the tracer bullet**: permission → library → one photo → decide →
  reversible list → review → system commit → result.
* **Slices 2–4** (ergonomics, deletion confidence, optional video): never
  delivered as separate slices; the relevant work is folded into tickets #25–#36.
