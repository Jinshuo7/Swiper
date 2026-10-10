#!/usr/bin/env python3
"""Build the Round 4 Home comparison: reference left, current right, two rows.

Both phone images are scaled to the same height, so the layouts can be read side
by side. Overwrites `home-compare.png` next to this script.

Usage: python3 make_compare.py
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROUND3 = os.path.join(HERE, "..", "round-3")

PHONE_HEIGHT = 820
PAD = 22
HEADER = 120
LABEL = 30


def font(size: int) -> ImageFont.FreeTypeFont:
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


def scaled(path: str) -> Image.Image:
    image = Image.open(path).convert("RGB")
    ratio = PHONE_HEIGHT / image.height
    return image.resize((round(image.width * ratio), PHONE_HEIGHT), Image.LANCZOS)


def main() -> None:
    rows = [
        ("LIGHT", os.path.join(ROUND3, "reference-home-light.png"), os.path.join(HERE, "current-home-light.png")),
        ("DARK", os.path.join(ROUND3, "reference-home-dark.png"), os.path.join(HERE, "current-home-dark.png")),
    ]
    phones = [(scaled(left), scaled(right)) for _, left, right in rows]
    column = max(max(left.width, right.width) for left, right in phones)
    width = PAD + 2 * (column + PAD)
    height = HEADER + len(rows) * (PHONE_HEIGHT + LABEL + PAD) + PAD
    sheet = Image.new("RGB", (width, height), (247, 247, 245))
    draw = ImageDraw.Draw(sheet)

    draw.text((PAD, 22), "Approved reference (left)  ·  Current build (right)", fill=(30, 30, 30), font=font(30))
    draw.text((PAD, 64), "Round 4 — Home polish: real photos, scale, filled layout, status bar", fill=(120, 120, 120), font=font(18))

    for index, (label, _, _) in enumerate(rows):
        left, right = phones[index]
        top = HEADER + index * (PHONE_HEIGHT + LABEL + PAD)
        draw.text((PAD + 2, top - LABEL + 2), f"{label} — reference", fill=(150, 90, 40), font=font(20))
        draw.text((PAD + PAD + column, top - LABEL + 2), f"{label} — current", fill=(150, 90, 40), font=font(20))
        for column_index, phone in enumerate((left, right)):
            x = PAD + column_index * (column + PAD) + (column - phone.width) // 2
            sheet.paste(phone, (x, top))
            draw.rectangle([x - 1, top - 1, x + phone.width, top + phone.height], outline=(180, 180, 180))

    output = os.path.join(HERE, "home-compare.png")
    sheet.save(output, "PNG", optimize=True)
    print(output)


if __name__ == "__main__":
    main()
