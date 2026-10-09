#!/usr/bin/env python3
"""Generate natural-looking sample JPEGs and seed the booted Simulator.

Used only to judge the Home cards against the approved design; the app's own
tests keep using FakePhotoLibrary. Every scene is built from fractal-noise
texture and gradients — no text labels and no flat colour blocks — then
grain, a soft vignette and JPEG compression are applied.

Usage: python3 generate_samples.py [--seed]
"""
from __future__ import annotations

import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples")
W, H = 1600, 1200


def fbm(width, height, octaves=5, seed=0, roughness=0.55):
    rng = np.random.default_rng(seed)
    out = np.zeros((height, width), np.float32)
    amp, total = 1.0, 0.0
    for octave in range(octaves):
        res = 2 ** (octave + 2)
        grid = rng.random((res, res)).astype(np.float32)
        up = np.asarray(
            Image.fromarray((grid * 255).astype(np.uint8)).resize((width, height), Image.BICUBIC),
            np.float32,
        ) / 255.0
        out += up * amp
        total += amp
        amp *= roughness
    return out / total


def vgradient(width, height, top, bottom):
    t = np.linspace(0, 1, height, dtype=np.float32)[:, None]
    top = np.array(top, np.float32)
    bottom = np.array(bottom, np.float32)
    base = top[None, None, :] * (1 - t)[:, :, None] + bottom[None, None, :] * t[:, :, None]
    return np.repeat(base, width, axis=1)


def mix(image, colour, mask):
    colour = np.array(colour, np.float32)
    mask = np.asarray(mask, np.float32)
    if mask.ndim == 3:
        mask = mask[:, :, 0]
    mask = np.clip(mask, 0, 1)[:, :, None]
    return image * (1 - mask) + colour[None, None, :] * mask


def vignette(image, strength=0.28):
    h, w, _ = image.shape
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    mask = np.clip((d - 0.55) / 0.75, 0, 1) * strength
    return image * (1 - mask[:, :, None])


def grain(image, amount=5.0, seed=7):
    noise = np.random.default_rng(seed).normal(0, amount, image.shape[:2])[:, :, None]
    return np.clip(image + noise, 0, 255)


def finish(array, name, seed=7):
    array = vignette(array)
    array = grain(array, seed=seed)
    image = Image.fromarray(np.clip(array, 0, 255).astype(np.uint8))
    image = image.filter(ImageFilter.GaussianBlur(0.6))
    image.save(os.path.join(OUT, f"{name}.jpg"), "JPEG", quality=88)
    return os.path.join(OUT, f"{name}.jpg")


def sky_mountains(seed):
    clouds = fbm(W, H, 5, seed)
    sky = vgradient(W, H, (38, 78, 150), (232, 206, 170))
    sky = mix(sky, (255, 250, 245), np.clip((clouds - 0.45) * 2.2, 0, 1) * np.linspace(1, 0.2, H)[:, None])
    y, x = np.mgrid[0:H, 0:W]
    sun = np.exp(-(((x - W * 0.74) / 150) ** 2 + ((y - H * 0.2) / 150) ** 2))
    sky = mix(sky, (255, 244, 214), sun * 0.9)
    ridge = fbm(W, H, 6, seed + 11)
    ground = 0.58
    horizon = y / H
    mountain = np.clip((ridge - 0.42) * 6, 0, 1) * np.clip((ground - horizon) * 4, 0, 1)
    far = mix(sky, (96, 116, 150), np.clip((fbm(W, H, 4, seed + 21) - 0.38) * 5, 0, 1) * np.clip((ground + 0.1 - horizon) * 4, 0, 1))
    far = mix(far, (78, 98, 134), np.clip((ridge - 0.4) * 5, 0, 1) * np.clip((ground - horizon) * 4, 0, 1))
    water = vgradient(W, H, (60, 92, 118), (30, 54, 78))
    ripple = np.clip((fbm(W, H, 3, seed + 31) - 0.5) * 1.4 + 0.5, 0, 1)
    water = mix(water, (150, 180, 196), ripple * 0.35)
    out = np.where(horizon[:, :, None] < ground, mix(far, (110, 130, 150), mountain), water)
    return out


def beach(seed):
    clouds = fbm(W, H, 5, seed)
    sky = vgradient(W, H, (96, 158, 214), (250, 226, 196))
    sky = mix(sky, (255, 252, 246), np.clip((clouds - 0.5) * 2.4, 0, 1))
    texture = fbm(W, H, 5, seed + 41)
    sea = mix(vgradient(W, H, (52, 120, 156), (36, 96, 132)), (150, 200, 214), np.clip((texture - 0.5) * 2, 0, 1) * 0.4)
    sand = mix(vgradient(W, H, (222, 198, 158), (196, 166, 126)), (240, 224, 190), np.clip((texture - 0.5) * 2.5, 0, 1) * 0.5)
    y = np.mgrid[0:H, 0:W][0] / H
    out = np.where((y < 0.5)[:, :, None], sky, np.where((y < 0.62)[:, :, None], sea, sand))
    foam = np.exp(-((y - 0.615) ** 2) / 0.0006)[:, :, None] * (0.5 + 0.5 * texture[:, :, None])
    return mix(out, (248, 248, 244), foam * 0.8)


def forest(seed):
    canopy = fbm(W, H, 6, seed)
    base = vgradient(W, H, (40, 74, 52), (108, 138, 84))
    base = mix(base, (150, 170, 110), np.clip((canopy - 0.5) * 2, 0, 1) * 0.5)
    base = mix(base, (18, 40, 26), np.clip((0.45 - canopy) * 3, 0, 1))
    yy, xx = np.mgrid[0:H, 0:W]
    rng = random.Random(seed)
    for _ in range(26):
        cx = rng.uniform(0, W)
        top = rng.uniform(0.05, 0.45) * H
        spread = rng.uniform(90, 220)
        canopy_blob = np.exp(-(((xx - cx) / spread) ** 2 + ((yy - top) / (H * 0.28)) ** 2))
        base = mix(base, (30, 64, 40), canopy_blob * 0.9)
        trunk = (np.abs(xx - cx) < spread * 0.09) & (yy > top)
        base = mix(base, (40, 32, 26), trunk.astype(np.float32) * 0.85)
    base = mix(base, (34, 60, 38), np.clip((yy / H - 0.75) * 3, 0, 1))
    return base


def city(seed):
    clouds = fbm(W, H, 5, seed)
    sky = vgradient(W, H, (28, 36, 62), (226, 142, 96))
    sky = mix(sky, (250, 180, 130), np.clip((clouds - 0.55) * 2, 0, 1) * 0.5)
    rng = random.Random(seed)
    draw = ImageDraw.Draw(Image.fromarray(np.zeros((H, W, 3), np.uint8)))
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    x = -30
    while x < W + 30:
        w = rng.randint(50, 130)
        h = rng.randint(120, 420)
        md.rectangle([x, H - h, x + w, H], fill=255)
        x += w + rng.randint(6, 22)
    mask = np.asarray(mask, np.float32) / 255
    out = mix(sky, (40, 44, 70), mask)
    lights = (fbm(W, H, 4, seed + 51) > 0.72).astype(np.float32) * mask
    return mix(out, (255, 214, 140), lights * 0.9)


def portrait(seed):
    rng = random.Random(seed)
    bg = fbm(W, H, 4, seed)
    warm = rng.choice([(214, 176, 150), (176, 150, 190), (150, 182, 200)])
    base = vgradient(W, H, warm, (90, 70, 66))
    base = mix(base, (240, 220, 200), np.clip((bg - 0.5) * 1.6, 0, 1) * 0.25)
    bokeh = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    for _ in range(40):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H * 0.7)
        r = rng.uniform(40, 130)
        bokeh += np.exp(-(((xx - cx) / r) ** 2 + ((yy - cy) / r) ** 2)) * rng.uniform(0.2, 0.6)
    base = np.clip(base + bokeh[:, :, None] * 90, 0, 255)
    draw = ImageDraw.Draw(Image.fromarray(np.zeros((H, W, 3), np.uint8)))
    skin = rng.choice([(232, 192, 168), (198, 152, 120), (150, 108, 84)])
    shirt = rng.choice([(58, 78, 120), (150, 70, 60), (70, 110, 90), (200, 150, 70)])
    hair = rng.choice([(38, 28, 24), (92, 60, 34), (24, 24, 30)])
    cx = W * 0.5
    person = Image.new("L", (W, H), 0)
    pd = ImageDraw.Draw(person)
    pd.ellipse([cx - 150, H * 0.26, cx + 150, H * 0.26 + 300], fill=255)
    pd.ellipse([cx - 270, H * 0.58, cx + 270, H * 1.2], fill=255)
    pm = np.asarray(person, np.float32) / 255
    hair_mask = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hair_mask)
    hd.chord([cx - 158, H * 0.24, cx + 158, H * 0.55], 180, 360, fill=255)
    hm = np.asarray(hair_mask, np.float32) / 255
    base = mix(base, shirt, np.clip(pm - hm, 0, 1))
    base = mix(base, skin, np.clip(pm * (1 - hm), 0, 1))
    base = mix(base, hair, hm)
    return base


def coffee(seed):
    rng = random.Random(seed)
    table = mix(vgradient(W, H, (238, 228, 212), (150, 122, 96)), (250, 240, 224), fbm(W, H, 4, seed) * 0.3)
    draw = ImageDraw.Draw(Image.fromarray(np.zeros((H, W, 3), np.uint8)))
    cup = Image.new("L", (W, H), 0)
    cd = ImageDraw.Draw(cup)
    cd.ellipse([W * 0.28, H * 0.24, W * 0.72, H * 0.24 + W * 0.46], fill=255)
    cm = np.asarray(cup, np.float32) / 255
    out = mix(table, (246, 244, 238), cm)
    liquid = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(liquid)
    ld.ellipse([W * 0.32, H * 0.29, W * 0.68, H * 0.29 + W * 0.38], fill=255)
    lm = np.asarray(liquid, np.float32) / 255
    crema = mix(np.zeros((H, W, 3), np.float32), (110, 74, 48), fbm(W, H, 4, seed + 3))
    out = mix(out, (60, 38, 26), lm)
    out = mix(out, (140, 96, 60), lm * np.clip(fbm(W, H, 3, seed + 9), 0.3, 0.8))
    return out


def pizza(seed):
    yy, xx = np.mgrid[0:H, 0:W]
    table = mix(vgradient(W, H, (226, 216, 196), (176, 148, 116)), (240, 232, 214), fbm(W, H, 4, seed) * 0.3)
    r = min(W, H) * 0.34
    cx, cy = W * 0.5, H * 0.5
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    crust = np.clip((r - d) / 30, 0, 1) * (d > r * 0.86)
    cheese = np.clip((r * 0.88 - d) / 20, 0, 1)
    sauce = np.clip((r * 0.82 - d) / 20, 0, 1)
    out = mix(table, (214, 170, 96), np.clip((r - d) / 20, 0, 1))
    out = mix(out, (196, 78, 48), sauce)
    out = mix(out, (236, 200, 130), cheese * np.clip(fbm(W, H, 3, seed + 5) + 0.4, 0, 1))
    rng = random.Random(seed)
    for _ in range(30):
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0, r * 0.7)
        px, py = cx + rr * np.cos(a), cy + rr * np.sin(a)
        topping = np.exp(-(((xx - px) / 26) ** 2 + ((yy - py) / 26) ** 2))
        out = mix(out, rng.choice([(238, 236, 226), (190, 40, 40), (70, 130, 60), (60, 110, 55)]), topping)
    return out


def tulips(seed):
    base = mix(vgradient(W, H, (96, 150, 84), (44, 92, 58)), (140, 180, 110), fbm(W, H, 4, seed) * 0.4)
    yy, xx = np.mgrid[0:H, 0:W]
    rng = random.Random(seed)
    for _ in range(90):
        cx, cy = rng.uniform(0, W), rng.uniform(H * 0.1, H)
        r = rng.uniform(20, 52)
        blob = np.exp(-(((xx - cx) / r) ** 2 + ((yy - cy) / r) ** 2))
        base = mix(base, rng.choice([(226, 74, 96), (248, 196, 72), (244, 240, 236), (232, 122, 56), (180, 70, 140)]), blob * 0.9)
    return base


def desert(seed):
    base = vgradient(W, H, (238, 186, 128), (198, 118, 78))
    dunes = fbm(W, H, 5, seed)
    yy = np.mgrid[0:H, 0:W][0]
    bands = np.zeros((H, W), np.float32)
    for i in range(5):
        edge = 0.35 + i * 0.11
        bands += np.clip((dunes - edge) * 4, 0, 1) * (yy / H > edge)
    base = mix(base, (176, 96, 62), np.clip(bands, 0, 1) * 0.5)
    base = mix(base, (250, 214, 160), np.clip((dunes - 0.55) * 3, 0, 1) * 0.4)
    return base


def snow(seed):
    base = vgradient(W, H, (70, 110, 168), (222, 230, 238))
    rock = fbm(W, H, 6, seed)
    base = mix(base, (60, 74, 96), np.clip((rock - 0.5) * 4, 0, 1) * np.clip(np.linspace(1.2, 0, H)[:, None], 0, 1))
    snow = np.clip((fbm(W, H, 5, seed + 8) - 0.42) * 3, 0, 1)
    return mix(base, (248, 250, 252), snow * 0.7)


SCENES = [
    ("01-mountain-lake", sky_mountains),
    ("02-sunset-beach", beach),
    ("03-forest-path", forest),
    ("04-city-dusk", city),
    ("05-portrait-a", portrait),
    ("06-portrait-b", portrait),
    ("07-coffee-cup", coffee),
    ("08-pizza", pizza),
    ("09-tulip-field", tulips),
    ("10-desert-dunes", desert),
    ("11-snow-peak", snow),
    ("12-harbour", beach),
    ("13-pines", forest),
    ("14-skyline-night", city),
    ("15-portrait-c", portrait),
    ("16-espresso", coffee),
]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    paths = []
    for index, (name, builder) in enumerate(SCENES):
        paths.append(finish(builder(index + 1), name, seed=index + 7))
    print("\n".join(paths))
    if "--seed" in sys.argv:
        subprocess.run(["xcrun", "simctl", "addmedia", "booted", *paths], check=True)


if __name__ == "__main__":
    main()
