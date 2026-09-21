# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Build and test

- Xcode 27.x, iOS deployment target 17.0. The scheme is `Swiper`; the project is
  `Swiper.xcodeproj`.
- If the global developer directory points at Command Line Tools, use
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on commands rather
  than changing the machine selection.
- `xcode-select -p` still points at Command Line Tools, so prefix `xcodebuild`
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Verified working 2026-09-20: Xcode 27.0, licence accepted. The iOS Simulator
  runtime was removed to save disk; the full suite runs on a connected iPhone:
  `xcodebuild test -project Swiper.xcodeproj -scheme Swiper -destination 'platform=iOS,id=<UDID>'`
  → 66 `SwiperKitTests` + 4 `SwiperUITests`, all green (see `docs/TESTING.md`).
- Device builds sign with the personal team and a unique app bundle id set in
  `Scripts/generate_project.rb`; `com.swiper.app` is globally taken, so it cannot
  be registered. Personal-team provisioning profiles expire after 7 days.
- Raw-compiler fallbacks when `xcodebuild` is unavailable:
  `Scripts/run-kit-tests.sh` (macOS) and `Scripts/typecheck-ios.sh` (iOS check).
- After adding, renaming or deleting source files, run
  `ruby Scripts/generate_project.rb` and commit `Swiper.xcodeproj`.

## Architecture

- `SwiperKit/` is a Foundation-only framework holding all decision logic:
  ordering, the deletion queue, undo, Tumbler, preferences, statistics and
  stale-asset reconciliation. Keep PhotoKit and UIKit out of it.
- `Swiper/` is the app. `PhotoKitLibrary` implements the framework protocols;
  `AppModel` performs the `SessionEffect` values the pure `SessionEngine`
  emits. Views are in `Swiper/Views/`.
- The engine never mutates the library. Deleting happens only in
  `AppModel.confirmDeletion()` after an explicit user confirmation, and only
  confirmed deletions update statistics.

## Safety

- Automated tests must never touch a real photo library. Unit tests use
  `SwiperKit` fakes; UI tests launch with `-uiTestingFakeLibrary`, which swaps in
  `FakePhotoLibrary`.
- Do not add private APIs or Key-Value Coding file-size tricks. Storage is an
  estimate; see `SwiperKit/StorageEstimate.swift` and `docs/adr/0002`.

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
