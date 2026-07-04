"""Kai battle sprite v3 — built on the sample Ike base (cleared for reuse).

Pipeline: descale webp 2x -> border-flood background removal -> HSV material
classification -> luminance-mapped recolor onto Kai ramps -> mirror to face
right -> identity edits (temple mark, headband to crimson) -> render checks.
"""
from PIL import Image
import numpy as np
import colorsys
import os

OUT = os.path.dirname(os.path.abspath(__file__))
SRC = "/Users/nealsharma/code/Vael Academy/sample/my-fe-pixel-work-over-the-years-v0-lywu3r4nm4pa1.webp"


def hexc(s):
    return tuple(int(s[i:i+2], 16) for i in (0, 2, 4))


# Kai ramps, dark -> light (from the v2 palette, STYLE_BIBLE v6.1)
RAMPS = {
    "hair":    [hexc("16141f"), hexc("252537"), hexc("383d56"), hexc("525c80")],
    "cape":    [hexc("4f1216"), hexc("8c1f22"), hexc("c72929"), hexc("e05a41")],
    "uniform": [hexc("151c2b"), hexc("263650"), hexc("3d5678"), hexc("5c7ba8")],
    "skin":    [hexc("6f3b26"), hexc("a05f3a"), hexc("cf8f5e"), hexc("e8b284")],
    "leather": [hexc("362112"), hexc("5a3c1e"), hexc("82602f"), hexc("a3854a")],
    "steel":   [hexc("3d4454"), hexc("7e8a9e"), hexc("bac6d6"), hexc("eef4fa")],
    "gold":    [hexc("8a5c20"), hexc("c1902f"), hexc("edc24a"), hexc("ffeb9c")],
    "cloth":   [hexc("6b6259"), hexc("948a7d"), hexc("beb3a2"), hexc("e3dccb")],
}
OUTLINE = hexc("160d12")


def expand(ramp, n=6):
    """Piecewise-linear resample of a ramp to n stops (reduces banding)."""
    out = []
    for i in range(n):
        t = i * (len(ramp) - 1) / (n - 1)
        a, b = ramp[int(t)], ramp[min(len(ramp) - 1, int(t) + 1)]
        f = t - int(t)
        out.append(tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return out


for _name in ("cape", "cloth", "uniform", "leather", "steel"):
    RAMPS[_name] = expand(RAMPS[_name], 6)


def load_base():
    img = Image.open(SRC).convert("RGB")
    a = np.asarray(img).astype(float)
    S = 4  # true native scale (2x showed residual 2x2 blocking)
    H, W = a.shape[0] // S, a.shape[1] // S
    small = a[:H*S, :W*S].reshape(H, S, W, S, 3).mean(axis=(1, 3))
    small = small[:, ::-1]  # mirror up front: he faces right in all coords below
    # background: flood fill near-black from the borders
    dark = small.sum(axis=2) < 60
    bg = np.zeros((H, W), bool)
    stack = [(y, x) for y in range(H) for x in (0, W-1) if dark[y, x]]
    stack += [(y, x) for x in range(W) for y in (0, H-1) if dark[y, x]]
    for y, x in stack:
        bg[y, x] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < H and 0 <= nx < W and dark[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                stack.append((ny, nx))
    return small, bg


def classify(r, g, b):
    """Return material name for an RGB pixel (0-255 floats)."""
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    hue = h * 360
    if v < 0.16:
        return "outline"
    if 70 <= hue <= 180 and s > 0.25:
        return "band"          # green headband + tails
    if (hue < 22 or hue > 335) and s > 0.45:
        return "cape"          # reds
    if 180 <= hue <= 280 and s > 0.10:
        return "uniform"       # blues incl. desaturated blue-grey armor
    if 22 <= hue <= 48 and s > 0.28 and v > 0.55:
        return "skin"          # positional: outside the face box -> leather
    if 22 <= hue <= 50 and s > 0.25:
        return "leather"       # darker warm browns (belts, boots)
    if s <= 0.20 and v > 0.35:
        return "cloth"         # white tunic + its grey shadows
    if s <= 0.28:
        return "steel"
    if 48 < hue < 70 and s > 0.3:
        return "gold"
    return "steel"


def ramp_map(v, ramp, lo, hi):
    """Map luminance v in [lo,hi] onto ramp indices (round to nearest stop)."""
    t = 0.0 if hi <= lo else (v - lo) / (hi - lo)
    i = min(len(ramp) - 1, max(0, round(t * (len(ramp) - 1))))
    return ramp[i]


def build(target_band="cape"):
    small, bg = load_base()
    H, W = bg.shape
    lum = small @ np.array([0.299, 0.587, 0.114])

    # first pass: classify everything to find per-material luminance ranges
    # content origin (for positional rules in final sprite coords)
    cmask = ~bg
    cys, cxs = np.where(cmask)
    oy, ox = cys.min(), cxs.min()
    mats = np.empty((H, W), dtype=object)
    for y in range(H):
        for x in range(W):
            if bg[y, x]:
                mats[y, x] = None
                continue
            m = classify(*small[y, x])
            sx, sy = x - ox, y - oy      # sprite-local coords (faces right)
            in_face = 20 <= sx <= 37 and sy <= 14
            in_blade = sx >= 33 and sy >= 25
            if m == "skin" and not in_face:
                m = "leather"
            if m == "cloth" and in_blade:
                m = "steel"
            if m == "steel" and not in_blade and sy > 14:
                m = "cloth"
            if m == "uniform" and sy <= 7:
                m = "hair"       # hair shares Ike's blues; give it its own range
            mats[y, x] = m
    # despeckle: a pixel whose material disagrees with 3+ agreeing neighbors
    # adopts theirs (kills salt-and-pepper class flips; outline/face excluded)
    for _ in range(2):
        changes = []
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                m = mats[y, x]
                if m in (None, "outline"):
                    continue
                sx, sy = x - ox, y - oy
                if 20 <= sx <= 37 and sy <= 14:
                    continue
                nb = [mats[y-1, x], mats[y+1, x], mats[y, x-1], mats[y, x+1]]
                nb = [n for n in nb if n not in (None, "outline")]
                if len(nb) >= 3 and m not in nb:
                    top = max(set(nb), key=nb.count)
                    if nb.count(top) >= 3:
                        changes.append((y, x, top))
        for y, x, m in changes:
            mats[y, x] = m

    ranges = {}
    for m in set(RAMPS) | {"band"}:
        vs = [lum[y, x] for y in range(H) for x in range(W) if mats[y, x] == m]
        if vs:
            vs.sort()
            ranges[m] = (vs[int(len(vs)*0.05)], vs[int(len(vs)*0.95)])

    out = np.zeros((H, W, 4), dtype=np.uint8)
    for y in range(H):
        for x in range(W):
            m = mats[y, x]
            if m is None:
                continue
            if m == "outline":
                out[y, x] = (*OUTLINE, 255)
                continue
            ramp_name = target_band if m == "band" else m
            lo, hi = ranges.get(m, (0, 255))
            c = ramp_map(lum[y, x], RAMPS[ramp_name], lo, hi)
            out[y, x] = (*c, 255)

    # crop to content
    mask = out[:, :, 3] > 0
    ys, xs = np.where(mask)
    out = out[ys.min():ys.max()+1, xs.min():xs.max()+1]
    return Image.fromarray(out).copy()


MARK = hexc("c4d6e2")


def identity_edits(img):
    """Post-recolor Kai identity pass on the 1x sprite (faces right)."""
    px = img.load()
    lum = lambda c: 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
    skin = RAMPS["skin"]
    hair = RAMPS["hair"]
    # 1) unify the face box to skin (keep outline + existing skin)
    for y in range(6, 13):
        for x in range(26, 36):
            c = px[x, y]
            if c[3] == 0 or c[:3] == OUTLINE or c[:3] in skin:
                continue
            if c[:3] in hair:
                continue
            t = lum(c[:3])
            i = 0 if t < 90 else (1 if t < 140 else (2 if t < 190 else 3))
            px[x, y] = (*skin[i], 255)
    # 2) brighten the face one ramp step (our darker skin drowned Ike's shadow)
    for y in range(6, 13):
        for x in range(26, 36):
            c = px[x, y][:3]
            if c in skin:
                i = skin.index(c)
                px[x, y] = (*skin[min(3, i + 1)], 255)
    # 3) explicit facial features (facing right; face front edge x35)
    def put(x, y, c):
        px[x, y] = (*c, 255)
    # hair spikes spilling over the band read as dark hair, not skin
    for x in (29, 31, 33):
        if px[x, 5][:3] not in RAMPS["cape"]:
            put(x, 5, hair[0])
    # brow over the eye
    put(31, 7, hair[0]); put(32, 7, hair[0])
    # eye: dark pupil + lit skin beside it
    put(31, 8, OUTLINE); put(32, 8, skin[3]); put(33, 8, skin[3])
    put(31, 9, skin[1])
    # mouth tick + chin light
    put(32, 11, skin[0]); put(33, 11, skin[3])
    # temple mark: silver frost-crack at his left temple, under the band
    put(34, 6, MARK); put(35, 6, MARK)
    return img


if __name__ == "__main__":
    img = identity_edits(build())
    img.save(os.path.join(OUT, "kai_v3_raw_1x.png"))
    big = img.resize((img.size[0]*8, img.size[1]*8), Image.NEAREST)
    card = Image.new("RGBA", big.size, (26, 26, 26, 255))
    card.alpha_composite(big)
    card.save(os.path.join(OUT, "kai_v3_raw_8x.png"))
    print("v3 raw:", img.size)
