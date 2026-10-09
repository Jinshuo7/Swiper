# SWIPR

> **Production-v1 status.** The current target is **photos, Live Photos and
> ordinary videos** with Home + editable filters, a neutral whole-dock viewer,
> fixed non-wrapping sessions, complete English + Simplified Chinese, and an App
> Store release. [Issue #24](https://github.com/Jinshuo7/Swiper/issues/24) is
> authoritative; read [`docs/SPEC.md`](docs/SPEC.md) and
> [`docs/IMPLEMENTATION-STATUS.md`](docs/IMPLEMENTATION-STATUS.md) (as-built vs.
> required). The body of this README describes the **legacy photo-only build**
> and is kept as as-built history.

A minimal iOS photo-cleaning app. One complete photo fills the screen; a swipe or
a nearby button decides its fate. Nothing is deleted while you swipe — marked
photos go to a review screen and are only removed after an explicit final
confirmation. The deletion list outlives the session, decisions are saved before
they are acknowledged, and a save failure is shown with a Retry rather than
hidden.

For the product vision, glossary, behaviour and decisions, start with
[`docs/VISION.md`](docs/VISION.md), [`CONTEXT.md`](CONTEXT.md),
[`docs/SPEC.md`](docs/SPEC.md) and [`docs/adr/`](docs/adr).

## Requirements

* macOS with Xcode 26 or later installed.
* iOS 17.0 or later on the target device.
* [xcodeproj](https://github.com/CocoaPods/Xcodeproj) Ruby gem **only** if you
  change the file layout and regenerate the project:
  `gem install --user-install xcodeproj`.

## Repository layout

```
SWIPR.xcodeproj          Generated, committed Xcode project and shared scheme
SWIPRKit/                Pure-Swift logic framework (Foundation only, tested)
SWIPR/                   The iOS app: PhotoKit, SwiftUI views, app model
SWIPRKitTests/           Unit tests for SWIPRKit (also runnable on macOS)
SWIPRAppTests/           AppModel integration tests against fakes
SWIPRUITests/            UI tests against an in-memory fake library
Scripts/                  Project generation and no-xcodebuild fallback scripts
docs/                     Vision, spec, roadmap and ADRs
```

The logic lives in `SWIPRKit` and has no PhotoKit or UIKit dependency, so it
builds and runs on macOS. `SWIPR` implements the
`PhotoLibraryProviding`/`AssetImageProviding` protocols from that framework
using PhotoKit.

## Opening the project

```sh
open SWIPR.xcodeproj
```

The committed project already contains every source file. If you add, rename or
delete files, regenerate it:

```sh
ruby Scripts/generate_project.rb
```

## Xcode setup notes

The global developer directory on this Mac points at Command Line Tools. Prefer
exporting Xcode explicitly over changing the machine-wide selection:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

`xcodebuild` and `xcrun simctl` additionally require the Xcode licence to be
accepted for the current user and an installed iOS platform. If a build reports
`iOS ... is not installed`, install the simulator runtime once (about 8.5 GB):

```sh
xcodebuild -downloadPlatform iOS
```

If `xcodebuild` reports that the licence has not been agreed (needs an admin
password, one time):

```sh
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch           # installs/repairs Xcode's system components
```

On this machine all three are already satisfied (verified 2026-09-20); only the
`DEVELOPER_DIR` prefix is still needed. If they are ever missing, the raw
compiler inside `Xcode.app` still works, which is why the fallback scripts below
exist.

## Building and running

The iOS Simulator runtime was removed from this machine to save disk, so device
and UI work happens on a connected iPhone. In Xcode, pick the `SWIPR` scheme and
your device and press ⌘R.

If you do have a Simulator runtime, the equivalent command is:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Do not experiment on a real library first. Add a handful of disposable photos
(and one Live Photo and one ordinary video) with `xcrun simctl addmedia booted …`
on a Simulator, or use a throwaway test device.

### Running from a restricted sandbox

If commands run inside an agent-harness sandbox, two extra flags are needed or
every SwiftUI `@State` fails to expand its macro:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build-for-testing -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
```

`Scripts/typecheck-ios.sh` already passes `-Xfrontend -disable-sandbox`.

## Running on a physical iPhone

1. Connect the iPhone, unlock it and tap **Trust**.
2. On iOS 16+, enable **Developer Mode** in Settings ▸ Privacy & Security.
3. In Xcode, select the `SWIPR` scheme and your device.
4. Open the `SWIPR` target ▸ Signing & Capabilities, tick **Automatically
   manage signing**, and pick your Apple ID team. Change the bundle identifier
   from `com.swiper.app` if it collides (`com.yourname.SWIPR`).
5. Press ⌘R. On the phone, trust the developer certificate in
   Settings ▸ General ▸ VPN & Device Management if prompted.

### Granting photo access

On first launch SWIPR explains why it needs access and asks for read-write
library permission (read-write is required because deletion changes the
library). Choose **Allow Full Access**. You can also choose **Limit
Access**; SWIPR will show only the selected photos and offer a control to
select more. If you declined earlier, tap **Open Settings** and re-enable
access.

## Manually verifying behaviour safely

Use a throwaway library (Simulator, or a handful of disposable photos on a test
device).

**Keep / mark**

1. Tap **Start here**, then **Newest**. The first photo is shown complete, with
   both edges visible, and the one-time tutorial explains the flow. The three
   buttons sit in a tray at the bottom centre, with Undo at one end and the
   three-dot grip at the other.
2. Drag **right** past the threshold — a check well arms with a light haptic and
   the photo is kept. Drag right only a little: nothing happens.
3. Drag **left** past the threshold — a trash well arms and the photo is
   **marked**, not deleted. The round trash **Review** button appears in the
   top bar with a red count badge.
4. Tap **Undo** — the last decision of this session is reversed and you return
   to that photo.

**Deletion review and safety**

6. Mark a few photos and open review from the viewer (the round trash button in
   the top bar) or from home (the matching trash button in the top bar); review
   is reachable at any time, not only at the end. The count sits in the button's
   red badge, never in text.
7. Tap a thumbnail to inspect it full-screen; tap **Restore photo** to remove it
   from the list.
8. Tap **Select**, then drag across thumbnails to select a batch and tap
   **Restore N selected**.
9. Tap **Delete N photos**, then confirm. iOS shows its own system confirmation
   as well. Only after both confirmations are the photos removed. Cancelling
   either one leaves every mark in place and counts nothing.
10. Confirm the Photos app now shows the deleted items in **Recently Deleted**,
    and that restored photos are still present.

**Persistence, marks and recovery**

11. During a session, force-quit SWIPR mid-way and relaunch. The entry screen
    offers **Resume** at the saved position, and the round trash **Review**
    button for the marks, which survive opening Choose a photo and its other
    traversals too.
12. Marked photos are skipped while sorting. Restoring one lets a later session
    present it again.

**Moving the buttons**

13. Drag the three dots on the tray. A translucent puck follows your finger, the
    three positions appear as phantom slots and the nearest is highlighted.
    Release over a slot to move the buttons there; release anywhere else and
    nothing changes. The photo never resizes or shifts. The same choice is in
    Settings, with **Reset control position**, and **Show buttons** hides the
    tray while leaving swiping available.

**Statistics**

14. Statistics are at the top of Settings, inline and read-only. Only confirmed
    deletions are counted. Marked-then-restored photos, cancelled deletions and
    failed deletions are not.

> Automated tests never touch a real library. Unit tests exercise the pure
> `SWIPRKit` logic; UI tests launch the app with `-uiTestingFakeLibrary`, which
> swaps in an in-memory library.

## Tests

The pure-logic suite runs on macOS with no device:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
```

`SWIPRAppTests` (AppModel against the fake library and a controllable store) and
`SWIPRUITests` need a booted iOS device; there is no Simulator runtime on this
machine. See [`docs/TESTING.md`](docs/TESTING.md) for the exact commands,
results, what is currently blocked, and where screenshots are written.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -project SWIPR.xcodeproj -scheme SWIPR \
  -destination 'platform=iOS,id=<device UDID>'
```

## How storage sizes are reported

PhotoKit's public API does not expose asset byte sizes, and the private/KVC
workarounds are not App Store safe. SWIPR therefore estimates size from pixel
dimensions and media kind and always presents it as approximate. The exact
calculation lives in `SWIPRKit/StorageEstimate.swift`; the reasoning is in
[`docs/adr/0002-public-api-storage-estimates.md`](docs/adr/0002-public-api-storage-estimates.md).

## Privacy

* SWIPR requests read-write photo access only.
* All session state, preferences and statistics are stored locally in the app's
  Application Support directory.
* Nothing is uploaded. There are no accounts, analytics or cloud services.

## Regenerating the project

```sh
ruby Scripts/generate_project.rb
```
