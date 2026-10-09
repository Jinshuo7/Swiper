#!/usr/bin/env python3
"""Playtest round 1 asset pipeline.

Exports XCTest screenshots and layout dumps from an `.xcresult`, stages the
screenshots as resized PNGs under `before/` and `after/`, prints markdown layout
tables, and builds 3x4 labelled contact sheets.

Usage:
  python3 make_assets.py stage   <bundle.xcresult> <before|after> [suffix]
  python3 make_assets.py layout  <bundle.xcresult>
  python3 make_assets.py sheets  <after-dir> <repo-after-dir>
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
XCRUN = ["xcrun", "xcresulttool", "export", "attachments"]
DEV = "/Applications/Xcode.app/Contents/Developer"
SHEET_COLUMNS = 3
SHEET_ROWS = 4


def export(bundle: str, outdir: str) -> str:
    if os.path.isdir(outdir):
        shutil.rmtree(outdir)
    env = dict(os.environ, DEVELOPER_DIR=DEV)
    subprocess.run(
        XCRUN + ["--path", bundle, "--output-path", outdir],
        check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return os.path.join(outdir, "manifest.json")


def attachments(manifest: str) -> Dict[str, str]:
    """Map the human-readable attachment name (without the UUID tail) to its
    exported file name. Layout dumps keep the marker so callers can split."""
    data = json.load(open(manifest))
    rows = [a for entry in data for a in entry["attachments"]]
    result: Dict[str, str] = {}
    for row in rows:
        name = row["suggestedHumanReadableName"]
        # "01-home-light_0_UUID.png" -> "01-home-light.png"; the extension lives
        # after the UUID tail, so it is rebuilt from the tail.
        ext = "." + name.rsplit(".", 1)[-1]
        stem = name.split("_0_")[0] + ext
        result[stem] = row["exportedFileName"]
    return result


def resize_to_width(src: str, dst: str, width: int = 600) -> None:
    image = Image.open(src).convert("RGBA")
    ratio = width / image.width
    image = image.resize((width, max(1, round(image.height * ratio))), Image.LANCZOS)
    image.save(dst, "PNG", optimize=True)


def stage(bundle: str, phase: str, suffix: str = "") -> Tuple[str, str]:
    tmp = tempfile.mkdtemp(prefix="playtest-export-")
    manifest = export(bundle, tmp)
    files = attachments(manifest)
    shots = {k: v for k, v in files.items() if k.endswith(".png")}
    dumps = {k.replace(" — layout.txt", ""): v for k, v in files.items() if k.endswith(" — layout.txt")}
    out = os.path.join(HERE, phase)
    os.makedirs(out, exist_ok=True)
    staged = {}
    for name in sorted(shots):
        base = name[:-4]
        dst = os.path.join(out, f"{base}{suffix}.png")
        resize_to_width(os.path.join(tmp, shots[name]), dst)
        staged[name] = dst
    # Keep the raw layout dumps next to the images for the report generator.
    raw = os.path.join(HERE, f"_{phase}{suffix}-layout.json")
    json.dump(
        {k: open(os.path.join(tmp, v)).read() for k, v in dumps.items()},
        open(raw, "w"), indent=1,
    )
    return out, raw


def sheets(after_dir: str, out_dir: str, copy_dir: str) -> List[str]:
    names = sorted(
        n for n in os.listdir(after_dir)
        if n.endswith(".png") and not n.startswith("sheet-")
    )
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(copy_dir, exist_ok=True)
    made = []
    per_sheet = SHEET_COLUMNS * SHEET_ROWS
    for index in range(0, len(names), per_sheet):
        chunk = names[index:index + per_sheet]
        made.append(_sheet(chunk, after_dir, os.path.join(out_dir, f"sheet-{index // per_sheet + 1}.png")))
    for path in made:
        shutil.copy2(path, os.path.join(copy_dir, os.path.basename(path)))
    return made


def _font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        if os.path.exists(candidate):
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                pass
    return ImageFont.load_default()


def _sheet(names: List[str], after_dir: str, out: str) -> str:
    thumb_w, thumb_h = 300, 520
    pad, label_h, title_h = 18, 34, 60
    width = SHEET_COLUMNS * (thumb_w + pad) + pad
    height = title_h + SHEET_ROWS * (thumb_h + label_h + pad) + pad
    sheet = Image.new("RGB", (width, height), (28, 28, 30))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 16), f"SWIPR playtest round 1 — after ({os.path.basename(out)})", fill=(240, 240, 240), font=_font(26))
    for i, name in enumerate(names):
        col, row = i % SHEET_COLUMNS, i // SHEET_COLUMNS
        x = pad + col * (thumb_w + pad)
        y = title_h + row * (thumb_h + label_h + pad)
        image = Image.open(os.path.join(after_dir, name)).convert("RGB")
        ratio = min(thumb_w / image.width, thumb_h / image.height)
        image = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.LANCZOS)
        ox = x + (thumb_w - image.width) // 2
        oy = y + (thumb_h - image.height) // 2
        draw.rectangle([x - 1, y - 1, x + thumb_w + 1, y + thumb_h + 1], outline=(90, 90, 96))
        sheet.paste(image, (ox, oy))
        label = name[:-4]
        draw.text((x, y + thumb_h + 8), label[:40], fill=(220, 220, 220), font=_font(15))
    sheet.save(out, "PNG", optimize=True)
    return out


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "stage":
        stage(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
    elif cmd == "sheets":
        for path in sheets(sys.argv[2], sys.argv[3], sys.argv[4]):
            print(path)
    else:
        print(f"unknown command {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
