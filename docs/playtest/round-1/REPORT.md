# Playtest round 1

Owner-requested playtest of the SWIPR iOS app. Captured with a UI test on the
in-memory fake library (no real photo is ever touched), on:

- **iPhone 11 Pro** (375 x 812 pt) — light, dark and the largest accessibility
  text size (AX5).
- **iPhone SE (3rd generation)** (375 x 667 pt) — light.

Screenshots live in [`before/`](before) and [`after/`](after); the `after`
screenshots are also combined into the labelled 3x4 contact sheets
[`sheet-1.png`](sheet-1.png), [`sheet-2.png`](sheet-2.png) and
[`sheet-3.png`](sheet-3.png) (copies in `~/SWIPR-playtest/round-1/sheets/`).

The **before** screenshots come from `main` at `0151bf6`; the **after**
screenshots come from this branch, whose only changes are the fixes in (a).
Geometry below is the accessibility frame reported by XCTest, in points, with
the screen size in each heading.

## (a) What I fixed

1. **Home review/trash chip was 117 x 35.7 pt, under the 44 pt minimum and
   shorter than the 44 x 44 Settings button beside it** — the label now carries
   a 44 pt minimum height. Measured after: 117 x 44 pt (matches Settings).
2. **Viewer review/trash chip was 121 x 37.7 pt, shorter than the 44 x 44
   Close control** — same 44 pt minimum. Measured after: 121 x 44 pt.
3. **Review "Select"/"Done" was 45.3 x 18 pt** — its explicit `frame` was
   applied outside the button label, where it does not reach the hit or
   accessibility frame; the frame now wraps the label. Measured after: 60 x 44 pt.
4. **Filters "Clear" was 38 x 18 pt** — same misplaced-frame bug, moved inside
   the label. Measured after: 44 x 44 pt.
5. **Filters "Only" (all five categories) was 29 x 15.7 pt** — same fix.
   Measured after: 44 x 44 pt each.
6. **The full-screen photo inspector's Close was 40 x 40 pt** — raised to
   44 x 44 pt (not on a captured screen, but on the same code path).
7. **Settings position and Undo-position rows were 39 pt tall** — added a 44 pt
   minimum layout height, so the tappable row is 44 pt. (The accessibility frame
   XCTest reports is still 39-40 pt because it is the text union, not the row;
   see (b).)

## (b) What I found but need the owner's design decision on

- **Do we lift every dense control to a 44 pt tap target?** Still under 44 pt
  after the fixes: filter preset buttons (109 x 40), filter category rows
  (261 x 38), the Choose-a-photo traversal buttons (108 x 42), Jump/New order
  (176 x 34 and 132 x 34), the Settings two-line rows (39-40 pt accessibility
  frame), the Default-direction segmented control (299 x 31) and the system
  toggles (38 pt). Raising them all costs vertical space and reflows the
  Settings sections; a deliberate choice is needed rather than a blanket change.
- **The Settings rows report a 39-40 pt accessibility frame even after the tap
  target is 44 pt.** The frame XCTest/VoiceOver sees is the union of the two
  text lines, not the padded row. If we want the *spoken* row to be 44 pt, the
  title and subtitle need more space between them.
- **The decision dock lives in the bottom of the screen.** Delete/Keep sit at
  y 696-758 on the 812 pt phone and y 585-647 on the 667 pt phone. That is
  deliberate (thumb reach) but it is the bottom-half feedback the brief asked me
  to flag; confirm it does not fight the iOS bottom-edge swipe.
- **The review tab's visible capsule stays ~36 pt tall** while its tap target is
  now 44 pt. Confirm the smaller visual chip is still wanted.
- **The media-kind badge is 26 pt tall** (Photo/Live/Video). It is informational,
  not tappable, but it sits under the review tab; confirm the stacking reads well
  in all three dock positions.
- **At AX5 the Home preset cards run off the bottom** (Videos card at y 796 on an
  812 pt screen, and 187 pt tall). The screen scrolls, but confirm the first card
  should be the one that stays visible.

## (c) What I could not test

- Real PhotoKit deletion and the **system confirmation alert** — the playtest
  runs against `FakePhotoLibrary`.
- Real **Live Photo playback** — the fake library returns no `PHLivePhoto`.
- The **permission screen** (`permission.*`) — the fake library always grants
  access, so it is unreachable here.
- The **save-failure and read-only persistence banners** — they need an injected
  store failure; unit tests cover them but they were not screenshotted.
- **Landscape** orientation and iPad layouts.
- **VoiceOver reading order and spoken labels** — only frame geometry was
  captured, not audio.
- **Real-device behaviour**: haptics, reduced motion, and the bottom-edge system
  gesture.
- On the SE only the light pass ran; there is no SE dark/AX5 screenshot.

## (d) Layout tables (after fixes)

Flag key: **<44** = width or height below 44 pt; **bottom** = control centred in
the bottom half; **notch** = starts above the top safe edge; **home** = reaches
past the bottom safe edge while visible; **off-screen** = below the visible
area. Only controls and named text are listed. Elements with no name are omitted.

### iPhone 11 Pro (light / dark / AX5)

### 01 Home Empty Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 52.0 | 44.0 | 44.0 | — |
| `entry.wordmark` | 139.8 | 114.0 | 95.3 | 36.0 | — |
| `entry.heading` | 16.0 | 168.0 | 251.0 | 81.7 | — |
| `entry.preset.everything` | 16.0 | 267.7 | 343.0 | 128.0 | — |
| `entry.preset.photos` | 16.0 | 407.7 | 165.7 | 128.0 | bottom |
| `entry.preset.videos` | 193.7 | 407.7 | 165.3 | 128.0 | bottom |
| `video` | 257.3 | 458.3 | 39.7 | 26.7 | — |

### 02 Filters Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `filter.back` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `filter.preset.everything` | 16.0 | 110.0 | 109.0 | 40.0 | <44 |
| `filter.preset.photos` | 133.0 | 110.0 | 109.0 | 40.0 | <44 |
| `filter.preset.videos` | 250.0 | 110.0 | 109.0 | 40.0 | <44 |
| `checkmark` | 23.0 | 124.3 | 12.0 | 11.3 | — |
| `filter.clear` | 315.0 | 166.0 | 44.0 | 44.0 | — |
| `filter.only.screenshot` | 301.0 | 234.0 | 44.0 | 44.0 | — |
| `filter.toggle.screenshot` | 30.0 | 237.0 | 261.0 | 38.0 | <44 |
| `checkmark.circle.fill` | 31.7 | 245.3 | 21.7 | 21.7 | — |
| `filter.only.livePhoto` | 301.0 | 304.0 | 44.0 | 44.0 | — |
| `filter.toggle.livePhoto` | 30.0 | 307.0 | 261.0 | 38.0 | <44 |
| `checkmark.circle.fill` | 31.7 | 315.3 | 21.7 | 21.7 | — |
| `filter.only.panorama` | 301.0 | 374.0 | 44.0 | 44.0 | — |
| `filter.toggle.panorama` | 30.0 | 377.0 | 261.0 | 38.0 | <44 |
| `checkmark.circle.fill` | 31.7 | 385.3 | 21.7 | 21.7 | — |
| `filter.only.otherPhoto` | 301.0 | 444.0 | 44.0 | 44.0 | bottom |
| `filter.toggle.otherPhoto` | 30.0 | 447.0 | 261.0 | 38.0 | <44, bottom |
| `checkmark.circle.fill` | 31.7 | 455.3 | 21.7 | 21.7 | — |
| `filter.only.video` | 301.0 | 514.0 | 44.0 | 44.0 | bottom |
| `filter.toggle.video` | 30.0 | 517.0 | 261.0 | 38.0 | <44, bottom |
| `checkmark.circle.fill` | 31.7 | 525.3 | 21.7 | 21.7 | — |
| `filter.summary` | 16.0 | 582.0 | 343.0 | 47.7 | — |
| `photo.on.rectangle` | 32.0 | 597.3 | 20.7 | 17.0 | — |
| `filter.continue` | 16.0 | 715.7 | 343.0 | 50.3 | bottom |

### 03 Choose a Photo Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `choosePhoto.back` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `choosePhoto.explanation` | 16.0 | 94.0 | 337.7 | 51.7 | — |
| `choosePhoto.newest` | 16.0 | 155.7 | 107.7 | 62.0 | — |
| `choosePhoto.oldest` | 133.7 | 165.7 | 107.7 | 42.0 | <44 |
| `choosePhoto.random` | 251.3 | 165.7 | 107.7 | 42.0 | <44 |
| `clock.arrow.circlepath` | 27.7 | 179.0 | 17.0 | 15.3 | — |
| `clock` | 136.0 | 179.0 | 15.3 | 15.3 | — |
| `shuffle` | 263.0 | 179.7 | 18.0 | 14.3 | — |
| `choosePhoto.jump` | 16.0 | 227.7 | 176.3 | 34.0 | <44 |
| `choosePhoto.sort` | 226.7 | 227.7 | 132.3 | 34.0 | <44 |
| `calendar` | 30.0 | 237.7 | 15.3 | 14.0 | — |
| `arrow.down` | 240.7 | 237.7 | 11.7 | 14.0 | — |
| `chevron.down` | 169.0 | 241.7 | 10.0 | 6.0 | — |
| `choosePhoto.month.2024-06` | 2.0 | 272.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-23` | 2.0 | 304.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2024-05` | 2.0 | 398.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-22` | 2.0 | 430.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-21` | 126.3 | 430.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-20` | 250.7 | 430.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-19` | 2.0 | 524.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-19` | 2.0 | 524.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2024-04` | 2.0 | 618.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-18` | 2.0 | 650.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-17` | 126.3 | 650.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-16` | 250.7 | 650.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2024-03` | 2.0 | 744.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-15` | 2.0 | 776.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-14` | 126.3 | 776.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-14` | 126.3 | 776.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-13` | 250.7 | 776.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-12` | 2.0 | 870.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2024-02` | 2.0 | 964.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-11` | 2.0 | 996.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-10` | 126.3 | 996.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-9` | 250.7 | 996.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-9` | 250.7 | 996.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2024-01` | 2.0 | 1090.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-8` | 2.0 | 1122.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-7` | 126.3 | 1122.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-6` | 250.7 | 1122.0 | 122.3 | 92.0 | — |
| `choosePhoto.month.2023-12` | 2.0 | 1216.0 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-5` | 2.0 | 1248.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-4` | 126.3 | 1248.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-4` | 126.3 | 1248.0 | 122.3 | 92.0 | — |
| `choosePhoto.cell.fake-3` | 250.7 | 1248.0 | 122.3 | 92.0 | — |

### 04 Tutorial Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.tutorial` | 0.0 | 0.0 | 375.0 | 812.0 | — |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 287.8 | 49.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 57.7 | 13.0 | 10.3 | — |
| `hand.draw` | 49.3 | 175.3 | 26.0 | 24.3 | — |
| `hand.draw` | 49.3 | 259.0 | 26.0 | 24.3 | — |
| `trash` | 51.3 | 324.7 | 19.7 | 22.3 | — |
| `viewer.photo` | 0.3 | 364.0 | 374.3 | 94.0 | — |
| `hand.draw` | 49.3 | 408.3 | 26.0 | 24.3 | — |
| `viewer.tutorial.dismiss` | 46.0 | 638.0 | 283.0 | 50.3 | bottom |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 216.7 | 717.0 | 14.3 | 14.0 | — |

### 05 Viewer Dock Bottom Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 287.8 | 49.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 57.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.3 | 364.0 | 374.3 | 94.0 | — |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 216.7 | 717.0 | 14.3 | 14.0 | — |

### 06 Viewer Marked Dock Bottom Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.review` | 238.0 | 50.0 | 121.0 | 44.0 | — |
| `trash` | 253.0 | 63.7 | 14.7 | 17.0 | — |
| `viewer.mediaBadge` | 287.8 | 101.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 109.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.0 | 223.7 | 375.0 | 375.0 | — |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 216.7 | 717.0 | 14.3 | 14.0 | — |

### 07 Home Session And Marks Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 52.0 | 44.0 | 44.0 | — |
| `entry.review` | 242.0 | 52.0 | 117.0 | 44.0 | — |
| `trash` | 255.0 | 65.7 | 14.7 | 17.0 | — |
| `entry.wordmark` | 139.8 | 114.0 | 95.3 | 36.0 | — |
| `entry.heading` | 16.0 | 168.0 | 251.0 | 81.7 | — |
| `entry.preset.everything` | 16.0 | 267.7 | 343.0 | 128.0 | — |
| `entry.preset.photos` | 16.0 | 407.7 | 165.3 | 128.0 | bottom |
| `entry.preset.videos` | 193.3 | 407.7 | 165.7 | 128.0 | bottom |
| `video` | 257.3 | 458.3 | 39.7 | 26.7 | — |
| `entry.resume` | 15.5 | 553.2 | 344.0 | 67.0 | bottom |
| `clock.arrow.circlepath` | 29.7 | 576.3 | 22.7 | 20.7 | — |
| `chevron.right` | 337.7 | 580.7 | 6.7 | 11.7 | — |

### 08 Viewer Dock Left Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.review` | 238.0 | 50.0 | 121.0 | 44.0 | — |
| `trash` | 253.0 | 63.7 | 14.7 | 17.0 | — |
| `viewer.mediaBadge` | 287.8 | 101.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 109.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.0 | 223.7 | 375.0 | 375.0 | — |
| `viewer.cluster` | 20.0 | 461.7 | 56.0 | 196.0 | — |
| `control.undo` | 20.0 | 461.7 | 56.0 | 56.0 | bottom |
| `control.delete` | 20.0 | 531.7 | 56.0 | 56.0 | bottom |
| `control.keep` | 20.0 | 601.7 | 56.0 | 56.0 | bottom |

### 09 Viewer Dock Right Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.review` | 238.0 | 50.0 | 121.0 | 44.0 | — |
| `trash` | 253.0 | 63.7 | 14.7 | 17.0 | — |
| `viewer.mediaBadge` | 287.8 | 101.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 109.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.0 | 223.7 | 375.0 | 375.0 | — |
| `viewer.cluster` | 299.0 | 461.7 | 56.0 | 196.0 | — |
| `control.undo` | 299.0 | 461.7 | 56.0 | 56.0 | bottom |
| `control.delete` | 299.0 | 531.7 | 56.0 | 56.0 | bottom |
| `control.keep` | 299.0 | 601.7 | 56.0 | 56.0 | bottom |

### 10 Viewer Dock Bottom Again Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.review` | 238.0 | 50.0 | 121.0 | 44.0 | — |
| `trash` | 253.0 | 63.7 | 14.7 | 17.0 | — |
| `viewer.mediaBadge` | 287.8 | 101.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 109.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.0 | 223.7 | 375.0 | 375.0 | — |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 216.7 | 717.0 | 14.3 | 14.0 | — |

### 11 Review Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `review.back` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `review.selectToggle` | 303.0 | 50.0 | 60.0 | 44.0 | — |
| `review.markedCount` | 101.8 | 76.0 | 155.3 | 14.3 | — |
| `review.cell.0` | 2.0 | 94.0 | 122.3 | 122.3 | — |
| `review.delete` | 20.0 | 666.7 | 335.0 | 51.7 | bottom |
| `trash` | 118.0 | 683.0 | 16.7 | 19.0 | — |
| `review.deleteExplanation` | 32.5 | 730.3 | 310.0 | 33.7 | — |

### 12 Result Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `checkmark.circle.fill` | 162.0 | 307.7 | 51.0 | 51.0 | — |
| `result.done` | 48.0 | 469.0 | 279.0 | 50.0 | bottom |

### 13 Settings Light

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `chevron.left` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `settings.statistics` | 20.0 | 114.0 | 70.0 | 14.3 | — |
| `settings.statistics.lifetimeDeleted.label` | 38.0 | 158.3 | 115.0 | 20.3 | — |
| `settings.statistics.lifetimeDeleted` | 329.3 | 158.3 | 8.0 | 20.3 | — |
| `settings.statistics.lifetimeReclaimed.label` | 38.0 | 188.7 | 138.7 | 20.3 | — |
| `settings.statistics.lifetimeReclaimed` | 267.0 | 188.7 | 70.3 | 20.3 | — |
| `settings.statistics.sessions.label` | 38.0 | 219.0 | 153.3 | 20.3 | — |
| `settings.statistics.sessions` | 326.3 | 219.0 | 11.0 | 20.3 | — |
| `settings.statistics.currentSession.label` | 38.0 | 249.3 | 94.0 | 20.3 | — |
| `settings.statistics.currentSession` | 181.7 | 249.3 | 155.7 | 20.3 | — |
| `Controls` | 20.0 | 359.3 | 67.7 | 14.3 | — |
| `settings.showButtons` | 38.0 | 409.7 | 299.3 | 75.0 | — |
| `settings.haptics` | 38.0 | 506.7 | 299.3 | 75.0 | — |
| `settings.position.bottom` | 39.3 | 603.7 | 253.7 | 39.0 | <44, bottom |
| `largecircle.fill.circle` | 39.3 | 605.0 | 17.0 | 17.0 | — |
| `settings.position.leading` | 39.3 | 664.7 | 217.3 | 39.0 | <44, bottom |
| `circle` | 39.3 | 666.0 | 17.0 | 17.0 | — |
| `settings.position.trailing` | 39.3 | 725.7 | 228.3 | 39.0 | <44, bottom |
| `circle` | 39.3 | 727.0 | 17.0 | 17.0 | — |
| `settings.undoSide.leading` | 39.3 | 817.0 | 259.7 | 57.0 | bottom, off-screen |
| `largecircle.fill.circle` | 39.3 | 818.3 | 17.0 | 17.0 | — |
| `settings.undoSide.trailing` | 39.3 | 896.0 | 245.3 | 39.0 | <44, bottom, off-screen |
| `circle` | 39.3 | 897.3 | 17.0 | 17.0 | — |
| `settings.resetControls` | 39.3 | 957.0 | 297.3 | 57.0 | bottom, off-screen |
| `hand.draw` | 39.3 | 975.7 | 20.7 | 19.7 | — |
| `chevron.right` | 330.0 | 979.7 | 6.7 | 11.7 | — |
| `Help` | 20.0 | 1201.7 | 31.7 | 14.3 | — |
| `settings.howToUse` | 39.3 | 1252.0 | 297.3 | 57.0 | bottom, off-screen |
| `questionmark.circle` | 39.3 | 1272.0 | 17.0 | 17.0 | — |
| `chevron.right` | 330.0 | 1274.7 | 6.7 | 11.7 | — |
| `Default direction` | 20.0 | 1357.0 | 123.7 | 14.3 | — |
| `settings.direction` | 38.0 | 1401.3 | 299.3 | 31.0 | <44, bottom, off-screen |

### 14 Home Dark

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 52.0 | 44.0 | 44.0 | — |
| `entry.wordmark` | 139.8 | 114.0 | 95.3 | 36.0 | — |
| `entry.heading` | 16.0 | 168.0 | 251.0 | 81.7 | — |
| `entry.preset.everything` | 16.0 | 267.7 | 343.0 | 128.0 | — |
| `entry.preset.photos` | 16.0 | 407.7 | 165.7 | 128.0 | bottom |
| `entry.preset.videos` | 193.7 | 407.7 | 165.3 | 128.0 | bottom |
| `video` | 257.3 | 458.3 | 39.7 | 26.7 | — |

### 15 Viewer Dock Bottom Dark

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 287.8 | 49.5 | 71.7 | 26.3 | — |
| `photo` | 298.7 | 57.7 | 13.0 | 10.3 | — |
| `viewer.photo` | 0.3 | 364.0 | 374.3 | 94.0 | — |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 216.7 | 717.0 | 14.3 | 14.0 | — |

### 16 Review Dark

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `review.back` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `review.selectToggle` | 303.0 | 50.0 | 60.0 | 44.0 | — |
| `review.markedCount` | 101.8 | 76.0 | 155.3 | 14.3 | — |
| `review.cell.0` | 2.0 | 94.0 | 122.3 | 122.3 | — |
| `review.delete` | 20.0 | 666.7 | 335.0 | 51.7 | bottom |
| `trash` | 118.0 | 683.0 | 16.7 | 19.0 | — |
| `review.deleteExplanation` | 32.5 | 730.3 | 310.0 | 33.7 | — |

### 17 Result Dark

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `checkmark.circle.fill` | 162.0 | 307.7 | 51.0 | 51.0 | — |
| `result.done` | 48.0 | 469.0 | 279.0 | 50.0 | bottom |

### 18 Settings Dark

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `chevron.left` | 12.0 | 50.0 | 44.0 | 44.0 | — |
| `settings.statistics` | 20.0 | 114.0 | 70.0 | 14.3 | — |
| `settings.statistics.lifetimeDeleted.label` | 38.0 | 158.3 | 115.0 | 20.3 | — |
| `settings.statistics.lifetimeDeleted` | 329.3 | 158.3 | 8.0 | 20.3 | — |
| `settings.statistics.lifetimeReclaimed.label` | 38.0 | 188.7 | 138.7 | 20.3 | — |
| `settings.statistics.lifetimeReclaimed` | 267.0 | 188.7 | 70.3 | 20.3 | — |
| `settings.statistics.sessions.label` | 38.0 | 219.0 | 153.3 | 20.3 | — |
| `settings.statistics.sessions` | 326.3 | 219.0 | 11.0 | 20.3 | — |
| `settings.statistics.currentSession.label` | 38.0 | 249.3 | 94.0 | 20.3 | — |
| `settings.statistics.currentSession` | 181.7 | 249.3 | 155.7 | 20.3 | — |
| `Controls` | 20.0 | 359.3 | 67.7 | 14.3 | — |
| `settings.showButtons` | 38.0 | 409.7 | 299.3 | 75.0 | — |
| `settings.haptics` | 38.0 | 506.7 | 299.3 | 75.0 | — |
| `settings.position.bottom` | 39.3 | 603.7 | 253.7 | 39.0 | <44, bottom |
| `largecircle.fill.circle` | 39.3 | 605.0 | 17.0 | 17.0 | — |
| `settings.position.leading` | 39.3 | 664.7 | 217.3 | 39.0 | <44, bottom |
| `circle` | 39.3 | 666.0 | 17.0 | 17.0 | — |
| `settings.position.trailing` | 39.3 | 725.7 | 228.3 | 39.0 | <44, bottom |
| `circle` | 39.3 | 727.0 | 17.0 | 17.0 | — |
| `settings.undoSide.leading` | 39.3 | 817.0 | 259.7 | 57.0 | bottom, off-screen |
| `largecircle.fill.circle` | 39.3 | 818.3 | 17.0 | 17.0 | — |
| `settings.undoSide.trailing` | 39.3 | 896.0 | 245.3 | 39.0 | <44, bottom, off-screen |
| `circle` | 39.3 | 897.3 | 17.0 | 17.0 | — |
| `settings.resetControls` | 39.3 | 957.0 | 297.3 | 57.0 | bottom, off-screen |
| `hand.draw` | 39.3 | 975.7 | 20.7 | 19.7 | — |
| `chevron.right` | 330.0 | 979.7 | 6.7 | 11.7 | — |
| `Help` | 20.0 | 1201.7 | 31.7 | 14.3 | — |
| `settings.howToUse` | 39.3 | 1252.0 | 297.3 | 57.0 | bottom, off-screen |
| `questionmark.circle` | 39.3 | 1272.0 | 17.0 | 17.0 | — |
| `chevron.right` | 330.0 | 1274.7 | 6.7 | 11.7 | — |
| `Default direction` | 20.0 | 1357.0 | 123.7 | 14.3 | — |
| `settings.direction` | 38.0 | 1401.3 | 299.3 | 31.0 | <44, bottom, off-screen |

### 19 Home AX5

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 52.0 | 44.0 | 44.0 | — |
| `entry.wordmark` | 160.3 | 114.0 | 95.3 | 36.0 | — |
| `entry.heading` | 16.0 | 168.0 | 353.3 | 211.7 | — |
| `entry.preset.everything` | 16.0 | 397.7 | 384.0 | 187.3 | bottom |
| `entry.preset.photos` | 16.0 | 597.0 | 384.0 | 187.3 | bottom, home |
| `entry.preset.videos` | 16.0 | 796.3 | 384.0 | 187.3 | bottom, home |
| `video` | 189.3 | 831.0 | 39.7 | 26.7 | — |

### 20 Choose a Photo AX5

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `choosePhoto.back` | 12.0 | 90.7 | 44.0 | 44.0 | <44 |
| `choosePhoto.explanation` | 16.0 | 175.3 | 340.3 | 572.7 | — |
| `choosePhoto.newest` | 16.0 | 758.0 | 343.0 | 82.7 | bottom, home |
| `clock.arrow.circlepath` | 21.3 | 774.3 | 55.0 | 50.0 | — |
| `choosePhoto.oldest` | 16.0 | 850.7 | 343.0 | 82.7 | bottom, off-screen |
| `clock` | 37.3 | 867.0 | 50.0 | 50.0 | — |
| `choosePhoto.random` | 16.0 | 943.3 | 343.0 | 82.7 | bottom, off-screen |
| `shuffle` | 63.0 | 961.3 | 58.7 | 46.7 | — |
| `choosePhoto.jump` | 17.7 | 1036.0 | 339.7 | 132.7 | bottom, off-screen |
| `calendar` | 35.7 | 1079.7 | 49.3 | 45.3 | — |
| `chevron.down` | 304.3 | 1091.7 | 36.0 | 21.3 | — |
| `choosePhoto.sort` | 59.0 | 1178.7 | 257.3 | 132.7 | bottom, off-screen |
| `arrow.down` | 77.0 | 1222.3 | 37.7 | 45.7 | — |
| `choosePhoto.month.2024-06` | 2.0 | 1322.3 | 371.0 | 70.7 | — |
| `choosePhoto.cell.fake-23` | 2.0 | 1395.0 | 122.3 | 92.0 | — |

### 21 Viewer Dock Bottom AX5

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 50.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 170.2 | 49.5 | 189.3 | 61.0 | — |
| `photo` | 184.7 | 61.3 | 46.7 | 37.7 | — |
| `viewer.photo` | 0.3 | 364.0 | 374.3 | 94.0 | — |
| `viewer.cluster` | 16.7 | 690.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.7 | 696.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.7 | 702.0 | 44.0 | 44.0 | bottom |
| `trash` | 90.3 | 715.0 | 15.7 | 18.0 | — |
| `checkmark` | 211.7 | 717.0 | 14.3 | 14.0 | — |

### 22 Review AX5

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `review.back` | 12.0 | 166.7 | 44.0 | 44.0 | — |
| `review.selectToggle` | 303.0 | 166.7 | 60.0 | 44.0 | — |
| `review.markedCount` | 77.7 | 175.5 | 203.7 | 153.3 | — |
| `review.delete` | 20.0 | 343.0 | 335.0 | 98.3 | — |
| `trash` | 25.3 | 362.7 | 52.0 | 59.0 | — |
| `review.deleteExplanation` | 20.0 | 453.2 | 335.0 | 312.7 | — |

### 23 Result AX5

Screen size: **375 x 812 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `checkmark.circle.fill` | 162.0 | 100.7 | 51.0 | 51.0 | — |
| `result.done` | 48.0 | 650.3 | 279.0 | 155.3 | bottom, home |

### iPhone SE (3rd generation, light)

### SE — 01 Home Empty Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 28.0 | 44.0 | 44.0 | — |
| `entry.wordmark` | 139.8 | 90.0 | 95.5 | 36.0 | — |
| `entry.heading` | 16.0 | 144.0 | 251.0 | 82.0 | — |
| `entry.preset.everything` | 16.0 | 244.0 | 343.0 | 128.0 | — |
| `entry.preset.photos` | 16.0 | 384.0 | 165.5 | 128.0 | bottom |
| `entry.preset.videos` | 193.5 | 384.0 | 165.5 | 128.0 | bottom |
| `video` | 257.5 | 435.0 | 39.5 | 26.5 | — |

### SE — 02 Filters Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `filter.back` | 12.0 | 26.0 | 44.0 | 44.0 | — |
| `filter.preset.everything` | 16.0 | 86.0 | 109.0 | 40.0 | <44 |
| `filter.preset.photos` | 133.0 | 86.0 | 109.0 | 40.0 | <44 |
| `filter.preset.videos` | 250.0 | 86.0 | 109.0 | 40.0 | <44 |
| `checkmark` | 23.0 | 100.5 | 12.0 | 11.5 | — |
| `filter.clear` | 315.0 | 142.0 | 44.0 | 44.0 | — |
| `filter.only.screenshot` | 301.0 | 210.0 | 44.0 | 44.0 | — |
| `filter.toggle.screenshot` | 30.0 | 213.0 | 261.0 | 38.5 | <44 |
| `checkmark.circle.fill` | 32.0 | 221.5 | 21.5 | 21.5 | — |
| `filter.only.livePhoto` | 301.0 | 280.0 | 44.0 | 44.0 | — |
| `filter.toggle.livePhoto` | 30.0 | 283.0 | 261.0 | 38.5 | <44 |
| `checkmark.circle.fill` | 32.0 | 291.5 | 21.5 | 21.5 | — |
| `filter.only.panorama` | 301.0 | 350.0 | 44.0 | 44.0 | bottom |
| `filter.toggle.panorama` | 30.0 | 353.0 | 261.0 | 38.5 | <44, bottom |
| `checkmark.circle.fill` | 32.0 | 361.5 | 21.5 | 21.5 | — |
| `filter.only.otherPhoto` | 301.0 | 420.0 | 44.0 | 44.0 | bottom |
| `filter.toggle.otherPhoto` | 30.0 | 423.0 | 261.0 | 38.5 | <44, bottom |
| `checkmark.circle.fill` | 32.0 | 431.5 | 21.5 | 21.5 | — |
| `filter.only.video` | 301.0 | 490.0 | 44.0 | 44.0 | bottom |
| `filter.toggle.video` | 30.0 | 493.0 | 261.0 | 38.5 | <44, bottom |
| `checkmark.circle.fill` | 32.0 | 501.5 | 21.5 | 21.5 | — |
| `filter.summary` | 16.0 | 558.0 | 343.0 | 48.0 | — |
| `photo.on.rectangle` | 32.0 | 573.5 | 21.0 | 17.0 | — |
| `filter.continue` | 16.0 | 604.5 | 343.0 | 50.5 | bottom |

### SE — 03 Choose a Photo Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `choosePhoto.back` | 12.0 | 26.0 | 44.0 | 44.0 | — |
| `choosePhoto.explanation` | 16.0 | 70.0 | 337.5 | 52.0 | — |
| `choosePhoto.newest` | 16.0 | 132.0 | 107.5 | 62.0 | — |
| `choosePhoto.oldest` | 133.5 | 142.0 | 108.0 | 42.5 | <44 |
| `choosePhoto.random` | 251.5 | 142.0 | 107.5 | 42.0 | <44 |
| `clock.arrow.circlepath` | 28.0 | 155.5 | 17.0 | 15.5 | — |
| `clock` | 136.0 | 155.5 | 15.5 | 15.5 | — |
| `shuffle` | 262.5 | 156.0 | 18.0 | 14.5 | — |
| `choosePhoto.jump` | 16.0 | 204.0 | 177.0 | 34.0 | <44 |
| `choosePhoto.sort` | 226.5 | 204.0 | 132.5 | 34.0 | <44 |
| `calendar` | 30.0 | 214.0 | 15.5 | 14.0 | — |
| `arrow.down` | 240.5 | 214.0 | 12.0 | 14.0 | — |
| `chevron.down` | 169.5 | 218.0 | 10.0 | 6.0 | — |
| `choosePhoto.month.2024-06` | 2.0 | 248.5 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-23` | 2.0 | 280.5 | 122.5 | 92.0 | — |
| `choosePhoto.month.2024-05` | 2.0 | 374.5 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-22` | 2.0 | 406.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-21` | 126.5 | 406.5 | 122.0 | 92.0 | — |
| `choosePhoto.cell.fake-20` | 250.5 | 406.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-19` | 2.0 | 500.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-19` | 2.0 | 500.5 | 122.5 | 92.0 | — |
| `choosePhoto.month.2024-04` | 2.0 | 594.5 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-18` | 2.0 | 626.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-17` | 126.5 | 626.5 | 122.0 | 92.0 | — |
| `choosePhoto.cell.fake-16` | 250.5 | 626.5 | 122.5 | 92.0 | — |
| `choosePhoto.month.2024-03` | 2.0 | 720.5 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-15` | 2.0 | 752.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-14` | 126.5 | 752.5 | 122.0 | 92.0 | — |
| `choosePhoto.cell.fake-14` | 126.5 | 752.5 | 122.0 | 92.0 | — |
| `choosePhoto.cell.fake-13` | 250.5 | 752.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-12` | 2.0 | 846.5 | 122.5 | 92.0 | — |
| `choosePhoto.month.2024-02` | 2.0 | 940.5 | 371.0 | 30.0 | — |
| `choosePhoto.cell.fake-11` | 2.0 | 972.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-10` | 126.5 | 972.5 | 122.0 | 92.0 | — |
| `choosePhoto.cell.fake-9` | 250.5 | 972.5 | 122.5 | 92.0 | — |
| `choosePhoto.cell.fake-9` | 250.5 | 972.5 | 122.5 | 92.0 | — |
| `choosePhoto.month.2024-01` | 2.0 | 1066.5 | 371.0 | 30.0 | — |

### SE — 04 Tutorial Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.tutorial` | 0.0 | 0.0 | 375.0 | 667.0 | — |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 287.5 | 25.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 33.5 | 13.0 | 10.5 | — |
| `hand.draw` | 49.5 | 107.5 | 26.0 | 24.5 | — |
| `hand.draw` | 49.5 | 191.5 | 26.0 | 24.5 | — |
| `trash` | 51.0 | 257.5 | 20.0 | 22.5 | — |
| `viewer.photo` | 0.5 | 296.5 | 374.0 | 94.0 | — |
| `hand.draw` | 49.5 | 341.5 | 26.0 | 24.5 | — |
| `viewer.tutorial.dismiss` | 46.0 | 572.5 | 283.0 | 48.5 | bottom |
| `viewer.cluster` | 16.5 | 579.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.5 | 591.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 604.0 | 16.0 | 18.0 | — |
| `checkmark` | 216.5 | 606.0 | 14.5 | 14.0 | — |

### SE — 05 Viewer Dock Bottom Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.mediaBadge` | 287.5 | 25.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 33.5 | 13.0 | 10.5 | — |
| `viewer.photo` | 0.5 | 296.5 | 374.0 | 94.0 | — |
| `viewer.cluster` | 16.5 | 579.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.5 | 591.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 604.0 | 16.0 | 18.0 | — |
| `checkmark` | 216.5 | 606.0 | 14.5 | 14.0 | — |

### SE — 06 Viewer Marked Dock Bottom Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.review` | 237.5 | 26.0 | 121.5 | 44.0 | — |
| `trash` | 252.5 | 39.5 | 15.0 | 17.0 | — |
| `viewer.mediaBadge` | 287.5 | 77.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 85.5 | 13.0 | 10.5 | — |
| `viewer.photo` | 0.0 | 156.0 | 375.0 | 375.0 | — |
| `viewer.cluster` | 16.5 | 579.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.5 | 591.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 604.0 | 16.0 | 18.0 | — |
| `checkmark` | 216.5 | 606.0 | 14.5 | 14.0 | — |

### SE — 07 Home Session And Marks Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `entry.settings` | 16.0 | 28.0 | 44.0 | 44.0 | — |
| `entry.review` | 241.5 | 28.0 | 117.5 | 44.0 | — |
| `trash` | 254.5 | 41.5 | 15.0 | 17.0 | — |
| `entry.wordmark` | 139.8 | 90.0 | 95.5 | 36.0 | — |
| `entry.heading` | 16.0 | 144.0 | 251.0 | 82.0 | — |
| `entry.preset.everything` | 16.0 | 244.0 | 343.0 | 128.0 | — |
| `entry.preset.photos` | 16.0 | 384.0 | 165.5 | 128.0 | bottom |
| `entry.preset.videos` | 193.5 | 384.0 | 165.5 | 128.0 | bottom |
| `video` | 257.5 | 435.0 | 39.5 | 26.5 | — |
| `entry.resume` | 15.5 | 529.5 | 344.0 | 67.5 | bottom |
| `clock.arrow.circlepath` | 29.5 | 553.0 | 22.5 | 20.5 | — |
| `chevron.right` | 337.0 | 557.5 | 7.0 | 11.5 | — |

### SE — 08 Viewer Dock Left Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.review` | 237.5 | 26.0 | 121.5 | 44.0 | — |
| `trash` | 252.5 | 39.5 | 15.0 | 17.0 | — |
| `viewer.mediaBadge` | 287.5 | 77.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 85.5 | 13.0 | 10.5 | — |
| `viewer.photo` | 0.0 | 156.0 | 375.0 | 375.0 | — |
| `viewer.cluster` | 20.0 | 372.5 | 56.0 | 196.0 | — |
| `control.undo` | 20.0 | 372.5 | 56.0 | 56.0 | bottom |
| `control.delete` | 20.0 | 442.5 | 56.0 | 56.0 | bottom |
| `control.keep` | 20.0 | 512.5 | 56.0 | 56.0 | bottom |

### SE — 09 Viewer Dock Right Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.review` | 237.5 | 26.0 | 121.5 | 44.0 | — |
| `trash` | 252.5 | 39.5 | 15.0 | 17.0 | — |
| `viewer.mediaBadge` | 287.5 | 77.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 85.5 | 13.0 | 10.5 | — |
| `viewer.photo` | 0.0 | 156.0 | 375.0 | 375.0 | — |
| `viewer.cluster` | 299.0 | 372.5 | 56.0 | 196.0 | — |
| `control.undo` | 299.0 | 372.5 | 56.0 | 56.0 | bottom |
| `control.delete` | 299.0 | 442.5 | 56.0 | 56.0 | bottom |
| `control.keep` | 299.0 | 512.5 | 56.0 | 56.0 | bottom |

### SE — 10 Viewer Dock Bottom Again Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `viewer.close` | 16.0 | 26.0 | 44.0 | 44.0 | — |
| `viewer.review` | 237.5 | 26.0 | 121.5 | 44.0 | — |
| `trash` | 252.5 | 39.5 | 15.0 | 17.0 | — |
| `viewer.mediaBadge` | 287.5 | 77.5 | 72.0 | 26.5 | — |
| `photo` | 298.5 | 85.5 | 13.0 | 10.5 | — |
| `viewer.photo` | 0.0 | 156.0 | 375.0 | 375.0 | — |
| `viewer.cluster` | 16.5 | 579.0 | 286.0 | 68.0 | — |
| `control.delete` | 78.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.keep` | 192.5 | 585.0 | 104.0 | 56.0 | bottom |
| `control.undo` | 16.5 | 591.0 | 44.0 | 44.0 | bottom |
| `trash` | 97.0 | 604.0 | 16.0 | 18.0 | — |
| `checkmark` | 216.5 | 606.0 | 14.5 | 14.0 | — |

### SE — 11 Review Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `review.back` | 12.0 | 26.0 | 44.0 | 44.0 | — |
| `review.selectToggle` | 303.0 | 26.0 | 60.0 | 44.0 | — |
| `review.markedCount` | 101.8 | 52.0 | 155.5 | 14.5 | — |
| `review.cell.0` | 2.0 | 70.0 | 122.5 | 122.5 | — |
| `review.delete` | 20.0 | 554.5 | 335.0 | 52.5 | bottom |
| `trash` | 118.0 | 571.0 | 17.0 | 19.0 | — |
| `review.deleteExplanation` | 32.5 | 619.0 | 310.0 | 34.0 | — |

### SE — 12 Result Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `checkmark.circle.fill` | 162.0 | 240.0 | 51.0 | 51.0 | — |
| `result.done` | 48.0 | 401.5 | 279.0 | 50.5 | bottom |

### SE — 13 Settings Light

Screen size: **375 x 667 pt**.

| Element | x | y | width | height | Flags |
| --- | ---: | ---: | ---: | ---: | --- |
| `chevron.left` | 12.0 | 26.0 | 44.0 | 44.0 | — |
| `settings.statistics` | 20.0 | 90.0 | 70.0 | 14.5 | — |
| `settings.statistics.lifetimeDeleted.label` | 38.0 | 134.5 | 115.0 | 20.5 | — |
| `settings.statistics.lifetimeDeleted` | 329.0 | 134.5 | 8.0 | 20.5 | — |
| `settings.statistics.lifetimeReclaimed.label` | 38.0 | 165.0 | 139.0 | 20.5 | — |
| `settings.statistics.lifetimeReclaimed` | 266.5 | 165.0 | 70.5 | 20.5 | — |
| `settings.statistics.sessions.label` | 38.0 | 195.5 | 153.5 | 20.5 | — |
| `settings.statistics.sessions` | 326.0 | 195.5 | 11.0 | 20.5 | — |
| `settings.statistics.currentSession.label` | 38.0 | 226.0 | 94.0 | 20.5 | — |
| `settings.statistics.currentSession` | 181.0 | 226.0 | 156.0 | 20.5 | — |
| `Controls` | 20.0 | 336.5 | 68.0 | 14.5 | — |
| `settings.showButtons` | 38.0 | 387.0 | 299.0 | 75.5 | — |
| `settings.haptics` | 38.0 | 484.5 | 299.0 | 75.5 | — |
| `settings.position.bottom` | 39.5 | 582.0 | 254.0 | 39.5 | <44, bottom |
| `largecircle.fill.circle` | 39.5 | 583.5 | 17.0 | 17.0 | — |
| `settings.position.leading` | 39.5 | 643.5 | 217.5 | 39.5 | <44, bottom |
| `circle` | 39.5 | 645.0 | 17.0 | 17.0 | — |
| `settings.position.trailing` | 39.5 | 705.0 | 228.5 | 39.5 | <44, bottom, off-screen |
| `circle` | 39.5 | 706.5 | 17.0 | 17.0 | — |
| `settings.undoSide.leading` | 39.5 | 797.0 | 260.0 | 57.5 | bottom, off-screen |
| `largecircle.fill.circle` | 39.5 | 798.5 | 17.0 | 17.0 | — |
| `settings.undoSide.trailing` | 39.5 | 876.5 | 245.5 | 39.5 | <44, bottom, off-screen |
| `circle` | 39.5 | 878.0 | 17.0 | 17.0 | — |
| `settings.resetControls` | 39.5 | 938.0 | 296.5 | 57.5 | bottom, off-screen |
| `hand.draw` | 39.5 | 957.0 | 21.0 | 19.5 | — |
| `chevron.right` | 329.0 | 961.0 | 7.0 | 11.5 | — |
| `Help` | 20.0 | 1183.5 | 31.5 | 14.5 | — |
| `settings.howToUse` | 39.5 | 1234.0 | 296.5 | 57.5 | bottom, off-screen |
| `questionmark.circle` | 39.5 | 1254.5 | 17.0 | 17.0 | — |
| `chevron.right` | 329.0 | 1257.0 | 7.0 | 11.5 | — |
| `Default direction` | 20.0 | 1339.5 | 124.0 | 14.5 | — |
| `settings.direction` | 38.0 | 1384.0 | 299.0 | 31.0 | <44, bottom, off-screen |

## Round 2

Round 2 changes only the owner's three items. Screenshots live in
[`round-2/`](round-2) and the single matrix contact sheet is
[`round-2-sheet.png`](round-2-sheet.png). Frames are measured from the same
accessibility dumps as round 1.

### Fix 1 — the media badge is only for Live Photo and Video

A plain photo has no `viewer.mediaBadge` element at all. The badge lives in
the top bar row, so its centre y equals `viewer.close`'s.

| Screen | Badge x, y, w, h | Close x, y, w, h | Centre Δy |
| --- | --- | --- | --- |
| 11 Pro light — Live Photo | 299, 58, 60, 27 | 16, 50, 44, 44 | +0.2 |
| 11 Pro dark — Live Photo | 299, 58, 60, 27 | 16, 50, 44, 44 | +0.2 |
| 11 Pro AX5 — Live Photo | 209, 50, 150, 65 | 16, 60, 44, 44 | -0.2 |
| SE light — Live Photo | 299, 34, 60, 28 | 16, 26, 44, 44 | +0.2 |
| SE dark — Live Photo | 299, 34, 60, 28 | 16, 26, 44, 44 | +0.2 |
| SE AX5 — Live Photo | 209, 26, 150, 65 | 16, 36, 44, 44 | +0.0 |
| 11 Pro light — plain photo | no badge (measured absent) | — | — |
| 11 Pro dark — plain photo | no badge (measured absent) | — | — |
| 11 Pro AX5 — plain photo | no badge (measured absent) | — | — |
| SE light — plain photo | no badge (measured absent) | — | — |
| SE dark — plain photo | no badge (measured absent) | — | — |
| SE AX5 — plain photo | no badge (measured absent) | — | — |

### Fix 2 — swipe feedback in the upper third

The Delete/Keep feedback that appears while dragging now sits just below
the top bar. It never reaches the bottom half and never overlaps a top-bar
control.

| Screen | Well | x, y, w, h | Mid-y | Screen h | Upper third |
| --- | --- | --- | ---: | ---: | --- |
| 11 Pro light — swipe left | viewer.dragFeedback.delete | 21, 124, 107, 50 | 149 | 812 | yes |
| 11 Pro light — swipe right | viewer.dragFeedback.keep | 256, 124, 98, 45 | 146 | 812 | yes |
| 11 Pro dark — swipe left | viewer.dragFeedback.delete | 21, 124, 107, 50 | 149 | 812 | yes |
| 11 Pro dark — swipe right | viewer.dragFeedback.keep | 256, 124, 98, 45 | 146 | 812 | yes |
| 11 Pro AX5 — swipe left | viewer.dragFeedback.delete | 22, 125, 240, 94 | 172 | 812 | yes |
| 11 Pro AX5 — swipe right | viewer.dragFeedback.keep | 141, 125, 211, 82 | 165 | 812 | yes |
| SE light — swipe left | viewer.dragFeedback.delete | 21, 100, 108, 50 | 125 | 667 | yes |
| SE light — swipe right | viewer.dragFeedback.keep | 256, 100, 99, 44 | 122 | 667 | yes |
| SE dark — swipe left | viewer.dragFeedback.delete | 21, 100, 108, 50 | 125 | 667 | yes |
| SE dark — swipe right | viewer.dragFeedback.keep | 256, 100, 99, 44 | 122 | 667 | yes |
| SE AX5 — swipe left | viewer.dragFeedback.delete | 22, 101, 241, 95 | 148 | 667 | yes |
| SE AX5 — swipe right | viewer.dragFeedback.keep | 141, 101, 212, 81 | 141 | 667 | yes |

### Fix 3 — round 44 x 44 Review button

Both Review entries are round 44 x 44 trash controls matching the control
beside them, with a red count badge and no "Review" text. At zero marks
neither exists.

| Screen | Element | x, y, w, h | Present |
| --- | --- | --- | --- |
| 11 Pro light — Viewer at 0 marks | viewer.review | — | absent (correct) |
| 11 Pro light — Viewer at 2 marks | viewer.review | 315, 50, 44, 44 | yes |
| 11 Pro light — Home at 0 marks | entry.review | — | absent (correct) |
| 11 Pro light — Home at 2 marks | entry.review | 315, 52, 44, 44 | yes |
| 11 Pro dark — Viewer at 0 marks | viewer.review | — | absent (correct) |
| 11 Pro dark — Viewer at 2 marks | viewer.review | 315, 50, 44, 44 | yes |
| 11 Pro dark — Home at 0 marks | entry.review | — | absent (correct) |
| 11 Pro dark — Home at 2 marks | entry.review | 315, 52, 44, 44 | yes |
| 11 Pro AX5 — Viewer at 0 marks | viewer.review | — | absent (correct) |
| 11 Pro AX5 — Viewer at 2 marks | viewer.review | 315, 50, 44, 44 | yes |
| 11 Pro AX5 — Home at 0 marks | entry.review | — | absent (correct) |
| 11 Pro AX5 — Home at 2 marks | entry.review | 315, 52, 44, 44 | yes |
| SE light — Viewer at 0 marks | viewer.review | — | absent (correct) |
| SE light — Viewer at 2 marks | viewer.review | 315, 26, 44, 44 | yes |
| SE light — Home at 0 marks | entry.review | — | absent (correct) |
| SE light — Home at 2 marks | entry.review | 315, 28, 44, 44 | yes |
| SE dark — Viewer at 0 marks | viewer.review | — | absent (correct) |
| SE dark — Viewer at 2 marks | viewer.review | 315, 26, 44, 44 | yes |
| SE dark — Home at 0 marks | entry.review | — | absent (correct) |
| SE dark — Home at 2 marks | entry.review | 315, 28, 44, 44 | yes |
| SE AX5 — Viewer at 0 marks | viewer.review | — | absent (correct) |
| SE AX5 — Viewer at 2 marks | viewer.review | 315, 26, 44, 44 | yes |
| SE AX5 — Home at 0 marks | entry.review | — | absent (correct) |
| SE AX5 — Home at 2 marks | entry.review | 315, 28, 44, 44 | yes |

## Round 3 — Home matches the approved design

Reference: `docs/design/orange-porcelain/01-setup.png` (Home is the top-left
light phone and the bottom-left dark phone) and the 01-setup palette in
`docs/design/orange-porcelain/PROMPTS.md`. Side-by-side comparison:
[`round-3/home-compare.png`](round-3/home-compare.png). The Simulator was seeded
with 16 generated sample photos plus a short beach video
([`round-3/generate_samples.py`](round-3/generate_samples.py)); the test suites
keep using the fake library.

### Palette (sampled, not by eye)

[`round-3/sample_colours.py`](round-3/sample_colours.py) reads a known region per
token from the reference board and from the captured Home screenshots. Channels
are quantised to multiples of 6, so a current value can land a couple of units
from the code token.

| Token | reference (sampled) | current before | current after | code token |
| --- | --- | --- | --- | --- |
| light background | #FAFAF9 | #FCF6EF | #F8F8F6 | `#F8F8F6` |
| light surface | #F5F4F3 | #FCF6EF / #FFFFFF | #FFFFFF | `#FFFFFF` |
| light wordmark | #C04812 | #BA4E12 | #C05A1E | `#C05A20` |
| light heading | #000000 | #181818 | #242424 | `#272724` |
| light accent | #EA8A42 | #BA4E12 | #C05A1E | `#C05A20` |
| light secondary | #7E7E7E | #6C6660 | #6C6660 | `#6E6A64` |
| dark background | #1A1B19 | #141614 | #191A18 | `#191A18` |
| dark surface | #292927 | #1F211E | #2C2D29 | `#2C2D29` |
| dark wordmark | #A85A1E | #DE7836 | #F0A266 | `#F2A66B` |
| dark heading | #FCFCFC | #F0F0EA | #F0F0EA | `#F5F3EF` |
| dark accent | #D29C5A | #DE7836 | #F0A266 | `#F2A66B` |
| dark secondary | #A2A2A2 | #B4AEA8 | #B4AEA8 | `#B4B1AA` |

The reference's ink renders near-black in light and near-white in dark in the
mockup, so its heading sample is not the ink token; every other token lands on
the approved colour. The seven tokens the board pins are exactly `#F8F8F6`,
`#FFFFFF`, `#C05A20`, `#272724`, `#191A18`, `#2C2D29` and `#F2A66B`, and the
code now uses those literals (the `Color(hex:)` initialiser in
`SWIPR/Views/EntryView.swift`).

### Structure against the reference

Matches: the compact orange **SWIPR** wordmark on the leading edge and the gear on
the trailing edge; the "What are we cleaning today?" heading; a wide
**Everything** card carrying three overlapping photo prints; two square
**Photos** and **Videos** cards with real thumbnails (Videos shows a play badge);
the **Continue sorting** row with a photo thumbnail; **Your impact**.

### Fixed

1. Palette: all seven approved tokens, replacing the old warm-cream/orange set.
2. Wordmark: moved from a 30 pt centred line to the compact 18 pt leading wordmark.
3. Heading: 34 pt `largeTitle` to 28 pt bold.
4. Everything card: one 128 pt photo to a 168 pt card with three overlapping,
   white-bordered and rotated photo prints, with a bottom scrim under the label.
5. Photos/Videos cards: 128 pt banners to square (1:1) cards with real
   thumbnails; a video gets a play badge.
6. Corner radius 18 to 20; the Continue sorting leading glyph is replaced by the
   session's own photo thumbnail.
7. A supporting fix so the cards could show the photos at all:
   `PhotoKitLibrary.thumbnail` requested `.fastFormat`, which fails with
   `PHPhotosErrorDomain 3303` ("No resource found matching image request spec")
   on ordinary stills and left every card on its placeholder. It now requests
   `.highQualityFormat`. This is image loading only — not deletion, saved state
   or any flow.

### Not fixed (owner decision or out of scope)

- The reference's **"Review 12 marked items"** row is not built. The round-2
  round 44 x 44 trash button with the red count badge is the review entry (owner
  decision); it sits next to the gear.
- **Your impact** is absent from the capture because the seeded library has no
  confirmed deletions yet; it appears once a deletion is confirmed.
- The reference's stock photos are replaced by the generated samples, and its
  "Photos · September" subtitle is the real saved filter name ("Everything").
- The no-progress Home is captured separately in
  `round-3/current-*-home-empty-*.png`; the reference only shows the
  progress-plus-marks state.

## Round 4 — Home polish against the reference

Owner review of `round-3/home-compare.png` asked for real photos, larger type
and cards, a screen that fills to the bottom, the Continue row's month subtitle,
a visible light-mode status bar and a seeded "Your impact". Artifacts live in
[`round-4/`](round-4); [`round-4/home-compare.png`](round-4/home-compare.png) is
the reference on the left and the current build on the right, light and dark.

**Media.** Twenty real photos from [picsum.photos](https://picsum.photos) (fixed
seeds) and one short ffmpeg clip, downloaded by
[`round-4/fetch_media.sh`](round-4/fetch_media.sh) and seeded onto a clean
`SWIPR iPhone 11 Pro` with `xcrun simctl addmedia`.
[`round-4/seed_state.py`](round-4/seed_state.py) writes the screenshot store —
`statistics.json` with 2.4 GB / 860 items and a 12-mark session — using the real
asset identifiers from the simulator's Photos database, so the app's own
reconciliation keeps them. The app's tests keep using `FakePhotoLibrary`.
[`round-4/capture.sh`](round-4/capture.sh) installs, seeds and captures.

### Fixed

1. **Type and weight.** The wordmark is 22 pt bold orange with the heading
   directly below it (no large gap); the heading is 30 pt bold with tighter
   leading. Card labels are 22 pt bold white with a shadow/scrim, bottom-left;
   the Continue row's title is 17 pt semibold over its footnote subtitle.
2. **Filled layout.** The Everything card is 248 pt tall; its middle print is
   the largest and sits in front, with white borders and slight rotations.
   Photos and Videos stay square with 12 pt gaps, and the "Your impact" row now
   closes the page, so there is no large empty band on the 812 pt phone.
3. **Real photos and thumbnails.** The card covers are real photographs, and
   each thumbnail is now requested at the card size in points × `displayScale`
   with `PHImageContentMode.aspectFill`, so nothing is upscaled. (The viewer
   keeps its aspect-fit display request.)
4. **Continue sorting.** A 48 pt rounded thumbnail, the subtitle
   `"<filter> · <month>"` (`Everything · October` here; the month comes from the
   photo the session will next show), and a filled surface with no outline.
5. **Status bar.** The window scheme is now decided in `RootView`
   (`statusBarScheme`): the porcelain Home and filters render dark text on light
   and the dark viewer chrome keeps light text. The shipped default is still
   dark — only the `-uiTestingForceLight` / `-uiTestingForceDark` seam changes
   it — and the debug-only dock prototype keeps its own dark scheme.
6. **Your impact** appears with the seeded confirmed deletions, worded exactly
   as the reference: "About 2.4 GB freed · 860 items deleted".

### Not fixed (owner decision or out of scope)

- The reference's **"Review 12 marked items"** row is not built; the round
  44 × 44 trash button with the red badge remains the review entry (owner
  decision from round 2).
- The reference is a wider-aspect mockup with a Dynamic Island, while the
  capture is a 375 × 812 iPhone 11 Pro with a notch, so the rows never line up
  pixel for pixel.
- The reference's stock photos are replaced by the picsum samples, and the
  reference's September is the seeded asset's October.
- Landscape, iPad, VoiceOver order and real-device haptics/motion remain untested
  (see (c) above).

### Result

Full local suite green on `SWIPR iPhone 11 Pro`: **233 kit + 55 app + 83 UI =
371 tests, 0 failures**, `** TEST SUCCEEDED **`. No test was skipped, weakened or
removed, and none needed a new expectation.
