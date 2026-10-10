#!/usr/bin/env python3
"""Sample the Home palette with fixed coordinates (not by eye).

Each token is read from a region whose role is known: the page margin, a card
interior, a wordmark stroke, the title ink, the orange tray symbol and the
secondary caption. Orange tokens use the dominant (modal) colour so
anti-aliasing does not drag the sample light. Run with `before` or `after` to
read the matching current screenshots.
"""
from __future__ import annotations

import os
import sys

from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
BOARD = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "docs", "design", "orange-porcelain", "01-setup.png"))
REFERENCE_BOXES = {"light": (265, 62, 470, 487), "dark": (265, 548, 470, 973)}

# Reference Home, in crop-local point coordinates (205 x 425 crop).
REFERENCE_REGIONS = {
    "wordmark": (8, 27, 48, 41),
    "heading": (8, 48, 140, 86),
    "accent": (28, 340, 54, 368),
    "secondary": (54, 300, 144, 318),
    "surface": (150, 286, 196, 318),
    "background": (0, 90, 10, 280),
}

# Current Home, in 375 x 812 point coordinates, for each layout generation.
BEFORE_REGIONS = {
    "wordmark": (142, 112, 234, 150),
    "heading": (16, 168, 267, 250),
    "accent": (29, 575, 53, 598),
    "secondary": (66, 590, 132, 606),
    "surface": (150, 580, 340, 615),
    "background": (0, 90, 8, 280),
}
AFTER_REGIONS = {
    "wordmark": (16, 58, 78, 88),
    "heading": (16, 114, 224, 181),
    "accent": (16, 58, 78, 88),
    "secondary": (84, 596, 152, 618),
    "surface": (150, 572, 340, 615),
    "background": (0, 90, 8, 280),
}
CURRENT_REGIONS = {"before": BEFORE_REGIONS, "after": AFTER_REGIONS}


def hexof(pixel) -> str:
    return "#{:02X}{:02X}{:02X}".format(*(int(round(max(0, min(255, v)))) for v in pixel[:3]))


def cut(array, box):
    x0, y0, x1, y1 = box
    return array[y0:y1, x0:x1].reshape(-1, 3)


def median_of(flat, predicate=lambda p: np.ones(len(p), bool)):
    chosen = flat[predicate(flat)]
    if chosen.size == 0:
        return "n/a"
    return hexof(np.median(chosen.reshape(-1, 3), axis=0))


def dominant_of(flat, predicate):
    chosen = flat[predicate(flat)]
    if chosen.size == 0:
        return "n/a"
    quantised = (chosen // 6 * 6).astype(int)
    values, counts = np.unique(quantised, axis=0, return_counts=True)
    return hexof(values[counts.argmax()])


def analyse(array, regions, dark: bool) -> dict:
    orange = lambda p: (p[:, 0] - p[:, 2]) > 45
    ink = (lambda p: p.sum(axis=1) < 330) if not dark else (lambda p: p.sum(axis=1) > 560)
    secondary = (lambda p: (p.sum(axis=1) > 260) & (p.sum(axis=1) < 560)) if not dark else \
        (lambda p: (p.sum(axis=1) > 250) & (p.sum(axis=1) < 560))
    return {
        "background": median_of(cut(array, regions["background"])),
        "surface": median_of(cut(array, regions["surface"])),
        "wordmark": dominant_of(cut(array, regions["wordmark"]), orange),
        "heading": dominant_of(cut(array, regions["heading"]), ink),
        "accent": dominant_of(cut(array, regions["accent"]), orange),
        "secondary": dominant_of(cut(array, regions["secondary"]), secondary),
    }


def scaled(box, scale) -> tuple:
    return tuple(round(value * scale) for value in box)


def main() -> None:
    state = sys.argv[1] if len(sys.argv) > 1 else "before"
    board = Image.open(BOARD)
    tokens = ("background", "surface", "wordmark", "heading", "accent", "secondary")
    for appearance in ("light", "dark"):
        dark = appearance == "dark"
        reference = analyse(np.asarray(board.crop(REFERENCE_BOXES[appearance]).convert("RGB"), np.float32), REFERENCE_REGIONS, dark)
        empty_array = np.asarray(Image.open(os.path.join(HERE, f"current-{state}-home-empty-{appearance}.png")).convert("RGB"), np.float32)
        progress_array = np.asarray(Image.open(os.path.join(HERE, f"current-{state}-home-progress-{appearance}.png")).convert("RGB"), np.float32)
        scale = empty_array.shape[0] / 812.0
        regions = {key: scaled(box, scale) for key, box in CURRENT_REGIONS[state].items()}
        empty = analyse(empty_array, regions, dark)
        progress = analyse(progress_array, regions, dark)
        print(f"### {appearance}")
        print("| Token | reference | current (no progress) | current (progress + marks) |")
        print("| --- | --- | --- | --- |")
        for token in tokens:
            print(f"| {token} | {reference[token]} | {empty[token]} | {progress[token]} |")
        print()


if __name__ == "__main__":
    main()
