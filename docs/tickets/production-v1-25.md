# Ticket #25 — Make the production-v1 contract durable

**Status: COMPLETE — approved baseline retained and required checks pass.**
Ticket [#25](https://github.com/Jinshuo7/SWIPR/issues/25) remains **open** for
owner review and merge.

Authoritative spec: [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24).
Base HEAD: `deeb8179ce2a12a2c7013ee3c0abc6016e863187`.

## Acceptance criteria — actual status

| Criterion | Status |
| --- | --- |
| Approved setup/filter, review, bottom/left/right dock references retained as the named production baseline | **DONE** — the five owner-approved files and their hashes are recorded below and in the [orange-porcelain index](../design/orange-porcelain/README.md). |
| Superseded concepts marked historical rather than implementation targets | **DONE** — [orange-porcelain index](../design/orange-porcelain/README.md), [flow summary](../design/2026-09-cleanup-flow.md), [PROTOTYPE.md](../design/orange-porcelain/PROTOTYPE.md) banner, TESTING historical labels, and ADRs. |
| Product docs describe ordinary video, Home media choices, editable filters, fixed non-wrapping pool, neutral viewer, direct whole-dock movement, EN/zh-Hans, App Store release as v1 | **DONE** — [SPEC.md](../SPEC.md), [VISION.md](../VISION.md), [ROADMAP.md](../ROADMAP.md), [CONTEXT.md](../../CONTEXT.md), [TESTING.md](../TESTING.md), [LOCALIZATION.md](../LOCALIZATION.md). |
| Glossary uses media-neutral domain language while preserving established meanings | **DONE** — `CONTEXT.md` reconciled (Session, Decision, Keep, Mark for deletion, Deletion list, Session-scoped Undo, Deletion review, Deletion commit, Confirmation preserved). Original archived. |
| ADRs that excluded video or required the old single-entry/grip interaction are superseded/amended; durable decisions intact | **DONE** — ADR-0003 and ADR-0008 superseded; ADR-0007 and ADR-0011 amended; ADR-0001/0002/0004/0005/0006/0009/0010 untouched. |
| Documentation identifies #24 as authoritative and contains no unresolved interview language | **DONE** — #24 is named authoritative throughout; the archived interview remains historical, and the movable-controls research now explicitly marks its former open questions as superseded. Procedural instructions such as asking the owner to unlock a test phone remain current, not product questions. |
| Documentation and prototype checks relevant to this change pass, and the completion report names authoritative sources | **DONE** — `git diff --check` is clean, all 132 kit tests pass, and the iOS app typecheck reports `OK`. The separate AX5 baseline failure remains release-blocking (see below). |

## Approved visual-reference hashes

All five files were supplied by the owner through chat and approved on
2026-10-01. The setup and review attachments were byte-identical to the existing
repository files; the three neutral viewer references were added byte-for-byte.

| Role | File | SHA-256 | Dimensions |
| --- | --- | --- | --- |
| Setup / filters | `docs/design/orange-porcelain/01-setup.png` | `9f3a4402f33d7358dff80c71ad51dcb9895e3f17d3b8081c7e9c9c4442426118` | 1536×1024 |
| Review / results | `docs/design/orange-porcelain/03-review.png` | `67f1f17ae02b9d9831e019c1e862dccfd4ffacf39553974daaf5dcc1bb041b04` | 1536×1024 |
| Neutral viewer — bottom dock | `docs/design/orange-porcelain/04-viewer-bottom-neutral.png` | `19b92f48d5b73c175c8f9e0fb5a4d2b537c7d26e9c1a73ea2c273de05d180c34` | 1125×2436 |
| Neutral viewer — left dock | `docs/design/orange-porcelain/05-viewer-left-neutral.png` | `d64dce2c287e9831fc8e28b66a34a4e7229d4ddd528d589a1cea69a23191a4f2` | 1125×2436 |
| Neutral viewer — right dock | `docs/design/orange-porcelain/06-viewer-right-neutral.png` | `7d5496bed79775d02dc2dbf8989ab672bfa7807ec520ce507e1fc4ad9449dc64` | 1125×2436 |

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

This completion pass adds the three approved neutral viewer PNGs, updates the
orange-porcelain index, and marks stale open-question wording in
`docs/research/movable-controls.md` as superseded.

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
| `git diff --check` | clean, exit 0 | Current completion run |
| `DEVELOPER_DIR=… Scripts/run-kit-tests.sh` | **132 tests, 0 failures**, exit 0 | Current completion run |
| `DEVELOPER_DIR=… Scripts/typecheck-ios.sh` | `OK`, exit 0 | Current completion run |
| `xcodebuild test … -only-testing:SWIPRUITests/ViewerDockPrototypeTests` | **1 test, 0 failures**, `** TEST SUCCEEDED **` | Earlier documentation pass; not rerun because this completion pass changes documentation and reference images only. |

The focused UI test does **not** establish that the prototype matches the
approved neutral baseline, only that the exploratory dock does not decide on a
move. Dynamic Type/AX5 remains unverified here.

### Known release-blocking baseline failure (not this ticket)

`PlaySessionUITests.testPlayEveryScreenAtTheLargestAccessibilityTextSize` cannot
scroll `choosePhoto.newest` at AX5. It is release-blocking and must be fixed and
re-run on a named commit; no all-green suite is claimed.

## Earlier documentation-pass evidence

The earlier uncommitted reconstruction evidence was captured by snapshot commit
`deeb8179ce2a12a2c7013ee3c0abc6016e863187`. This branch adds only the approved
visual baseline and the documentation updates listed above.

## Human / owner gates

* **Localization:** a fluent human must review Simplified Chinese before release
  (agent may draft the first pass).
* **Final icon:** owner approves the rendered asset before submission.
* **Release:** manual after App Review, from the exact tested release-candidate
  commit.

## Authoritative read order

1. [Issue #24](https://github.com/Jinshuo7/SWIPR/issues/24).
2. [`docs/SPEC.md`](../SPEC.md) — target contract, not as-built.
3. [`docs/IMPLEMENTATION-STATUS.md`](../IMPLEMENTATION-STATUS.md) — required vs. built, AX5 blocker.
4. [`docs/VISION.md`](../VISION.md), [`docs/ROADMAP.md`](../ROADMAP.md).
5. [`CONTEXT.md`](../../CONTEXT.md), [`docs/adr/`](../adr).
6. [`docs/design/orange-porcelain/README.md`](../design/orange-porcelain/README.md)
   (approved visual baseline index), [`docs/TESTING.md`](../TESTING.md),
   [`docs/LOCALIZATION.md`](../LOCALIZATION.md).
7. Archived originals: [`docs/history/production-v1-reconciliation/`](../history/production-v1-reconciliation/README.md)
   (historical, non-normative; archived relative links may be inert).
