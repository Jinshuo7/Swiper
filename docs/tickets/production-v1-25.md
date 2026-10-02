# Ticket #25 — Make the production-v1 contract durable

**Status: PARTIAL — documentation pass complete; one blocked acceptance item.**
Ticket [#25](https://github.com/Jinshuo7/Swiper/issues/25) remains **open**
pending the owner/supervisor asset handoff below. This is not a claim of
acceptance.

Authoritative spec: [issue #24](https://github.com/Jinshuo7/Swiper/issues/24).
Base HEAD: `cf8e12698f745f98fee26b541744810c2b32c53a`.

## Acceptance criteria — actual status

| Criterion | Status |
| --- | --- |
| Approved setup/filter, review, bottom/left/right dock references retained as the named production baseline | **BLOCKED** — the exact **neutral** viewer frames (bottom/left/right) are not in the repository. `01-setup.png` and `03-review.png` are retained direction boards, not verified approved frames. `02-viewer*.png` are superseded grip/coloured concepts. Requires owner/supervisor handoff; no substitute fabricated. |
| Superseded concepts marked historical rather than implementation targets | **DONE** — [orange-porcelain index](../design/orange-porcelain/README.md), [flow summary](../design/2026-09-cleanup-flow.md), [PROTOTYPE.md](../design/orange-porcelain/PROTOTYPE.md) banner, TESTING historical labels, and ADRs. |
| Product docs describe ordinary video, Home media choices, editable filters, fixed non-wrapping pool, neutral viewer, direct whole-dock movement, EN/zh-Hans, App Store release as v1 | **DONE** — [SPEC.md](../SPEC.md), [VISION.md](../VISION.md), [ROADMAP.md](../ROADMAP.md), [CONTEXT.md](../../CONTEXT.md), [TESTING.md](../TESTING.md), [LOCALIZATION.md](../LOCALIZATION.md). |
| Glossary uses media-neutral domain language while preserving established meanings | **DONE** — `CONTEXT.md` reconciled (Session, Decision, Keep, Mark for deletion, Deletion list, Session-scoped Undo, Deletion review, Deletion commit, Confirmation preserved). Original archived. |
| ADRs that excluded video or required the old single-entry/grip interaction are superseded/amended; durable decisions intact | **DONE** — ADR-0003 and ADR-0008 superseded; ADR-0007 and ADR-0011 amended; ADR-0001/0002/0004/0005/0006/0009/0010 untouched. |
| Documentation identifies #24 as authoritative and contains no unresolved interview language | **PARTIAL** — #24 named authoritative throughout; the interview draft was archived and replaced with a settled summary. A repo-wide sweep for stale interview language remains. |
| Documentation and prototype checks relevant to this change pass, and the completion report names authoritative sources | **DONE (this ticket)** — `git diff --check` clean; `run-kit-tests.sh` 132/0; `typecheck-ios.sh` OK; focused `ViewerDockPrototypeTests` 1/0 on the simulator. The separate AX5 baseline failure remains release-blocking (see below). |

## Files changed by this documentation work

Existing docs reconciled (pre-existing dirty ones archived first):
`README.md`, `AGENTS.md`, `CONTEXT.md`, `docs/SPEC.md`, `docs/VISION.md`,
`docs/ROADMAP.md`, `docs/IMPLEMENTATION-STATUS.md`, `docs/LOCALIZATION.md`,
`docs/TESTING.md`, `docs/IMPLEMENTATION-PROMPT.md`,
`docs/design/DESIGN-BRIEF.md`, `docs/design/2026-09-cleanup-flow.md`,
`docs/design/orange-porcelain/README.md`,
`docs/design/orange-porcelain/PROTOTYPE.md`,
`docs/adr/0003`, `docs/adr/0007`, `docs/adr/0008`, `docs/adr/0011`.

New: `docs/history/production-v1-reconciliation/` (archive),
`docs/tickets/production-v1-25.md` (this file).

Pre-existing user-owned dirty files **not touched**: `.gitignore`,
`SWIPR/Views/ViewerDockPrototype.swift`,
`SWIPRUITests/ViewerDockPrototypeTests.swift`,
`Scripts/run-viewer-prototype.sh`, `docs/design/orange-porcelain/*.png`,
`PROMPTS.md`, `VIEWER-V2-PROMPTS.md`, `VIEWER-V3-PROMPTS.md`,
`docs/research/*`, `.lavish/`.

## Original-preservation evidence

Pre-edit bytes archived under
[`docs/history/production-v1-reconciliation/`](../history/production-v1-reconciliation/README.md),
each byte-exact to `.tmp/v1-25-start/files/<path>`:

| Archived | sha256 |
| --- | --- |
| `CONTEXT.md` | `0fc6b4575f60450921ea49b09a62c0871d871af299d30b5df26f0f314e2d9175` |
| `AGENTS.md` | `6177b0c2d6642484d2e2b0d74d868abb992b43d5c28e3e89239f00a7aace6c99` |
| `docs/TESTING.md` | `cf7a97671fb98323237cf4e3e16606c41c4b1a6dc49287b7fd53477007120295` |
| `docs/design/2026-09-cleanup-flow.md` | `74dfd7b911b08a5d4cf8625c5f01ff768e02debdbd4f046ffb6ac6adf1bf2361` |
| `docs/design/orange-porcelain/PROTOTYPE.md` | `62893cc386471ed03d84ca68cbde9a81ad15429612a1a59d297089c538a76114` |
| `docs/design/orange-porcelain/README.md` | `940b0305ca81482d7bef25727e7e06e11d3f94a993a83dc58002a3927ed4fb6b` |

## Test commands and results

| Command | Result | Log / bundle |
| --- | --- | --- |
| `git diff --check` | clean | `.tmp/v1-25-worker-diffcheck.log` |
| `DEVELOPER_DIR=… Scripts/run-kit-tests.sh` | **132 tests, 0 failures**, exit 0 | `.tmp/v1-25-worker-kittests.log` |
| `DEVELOPER_DIR=… Scripts/typecheck-ios.sh` | `OK`, exit 0 | `.tmp/v1-25-worker-typecheck.log` |
| `xcodebuild test … -only-testing:SWIPRUITests/ViewerDockPrototypeTests` | **1 test, 0 failures**, `** TEST SUCCEEDED **` | `.tmp/v1-25-worker-uitest.log`; `.derivedData-simulator/Logs/Test/Test-SWIPR-2026.10.01_20-19-30-+0800.xcresult` |

The focused UI test does **not** establish that the prototype matches the
approved neutral baseline, only that the exploratory dock does not decide on a
move. Dynamic Type/AX5 remains unverified here.

### Known release-blocking baseline failure (not this ticket)

`PlaySessionUITests.testPlayEveryScreenAtTheLargestAccessibilityTextSize` cannot
scroll `choosePhoto.newest` at AX5. It is release-blocking and must be fixed and
re-run on a named commit; no all-green suite is claimed.

## Diff identity

* HEAD: `cf8e12698f745f98fee26b541744810c2b32c53a`
* Tracked working-tree diff sha256: `ef8adf072c8d3d535f402be54c79f370ed4b322432584ed334d87995a1de37fc`
* Untracked additions: `docs/tickets/production-v1-25.md`
  (`fbf83623cd20b5799150b7014a2bd551eccbd8807400668cf4e6f220a2c96d8f`),
  `docs/history/production-v1-reconciliation/README.md`
  (`f8c2eb3cfbf8285b52ad1e8db82749346d7859eceee26d1687e7186dbbbb9c70`),
  and the other new design/archive files listed above.
* No staging, commit or push performed.

## Human / owner gates

* **Asset handoff (blocking):** exact approved neutral bottom/left/right viewer
  references, plus confirmation of the setup/filter and review frames.
* **Localization:** a fluent human must review Simplified Chinese before release
  (agent may draft the first pass).
* **Final icon:** owner approves the rendered asset before submission.
* **Release:** manual after App Review, from the exact tested release-candidate
  commit.

## Authoritative read order

1. [Issue #24](https://github.com/Jinshuo7/Swiper/issues/24).
2. [`docs/SPEC.md`](../SPEC.md) — target contract, not as-built.
3. [`docs/IMPLEMENTATION-STATUS.md`](../IMPLEMENTATION-STATUS.md) — required vs. built, AX5 blocker.
4. [`docs/VISION.md`](../VISION.md), [`docs/ROADMAP.md`](../ROADMAP.md).
5. [`CONTEXT.md`](../../CONTEXT.md), [`docs/adr/`](../adr).
6. [`docs/design/orange-porcelain/README.md`](../design/orange-porcelain/README.md)
   (baseline index + blocker), [`docs/TESTING.md`](../TESTING.md),
   [`docs/LOCALIZATION.md`](../LOCALIZATION.md).
7. Archived originals: [`docs/history/production-v1-reconciliation/`](../history/production-v1-reconciliation/README.md)
   (historical, non-normative; archived relative links may be inert).
