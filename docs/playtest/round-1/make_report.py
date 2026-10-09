#!/usr/bin/env python3
"""Generate docs/playtest/round-1/REPORT.md from the captured layout dumps.

The narrative sections (a)-(c) are fixed; section (d) is built from
`_after-layout.json` (iPhone 11 Pro) and `_after-se-layout.json` (iPhone SE).
"""
from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PRO_LAYOUT = os.path.join(HERE, "_after-layout.json")
SE_LAYOUT = os.path.join(HERE, "_after-se-layout.json")

CONTROLS = {9: "button", 41: "switch", 37: "segmented", 33: "slider", 10: "radio"}

NARRATIVE = """# Playtest round 1

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
"""


def parse(dump: str):
    rows = []
    size = (375, 812)
    for line in dump.splitlines():
        parts = line.split("\t")
        if not parts:
            continue
        if parts[0] == "WINDOW":
            size = (float(parts[5]), float(parts[6]))
            continue
        if len(parts) < 7:
            continue
        rows.append(
            {
                "id": parts[0],
                "type": int(parts[1]),
                "label": parts[2],
                "x": float(parts[3]),
                "y": float(parts[4]),
                "w": float(parts[5]),
                "h": float(parts[6]),
            }
        )
    return rows, size


def flags(row, size, safe_top, safe_bottom):
    width, height = size
    out = []
    if row["type"] in CONTROLS:
        if row["w"] < 44 or row["h"] < 44:
            out.append("<44")
        if row["y"] + row["h"] / 2 > height / 2:
            out.append("bottom")
        if row["y"] < safe_top:
            out.append("notch")
        if row["y"] < height and row["y"] + row["h"] > height - safe_bottom and safe_bottom > 0:
            out.append("home")
        if row["y"] >= height:
            out.append("off-screen")
    return out


def table(title: str, dump: str, safe_top: float, safe_bottom: float) -> str:
    rows, size = parse(dump)
    visible = [r for r in rows if r["id"] != "-" and (r["type"] in CONTROLS or r["h"] > 0)]
    lines = [f"### {title}", "", f"Screen size: **{size[0]:.0f} x {size[1]:.0f} pt**.", ""]
    lines.append("| Element | x | y | width | height | Flags |")
    lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
    for row in sorted(visible, key=lambda r: (round(r["y"]), r["x"])):
        name = row["id"] if row["id"] != "-" else f'“{row["label"]}”'
        flag = ", ".join(flags(row, size, safe_top, safe_bottom)) or "—"
        lines.append(
            f"| `{name}` | {row['x']:.1f} | {row['y']:.1f} | {row['w']:.1f} | {row['h']:.1f} | {flag} |"
        )
    return "\n".join(lines) + "\n"


def label_for(name: str) -> str:
    parts = name.split("-")
    words = []
    for part in parts:
        if part == "ax5":
            words.append("AX5")
        elif part == "se":
            words.append("SE")
        else:
            words.append(part.capitalize())
    text = " ".join(words)
    return text.replace("A Photo", "a Photo")


def main() -> None:
    pro = json.load(open(PRO_LAYOUT))
    se = json.load(open(SE_LAYOUT))
    sections = [NARRATIVE, "### iPhone 11 Pro (light / dark / AX5)\n"]
    for name in sorted(pro):
        sections.append(table(label_for(name), pro[name], safe_top=44, safe_bottom=34))
    sections.append("### iPhone SE (3rd generation, light)\n")
    for name in sorted(se):
        sections.append(table("SE — " + label_for(name), se[name], safe_top=20, safe_bottom=0))
    open(os.path.join(HERE, "REPORT.md"), "w").write("\n".join(sections))
    print("wrote REPORT.md")


if __name__ == "__main__":
    main()
