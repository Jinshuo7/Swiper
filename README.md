# Swiper

A minimal iOS photo-cleaning app. One photo fills the screen; a swipe or a
nearby button decides its fate. Nothing is deleted while you swipe — queued
photos go to a review screen and are only removed after an explicit final
confirmation.

For the product vision, glossary, behaviour and decisions, start with
[`docs/VISION.md`](docs/VISION.md), [`CONTEXT.md`](CONTEXT.md),
[`docs/SPEC.md`](docs/SPEC.md) and [`docs/adr/`](docs/adr).

## Requirements

* macOS with Xcode 26.x installed.
* iOS 17.0 or later on the target device.
* [xcodeproj](https://github.com/CocoaPods/Xcodeproj) Ruby gem **only** if you
  change the file layout and regenerate the project:
  `gem install --user-install xcodeproj`.

## Repository layout

```
Swiper.xcodeproj          Generated, committed Xcode project and shared scheme
SwiperKit/                Pure-Swift logic framework (Foundation only, tested)
Swiper/                   The iOS app: PhotoKit, SwiftUI views, app model
SwiperKitTests/           Unit tests for SwiperKit
SwiperUITests/            UI smoke tests against an in-memory fake library
Scripts/                  Project generation and no-xcodebuild fallback scripts
docs/                     Vision, spec, roadmap and ADRs
```

The logic lives in `SwiperKit` and has no PhotoKit or UIKit dependency, so it
builds and runs on macOS. `Swiper` implements the
`PhotoLibraryProviding`/`AssetImageProviding` protocols from that framework
using PhotoKit.

## Opening the project

```sh
open Swiper.xcodeproj
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

## Building and running in the Simulator

Once the two machine fixes above are done:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or press ⌘R in Xcode with the `Swiper` scheme and a Simulator destination.

### Seeding disposable test photos

Do not experiment on a real library first. Seed throwaway photos:

```sh
xcrun simctl boot "iPhone 17 Pro"      # or pick another available device
open -a Simulator
# Add one or more disposable images:
xcrun simctl addmedia booted /path/to/test-photo-1.jpg /path/to/test-photo-2.jpg
```

Also try a Live Photo and a short video to confirm only the still/Live assets
appear.

## Running on a physical iPhone

1. Connect the iPhone, unlock it and tap **Trust**.
2. On iOS 16+, enable **Developer Mode** in Settings ▸ Privacy & Security.
3. In Xcode, select the `Swiper` scheme and your device.
4. Open the `Swiper` target ▸ Signing & Capabilities, tick **Automatically
   manage signing**, and pick your Apple ID team. Change the bundle identifier
   from `com.swiper.app` if it collides (`com.yourname.Swiper`).
5. Press ⌘R. On the phone, trust the developer certificate in
   Settings ▸ General ▸ VPN & Device Management if prompted.

### Granting photo access

On first launch Swiper explains why it needs access and asks for read-write
library permission (read-write is required because favoriting and deletion both
change the library). Choose **Allow Full Access**. You can also choose **Limit
Access**; Swiper will show only the selected photos and offer a control to
select more. If you declined earlier, tap **Open Settings** and re-enable
access.

## Manually verifying behaviour safely

Use a throwaway library (Simulator, or a handful of disposable photos on a test
device).

**Keep / delete queue / favorite**

1. Enter with **Recent**.
2. Swipe **right** — the photo is kept and the next appears.
3. Swipe **left** — the photo is queued. It is **not** deleted yet.
4. Tap the heart — the photo is favorited in the Photos app,
   kept, and the next appears.
5. Tap **Undo** — the last decision is reversed and you return to that photo.

**Deletion review and safety**

6. Queue a few photos, finish reviewing the session, then open the final
   deletion review.
7. Tap a thumbnail to inspect it full-screen; tap **Restore photo** to remove
   it from the queue.
8. Tap **Select**, then drag across thumbnails to select a batch and tap
   **Restore N selected**.
9. Tap **Delete N photos**, then confirm. iOS shows its own system confirmation
   as well. Only after both confirmations are the photos removed.
10. Confirm the Photos app now shows the deleted items in **Recently Deleted**,
    and that restored photos are still present.

**Persistence**

11. During a session, force-quit Swiper mid-way and relaunch. The entry screen
    offers **Continue**; the queue and position are restored.

**Statistics**

12. Open the statistics icon (chart, top-right on the entry screen). Only
    confirmed deletions are counted. Queued-then-restored photos and failed
    deletions are not.

> Automated tests never touch a real library. Unit tests exercise the pure
> `SwiperKit` logic; UI tests launch the app with `-uiTestingFakeLibrary`, which
> swaps in an in-memory library.

## Tests

With a working Xcode:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -project Swiper.xcodeproj -scheme Swiper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Verified 2026-09-20 on Xcode 27.0 / iOS 26.5: **66 unit tests + 4 UI tests,
all green** on the iPhone 17 Pro Simulator.

If `xcodebuild` is unavailable, the logic tests still run on macOS directly:

```sh
Scripts/run-kit-tests.sh        # builds and runs SwiperKitTests on macOS
Scripts/typecheck-ios.sh        # compile-checks the iOS app and framework
```

## How storage sizes are reported

PhotoKit's public API does not expose asset byte sizes, and the private/KVC
workarounds are not App Store safe. Swiper therefore estimates size from pixel
dimensions and media kind and always presents it as approximate. The exact
calculation lives in `SwiperKit/StorageEstimate.swift`; the reasoning is in
[`docs/adr/0002-public-api-storage-estimates.md`](docs/adr/0002-public-api-storage-estimates.md).

## Privacy

* Swiper requests read-write photo access only.
* All session state, preferences and statistics are stored locally in the app's
  Application Support directory.
* Nothing is uploaded. There are no accounts, analytics or cloud services.

## Regenerating the project

```sh
ruby Scripts/generate_project.rb
```
