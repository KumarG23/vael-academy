"""Sprite authoring lib: ASCII grid -> PNG, zoom renders, compare cards.

Grid convention: list of strings, one char per pixel.
'.' = transparent. Every other char must be in the sprite's PALETTE dict.
"""
from PIL import Image
import os

SCRATCH = os.path.dirname(os.path.abspath(__file__))
REVIEW = "/Users/nealsharma/code/Vael Academy/assets/art_review/aw8_kai_v2"


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def render(grid, palette, path_1x, scale=8, path_big=None):
    h = len(grid)
    w = max(len(r) for r in grid)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    unknown = set()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            if ch not in palette:
                unknown.add(ch)
                continue
            px[x, y] = palette[ch]
    if unknown:
        raise ValueError(f"unknown chars in grid: {sorted(unknown)}")
    img.save(path_1x)
    if path_big:
        big = img.resize((w * scale, h * scale), Image.NEAREST)
        # dark card background so it reads like the samples
        card = Image.new("RGBA", big.size, (26, 26, 26, 255))
        card.alpha_composite(big)
        card.save(path_big)
    return img


def validate_grid(grid, width):
    """Check all rows are exactly `width` chars; report offenders."""
    bad = [(i, len(r)) for i, r in enumerate(grid) if len(r) != width]
    if bad:
        raise ValueError(f"rows with wrong width (want {width}): {bad}")


def compare_card(pairs, out_path, cell_h=520, pad=24, bg=(26, 26, 26, 255)):
    """pairs: list of (label, PIL.Image or path). Renders each scaled to cell_h
    high (nearest), side by side, labels omitted (pure pixels)."""
    imgs = []
    for label, im in pairs:
        if isinstance(im, str):
            im = Image.open(im).convert("RGBA")
        s = cell_h // im.size[1]
        s = max(1, s)
        imgs.append((label, im.resize((im.size[0] * s, im.size[1] * s), Image.NEAREST)))
    W = sum(i.size[0] for _, i in imgs) + pad * (len(imgs) + 1)
    H = max(i.size[1] for _, i in imgs) + pad * 2
    card = Image.new("RGBA", (W, H), bg)
    x = pad
    for label, i in imgs:
        card.alpha_composite(i, (x, H - pad - i.size[1]))
        x += i.size[0] + pad
    card.save(out_path)
    return out_path
