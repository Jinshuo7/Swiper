# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Build and test

- Xcode 26.x, iOS deployment target 17.0. The scheme is `Swiper`; the project is
  `Swiper.xcodeproj`.
- If the global developer directory points at Command Line Tools, use
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on commands rather
  than changing the machine selection.
- `xcodebuild`/`simctl` require the Xcode licence accepted for the current user
  (`sudo xcodebuild -license accept`, `sudo xcodebuild -runFirstLaunch`) and an
  installed iOS platform (`xcodebuild -downloadPlatform iOS`, ~8.5 GB). A build
  that reports `iOS ... is not installed` is missing the runtime, not the SDK.
  When those are unavailable, the raw compiler inside `Xcode.app` still works:
  - `Scripts/run-kit-tests.sh` builds and runs `SwiperKitTests` on macOS
    (see `docs/TESTING.md` for the exact command and pass count).
  - `Scripts/typecheck-ios.sh` compile-checks `SwiperKit` and the app for iOS.
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

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
