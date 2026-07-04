"""Process PixelLab 60x60 frames into engine-ready 32x32 (bottom-anchored),
plus preview sheets and GIFs. Deterministic: one shared crop window per
animation so frames don't jitter."""
from PIL import Image
import glob
import os
import sys


def shared_window(frames, out_w=32, out_h=32):
    """Union content bbox across frames -> one 32x32 window (bottom-anchored
    on the union, horizontally centered)."""
    x0 = y0 = 10**6
    x1 = y1 = -1
    for f in frames:
        b = f.getbbox()
        if b:
            x0, y0 = min(x0, b[0]), min(y0, b[1])
            x1, y1 = max(x1, b[2]), max(y1, b[3])
    cx = (x0 + x1) // 2
    left = cx - out_w // 2
    top = y1 - out_h            # anchor to feet (bottom of union bbox)
    return (left, top, left + out_w, top + out_h)


def process(src_glob, out_dir, base, duration=125, scale_preview=8):
    files = sorted(glob.glob(src_glob))
    frames = [Image.open(f).convert("RGBA") for f in files]
    if not frames:
        raise SystemExit(f"no frames match {src_glob}")
    win = shared_window(frames)
    os.makedirs(out_dir, exist_ok=True)
    outs = []
    for i, f in enumerate(frames, 1):
        c = f.crop(win)
        c.save(os.path.join(out_dir, f"{base}_f{i}.png"))
        outs.append(c)
    # preview strip
    s = scale_preview
    strip = Image.new("RGBA", (len(outs) * (32 * s + 6) + 6, 32 * s + 12), (30, 30, 34, 255))
    for i, c in enumerate(outs):
        strip.alpha_composite(c.resize((32 * s, 32 * s), Image.NEAREST), (6 + i * (32 * s + 6), 6))
    strip.save(os.path.join(out_dir, f"{base}_strip_{s}x.png"))
    # gif
    gif = []
    for c in outs:
        g = Image.new("RGBA", (32 * 6, 32 * 6), (40, 44, 40, 255))
        g.alpha_composite(c.resize((32 * 6, 32 * 6), Image.NEAREST))
        gif.append(g)
    gif[0].save(os.path.join(out_dir, f"{base}.gif"), save_all=True,
                append_images=gif[1:], duration=duration, loop=0)
    print(f"{base}: {len(outs)} frames -> {out_dir} (window {win})")


if __name__ == "__main__":
    process(sys.argv[1], sys.argv[2], sys.argv[3],
            int(sys.argv[4]) if len(sys.argv) > 4 else 125)
