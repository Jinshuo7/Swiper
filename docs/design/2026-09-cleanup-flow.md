# Cleanup flow — settled production-v1 design summary

> **Settled.** The design interview is closed. The decisions below are captured
> normatively in [issue #24](https://github.com/Jinshuo7/Swiper/issues/24) and
> [`docs/SPEC.md`](../SPEC.md); if anything here disagrees with them, #24 wins.
> The original interview draft (rounds 1–8, owner feedback, open questions) is
> archived at
> [`docs/history/production-v1-reconciliation/docs/design/2026-09-cleanup-flow.md`](../history/production-v1-reconciliation/docs/design/2026-09-cleanup-flow.md)
> as historical context only.

## Settled flow

Home → editable filters → starting-point grid → sorting (photos, Live Photos,
ordinary videos) → deletion review → system-confirmed deletion → result /
Your impact.

## Visual direction

**Orange & Porcelain** identity for the app surfaces (light background `#F8F8F6`,
surface `#FFFFFF`, accent `#C05A20`, ink `#272724`; dark background `#191A18`,
surface `#2C2D29`, accent `#F2A66B`), around a deliberately **neutral,
media-led viewer**. Red/green survive only as extremely faint desaturated edge
illumination; symbols, wording, stroke and weight carry meaning. See
[`docs/SPEC.md`](../SPEC.md) §4.

## Settled decisions

* **Home** offers Everything / Photos / Videos, each opening editable filters;
  Continue sorting and Review marked items are distinct; Your impact is quiet and
  conditional.
* **Filter pool** is editable before a session and **fixed at creation**;
  exclusions win on overlap; every item appears once.
* **Starting point** supports Newest first / Oldest first, month jump, a specific
  item, and Random (Tumbler); traversal **completes without wrapping**.
* **Replacement session** requires confirmation naming what is replaced (position
  and Undo) and what survives (marks).
* **Viewer** fits the complete asset at original aspect ratio; chrome floats and
  never resizes or crops the media; a small neutral Photo/Live/Video badge sits
  beneath Review.
* **Decision dock** has exactly three fixed positions and is moved by **direct
  whole-dock dragging** into a neutral token (no grip, no long press); Before
  actions / After actions describes Undo.
* **Video** starts muted on request, never autoplays, has a seek-only timeline,
  and pauses/resumes around sorting gestures; Skip records no decision.
* **Deletion review** mixes photos and videos; deletion happens only there, only
  after the system confirmation; confirmed-only statistics.
* **Appearance / accessibility / languages**: System/Light/Dark with an iOS 17
  fallback; full accessibility contract; complete English and Simplified Chinese.

The full, authoritative statement — including numeric interaction tuning and the
App Store release gate — is in [`docs/SPEC.md`](../SPEC.md) and issue #24.
