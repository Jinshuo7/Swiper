# Orange & Porcelain — production-v1 baseline index

> **Status: incomplete baseline. Owner/supervisor handoff required.**
> The approved production-v1 visual baseline is described by
> [issue #24](https://github.com/Jinshuo7/Swiper/issues/24) and the in-repo
> [`docs/SPEC.md`](../../SPEC.md). This directory does **not** yet hold the full
> approved set. Nothing here is claimed as approved unless this index says so.

## Expected baseline roles (five frames)

The approved baseline is the five-frame Orange & Porcelain set:

| Role | File | Status |
| --- | --- | --- |
| Setup / filter direction | `01-setup.png` | Retained **direction board**; exact approved frame not verified. |
| Review direction | `03-review.png` | Retained **direction board**; exact approved frame not verified. |
| Neutral viewer — **bottom** dock | *(missing)* | **Blocker.** Not in the repository. |
| Neutral viewer — **left** dock | *(missing)* | **Blocker.** Not in the repository. |
| Neutral viewer — **right** dock | *(missing)* | **Blocker.** Not in the repository. |

**Blocker:** the three exact **neutral** viewer frames (bottom, left, right) are
missing and require owner/supervisor handoff. No substitute should be generated,
and no existing raster should be relabelled as the approved frame.

## Superseded concepts (non-targets)

* `02-viewer.png`, `02-viewer-v2.png`, `02-viewer-v3.png` are **superseded**
  historical concepts: coloured red/green controls, a visible three-dot
  **grip**, expanded slot previews and/or no media badge. They are **not**
  implementation targets. The production target is a neutral handle-free dock
  with direct whole-dock movement and a small Photo/Live/Video badge beneath
  Review (see [`docs/SPEC.md`](../../SPEC.md) §§4–5).
* `VIEWER-V2-PROMPTS.md`, `VIEWER-V3-PROMPTS.md` and `PROMPTS.md` are generation
  prompts for those superseded boards, kept as history.

## Prototype

[`PROTOTYPE.md`](PROTOTYPE.md) documents an exploratory native prototype. It has
neutral variants reachable via launch flags, but **variants and generated
screenshots are not proof of visual approval**: they have not been validated for
complete accessibility, iOS 17 material fallback, or against the owner's exact
references. Treat them as exploratory. The prototype's known differences from the
production target are listed in that file's banner.

## Reading order

[Issue #24](https://github.com/Jinshuo7/Swiper/issues/24) → [`docs/SPEC.md`](../../SPEC.md)
→ [`docs/VISION.md`](../../VISION.md) → this index. The pre-reconciliation copies
of changed design docs are archived under
[`docs/history/production-v1-reconciliation/`](../../history/production-v1-reconciliation/README.md).
