# Autonomous Swiper implementation handoff

## Canonical work

Repository: https://github.com/Jinshuo7/Swiper
Parent spec: https://github.com/Jinshuo7/Swiper/issues/10

Implementation issues (all labelled ready-for-agent):

| Issue | Deliverable | Blocked by |
| --- | --- | --- |
| #11 | Bound viewer; fit complete photos | None |
| #12 | Durable decisions, migration and visible recovery | None |
| #13 | Persistent marks across sessions | #12 |
| #14 | Review/deletion recovery and return to sorting | #11, #13 |
| #15 | Minimal drag feedback and replayable tutorial | #11, #12, #14 |
| #16 | Integrated verification and delivery | #13, #14, #15 |

GitHub issues include native blocking links and are sub-issues of #10. Read their
full bodies/comments before work. Local reference copies: the consolidated spec
in docs/specs/photo-cleaning-redesign.md and docs/tickets/01-redesign.md through
06-redesign.md. GitHub is authoritative if later discussion changes requirements.

## Paste into a fresh implementation-agent session in this repository

GO: Implement Swiper spec #10 by completing issues #11–#16 sequentially in that
order. Read AGENTS.md, docs/agents configuration and applicable skills first,
then CONTEXT.md and relevant ADRs. Fetch full spec/tickets/comments from GitHub
using the gh-axi skill. This handoff replaces the earlier mistaken two-spec,
two-ticket draft. Do not execute the unrelated old backlog #1–#9.

Use ONE implementation agent. Optional read-only review delegation is fine, but
no competing agents editing engine/AppModel/views. No further product interviews:
make conservative decisions within the agreed spec. Do not add speculative
abstractions or dependencies. Do not stop after making another plan.

Inspect git status/diff first. Preserve pre-existing work, including intentional
red UI tests and glossary/research changes. The red tests are preliminary and
contain provisional labels/identifiers; refine them to test agreed external
behavior. Never blindly reset/stash or stage unrelated edits. Start an isolated
feature branch if appropriate; retain existing intentional work.

For each issue: read all affected callers, reproduce the bug/write meaningful
failing checks, implement the smallest coherent fix, run focused checks, inspect
the diff, update relevant docs, and commit intentional changes locally. Comment
on that implementation issue with commit, actual checks and remaining gaps. Close
only a fully satisfied implementation issue; do not close or modify parent #10
or old issues #1–#9. Prior #1 schema-versioning and #8 ADR work overlap the new
scope: inspect and explain the overlap, don't treat obsolete constraints as new
requirements. Do not do the old mandatory three-controller refactor in #6.

Maintain docs/IMPLEMENTATION-STATUS.md as a compact durable checkpoint: current
issue, decisions, commits, exact check commands/results, blockers and next action.
Use it to resume after context compaction. Continue until the scoped work is done,
or genuinely blocked by physical access/credentials or a data-safety ambiguity.
Finish independent work before stopping; avoid repeatedly waiting on a locked phone.

Safety: automated tests must NEVER access the real photo library. All UI tests
launch with -uiTestingFakeLibrary; use fake libraries and temporary directories
elsewhere. No phone passcode changes, lock bypass, simulator installation, global
Xcode selection changes, user-data deletion, remote push, or app publication.

Use DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer for Xcode commands.
Discover the physical iPhone with xcrun devicectl list devices. Use Swiper.xcodeproj,
Swiper scheme, platform=iOS,id=<UDID>, and provisioning updates if needed.
A locked phone cannot run UI tests. Bound readiness waits and capture the exact
failure. Continue with Scripts/run-kit-tests.sh, Scripts/typecheck-ios.sh and
build-for-testing where possible. Mac Designed-for-iPad does not support the UI
tests. Simulator runtime was removed for storage reasons; do not reinstall it.

Validation must cover migration, failed save/retry, restart, cross-session marks,
Undo, restore, cancellation/partial deletion and effect-boundary recovery. The
primary integration seam is AppModel operations with fake library and controllable
persistence; reuse pure framework tests rather than adding unnecessary new seams.
Correct the fake-image fixtures to represent real aspect ratios and edge markers.
Capture AND visually inspect fake-library screenshots of photo bounds, controls,
tutorial, drag states, review and settings. Passing smoke tests isn't proof of
visual correctness. Record unavailable real Live Photo/manual checks separately.

Run full feasible suites after integration. If a device check is blocked, leave it
explicitly pending and don't close its issue as verified. Later independent local
work may continue, but don't pretend native blockers or acceptance criteria passed.

Keep Foundation-only SwiperKit, iOS 17 compatibility, public APIs and explicit
review confirmation. Never promise impossible crash-proof guarantees. Atomic local
writes do not make PhotoKit and storage one transaction; handle recovery explicitly.
When adding/removing/renaming sources, regenerate the project with the existing
Ruby generator and include it. Sync SPEC, VISION, ROADMAP, TESTING and glossary;
record cross-session deletion lifetime as an ADR.

Finish with commits, passed checks, screenshot locations, unverified cases and
remaining risks. Leave reviewer-ready code and local commits, not a prototype.
Do not push. Astra will perform the final correctness and screenshot review.

## Starting the session

Select the desired implementation model in a fresh context opened at this repo,
then paste: “Read docs/IMPLEMENTATION-PROMPT.md and execute its autonomous handoff.”
No /go or /goal command is required; this file doesn't install either command.
The harness must remain running with tool permissions. Physical-device validation
still requires the trusted phone connected and unlocked; no prompt bypasses that.
