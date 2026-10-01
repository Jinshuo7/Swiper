# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

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
  targets without signing or a phone; 215 of 216 tests pass. The reproducible
  exception is the AX5 Choose a photo scroll in
  `testPlayEveryScreenAtTheLargestAccessibilityTextSize`. See
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

Keep these in sync with behaviour: `docs/VISION.md`, `docs/SPEC.md`,
`docs/ROADMAP.md`, and `docs/adr/`. The glossary is `CONTEXT.md`.

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
