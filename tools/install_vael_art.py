#!/usr/bin/env python3
"""AW-66: matte + install the Vael town building art.
Corner flood-fill (PixelLab's 'transparent' ships opaque), crop to bbox,
install to assets/art/pixellab/buildings/vael/. Then run:
  godot --headless --import && godot --headless --script tools/build_vael_town.gd
"""
import pathlib
from collections import deque
from PIL import Image

SRC = pathlib.Path("assets/source/pixellab/vael_town")
DST = pathlib.Path("assets/art/pixellab/buildings/vael")
DST.mkdir(parents=True, exist_ok=True)


def matte(im, tol=46):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    bg = px[0, 0][:3]
    near = lambda c: all(abs(c[i] - bg[i]) <= tol for i in range(3))
    seen = [[False] * w for _ in range(h)]
    dq = deque()
    for x in range(w):
        dq += [(x, 0), (x, h - 1)]
    for y in range(h):
        dq += [(0, y), (w - 1, y)]
    while dq:
        x, y = dq.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        if not near(px[x, y][:3]):
            continue
        px[x, y] = (0, 0, 0, 0)
        dq += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    bb = im.getbbox()
    return im.crop(bb) if bb else im


for p in sorted(SRC.glob("*.png")):
    im = matte(Image.open(p))
    out = DST / p.name
    im.save(out)
    print(f"{out.name}: {im.size}")
print("install complete")
