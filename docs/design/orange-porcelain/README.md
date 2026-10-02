# Orange & Porcelain — production-v1 baseline index

> **Status: owner-approved production-v1 baseline as of 2026-10-01.**
> The approved production-v1 visual baseline is described by
> [issue #24](https://github.com/Jinshuo7/Swiper/issues/24) and the in-repo
> [`docs/SPEC.md`](../../SPEC.md). The five references below are the approved
> visual direction; issue #24 and `docs/SPEC.md` remain authoritative for
> behaviour not shown in the images.

## Expected baseline roles (five frames)

The approved baseline is the five-frame Orange & Porcelain set:

| Role | File | SHA-256 | Dimensions | Status |
| --- | --- | --- | --- | --- |
| Setup / filter direction | `01-setup.png` | `9f3a4402f33d7358dff80c71ad51dcb9895e3f17d3b8081c7e9c9c4442426118` | 1536×1024 | Owner-approved 2026-10-01. |
| Review direction | `03-review.png` | `67f1f17ae02b9d9831e019c1e862dccfd4ffacf39553974daaf5dcc1bb041b04` | 1536×1024 | Owner-approved 2026-10-01. |
| Neutral viewer — **bottom** dock | `04-viewer-bottom-neutral.png` | `19b92f48d5b73c175c8f9e0fb5a4d2b537c7d26e9c1a73ea2c273de05d180c34` | 1125×2436 | Owner-approved 2026-10-01. |
| Neutral viewer — **left** dock | `05-viewer-left-neutral.png` | `d64dce2c287e9831fc8e28b66a34a4e7229d4ddd528d589a1cea69a23191a4f2` | 1125×2436 | Owner-approved 2026-10-01. |
| Neutral viewer — **right** dock | `06-viewer-right-neutral.png` | `7d5496bed79775d02dc2dbf8989ab672bfa7807ec520ce507e1fc4ad9449dc64` | 1125×2436 | Owner-approved 2026-10-01. |

Supplied by the owner through chat; may be a resized copy. Replace with the
original export if one becomes available, and update the hash.

Bottom dock shows text labels; side docks are icon-only by design.

The small Photo/Live/Video badge beneath Review remains required by the
production-v1 contract, although it is not shown in these references.

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
