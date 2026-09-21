# Implementation status checkpoint

Durable resume point for the autonomous implementation of GitHub issues #11–#16
(parent spec #10). Read this together with `docs/IMPLEMENTATION-PROMPT.md`,
`docs/specs/photo-cleaning-redesign.md` and the active issue on GitHub.

## Current ticket

**#11 — Bound the viewer and show complete photos** (in progress).

## Baseline (before any change)

- `git status`: `CONTEXT.md` and `SwiperUITests/SwiperUITests.swift` modified
  (pre-existing intentional work: glossary wording + preliminary red UI tests);
  untracked `docs/IMPLEMENTATION-PROMPT.md`, `docs/research/`, `docs/specs/`,
  `docs/tickets/`. Nothing stashed or discarded.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh`
  → **66 tests, 0 failures** (exit 0).
- Device: iPhone 11 Pro `00008030-000669DE3408802E`, `booted`, paired.

## Environment notes (learned this session)

- The DSH file sandbox is `workspace-write`; `xcodebuild` writing to the default
  `~/Library/Developer/Xcode/DerivedData` is denied. Always pass
  `-derivedDataPath ./.derivedData` (and `-resultBundlePath` under the workspace
  when capturing xcresults).
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` must prefix Xcode
  commands; `xcode-select -p` still points at Command Line Tools.

## Completed changes

_(none yet)_

## Commits

_(none yet)_

## Blockers

- None so far. Physical-device UI validation depends on the phone staying
  connected and unlocked; every device check is reported exactly as run.

## Exact next steps

1. Finish #11: bound the photo canvas with a pure `PhotoLayout` fit helper,
   keep controls inside the safe area, drop the permanent hint text.
2. Fix fake-library fixtures to portrait/landscape/square/panorama with edge
   markers; regress cropping and offscreen controls.
3. Run `Scripts/run-kit-tests.sh`, `Scripts/typecheck-ios.sh` and the device
   suites; commit; comment on #11.
