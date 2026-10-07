# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Owner workflow (mandatory)

All agents must follow [`docs/agents/OWNER-INSTRUCTIONS.md`](docs/agents/OWNER-INSTRUCTIONS.md).

## Build and test

- Xcode 27.x, iOS deployment target 17.0. The scheme is `SWIPR`; the project is
  `SWIPR.xcodeproj`.
- If the global developer directory points at Command Line Tools, use
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on commands rather
  than changing the machine selection.
- `xcode-select -p` still points at Command Line Tools, so prefix `xcodebuild`
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Verified working 2026-09-27: Xcode 27.0 with the iOS 27.0 arm64 Simulator
  runtime. The dedicated `SWIPR iPhone 11 Pro` simulator has UDID
  `71EAC83D-54D4-451A-AB32-74A8878C7869`. The full simulator run executes all
  targets without signing or a phone.
  The former AX5 Choose a photo scroll in
  `testPlayEveryScreenAtTheLargestAccessibilityTextSize` was fixed by #58 and is
  no longer skipped in CI (#69). See
  `docs/TESTING.md` for the command and result bundle.
- Xcode 27 shows simulators in `Device Hub`, not a standalone `Simulator.app`.
  Open `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` and select
  `SWIPR iPhone 11 Pro` for a remotely controllable device window.
- Running the device suite from a sandboxed agent session needs **full file
  access**. Xcode launches the test host through a pseudo-terminal, so a
  restricted sandbox fails before any test runs with
  `IDEPseudoTerminalDomain … ErrorCode: 7 Errno: 1 (Operation not permitted)`.
  With full access the whole suite runs green on the connected iPhone.
- A **locked** iPhone makes a device run wait in silence
  (`deviceprep Code=-3 "Unlock iPhone to Continue"`), and `devicectl` cannot
  report the lock state. Ask the owner to unlock the phone before starting a
  device run, and kill and ask again if that error appears.
- Device builds sign with the personal team and the bundle id in
  `Scripts/generate_project.rb`. Changing that id needs a provisioning profile for
  the new id, and only a signed-in Xcode account can create one: from a sandboxed
  `xcodebuild`, a new id fails with `No Accounts`, while an id that already has a
  cached profile builds with no account involved. Managed profiles live in
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. To prove the code
  compiles without touching signing, add `CODE_SIGNING_ALLOWED=NO`. Personal-team
  profiles expire after 7 days. A free profile also caps how many apps can be
  installed at once: after a bundle-id change the old app and its UI-test runner
  still hold slots, and the new UI runner then fails to install with "This device
  has reached the maximum number of installed apps using a free developer
  profile". Clear the superseded ids with `xcrun devicectl device uninstall app`
  before re-running the UI suite.
- Raw-compiler fallbacks when `xcodebuild` is unavailable:
  `Scripts/run-kit-tests.sh` (macOS) and `Scripts/typecheck-ios.sh` (iOS check).
- Inside a restricted (agent-harness) sandbox, two extra flags are required, or
  every SwiftUI `@State` fails with "external macro implementation type
  'SwiftUIMacros.StateMacro' could not be found … produced malformed response":
  `-Xfrontend -disable-sandbox` (the macro plugin server cannot apply its own
  nested sandbox) and `-derivedDataPath ./.derivedData` (the default
  `~/Library/Developer/Xcode/DerivedData` is outside the writable workspace).
  For `xcodebuild` pass the flag via
  `OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'`.
  `Scripts/typecheck-ios.sh` already sets it.
- After adding, renaming or deleting source files, run
  `ruby Scripts/generate_project.rb` and commit `SWIPR.xcodeproj`.

## Architecture

- `SWIPRKit/` is a Foundation-only framework holding all decision logic:
  ordering, the deletion list, undo, Tumbler, preferences, statistics, stored
  state and migration, stale-asset reconciliation and photo-fit geometry. Keep
  PhotoKit and UIKit out of it.
- `SWIPR/` is the app. `PhotoKitLibrary` implements the framework protocols;
  `AppModel` performs the `SessionEffect` values the pure `SessionEngine` emits.
  Views are in `SWIPR/Views/`.
- The engine never mutates the library. Deleting happens only in
  `AppModel.confirmDeletion()` after an explicit user confirmation, and only
  confirmed deletions update statistics.
- The deletion list outlives sorting sessions (`docs/adr/0005`). `AppModel`
  stages a decision, saves it, and only then acknowledges and advances; a failed
  save parks a `PendingDecision` and offers Retry (`docs/adr/0004`).
- Test seams: `SWIPRKitTests` for pure logic on macOS, `SWIPRAppTests` for
  `AppModel` against `FakePhotoLibrary` + `InMemorySessionStore` (which can fail
  writes or hold unreadable/newer-version data), `SWIPRUITests` for the real UI
  with `-uiTestingFakeLibrary`.

## Safety

- Automated tests must never touch a real photo library. Unit tests use
  `SWIPRKit` fakes; UI tests launch with `-uiTestingFakeLibrary`, which swaps in
  `FakePhotoLibrary`.
- Do not add private APIs or Key-Value Coding file-size tricks. Storage is an
  estimate; see `SWIPRKit/StorageEstimate.swift` and `docs/adr/0002`.
- Agents never remove the `needs-strong-review` label. Under the delegated
  approval above, the agent may add `strong-review-passed` and merge only when
  every condition holds; otherwise only the owner does. The `strong-review` workflow
  flags any PR that touches a path in `.github/risky-paths.txt`.
- Agents must never weaken `.github/workflows/strong-review.yml`. Any PR that
  changes that file or `.github/risky-paths.txt` must say so at the top of its
  pull-request description.

## Full autonomy until V1 (owner directive)

The owner has delegated approval decisions for the rest of V1 (milestones
#26–#36). Work without asking for approval. Stop only when (a) V1 is
code-complete and all checks are green on `main`, or (b) the only work left
needs the owner: an Apple Developer account, App Store Connect, signing, the
final icon, a native Chinese review, or a real-device test. When stopping, open a
GitHub issue titled "Owner: V1 ready" or "Owner: action needed" that @mentions
@Jinshuo7, in plain non-technical language.

Never sit idle on one PR: keep working on any ticket that does not depend on it.
If Codex does not respond (rate limits), keep working and retry hourly; never
merge a risky PR without a Codex review of its exact head. Flaky tests get a
ticket and a root-cause fix; skipping is never allowed.

Rules that never change: photos are deleted only through the iOS system
confirmation, after the in-app Review confirmation; never weaken, skip or delete
tests, CI, `.github/risky-paths.txt` or the strong-review gate; never force-push;
never work in the owner's folder; PR #37 stays prohibited.

## Risky PR review workflow (`needs-strong-review`)

Applies to any PR the strong-review gate labels `needs-strong-review`.

1. When its checks are green, comment exactly `@codex review` with
   `gh pr comment`.
2. Wait for Codex's review: poll every 5 minutes with `gh pr view --comments`,
   `gh api repos/Jinshuo7/Swiper/pulls/<n>/reviews`, and `.../comments`. If Codex
   does not respond, keep working elsewhere and retry hourly.
3. If Codex reports problems, fix them in the same PR, push without force, wait
   for green checks, then comment `@codex review` again. Up to **5 rounds** per
   PR.
4. If a **P1** remains after 5 rounds, leave the PR open, add the
   `owner-blocked` label, and move on. Revisit later with a fresh approach.
   Never merge with an open P1.
5. **Delegated approval.** The owner has delegated `strong-review-passed` to the
   agent. Add it and merge (`--match-head-commit`, full SHA) only when ALL hold:
   checks green on the current head; a Codex review of that exact head reports
   **no P1**; no test, workflow, `risky-paths.txt` or gate was removed, skipped,
   weakened or loosened. P2 findings: fix quick ones, otherwise open a follow-up
   ticket and merge.
6. Never comment `@codex` with anything other than `review`. Only the agent
   writes code.

## Code Review Rules

Codex reviews must flag, as blocking:

- anything that can delete a photo without the explicit user confirmation step;
- anything that can add an unmarked photo to, or drop a marked photo from, the
  deletion list;
- anything that can lose or overwrite saved progress, marks, Undo, or Tumbler
  state;
- unsafe save-format migration;
- any test that is removed, skipped, loosened, or otherwise weakened.

## Localisation

- English only, deliberately: no String Catalog exists yet, so nothing is
  half-migrated. `docs/LOCALIZATION.md` has the inventory, the blockers and the
  plan; read it before touching copy.
- The blocker to know up front: a large share of user-facing copy lives in
  `SWIPRKit` (`DeletionWording`, rail and preset titles, error descriptions), so
  it needs the framework's own catalog and `bundle: .module` lookups, not just an
  app catalog.
- `Scripts/check_localizations.sh` fails if any catalog key lacks a `zh-Hans`
  value. Run it once catalogs exist.

## Documentation

Production v1 is specified by [issue #24](https://github.com/Jinshuo7/Swiper/issues/24);
the in-repo target contract is `docs/SPEC.md`, and `docs/IMPLEMENTATION-STATUS.md`
separates required v1 from as-built legacy. Keep `docs/VISION.md`, `docs/SPEC.md`,
`docs/ROADMAP.md`, `docs/TESTING.md`, `docs/LOCALIZATION.md` and `docs/adr/` in
sync with behaviour; the glossary is `CONTEXT.md`; the visual baseline index is
`docs/design/orange-porcelain/README.md`. English-only is the current as-built
state while bilingual EN/zh-Hans is a v1 requirement.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `Jinshuo7/Swiper` (use the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
