#!/usr/bin/env python3
"""AW-58: slice a Gemini 2x2 emotion sheet into per-emotion portraits.

Neal generates sheets in the Gemini app (attach the base portrait, ask for a
2x2 labeled grid: HAPPY / SAD / ANGRY / BLUSH, reading order) and drops them at
assets/source/emotion_sheets/<unit_id>.png. This slices each quadrant, strips
the label bands, pads to square, and installs
assets/portraits/portrait_<unit_id>_<emotion>.png. Run `godot --headless
--import` after a batch so the .ctex imports exist.

Usage:
  python3 tools/slice_emotion_sheet.py <unit_id> [sheet_path] [e1 e2 e3 e4]
  python3 tools/slice_emotion_sheet.py --all       # every sheet in the inbox
"""
import sys
import pathlib
import numpy as np
from PIL import Image

INBOX = pathlib.Path("assets/source/emotion_sheets")
OUT = pathlib.Path("assets/portraits")
DEFAULT_EMOTIONS = ["happy", "sad", "angry", "blush"]  # reading order


def label_bands(im: Image.Image) -> list:
    """Full-width near-black rows (the sheet's label bars)."""
    a = np.asarray(im.convert("L"))
    dark = [(a[y] < 40).mean() > 0.85 for y in range(a.shape[0])]
    bands, start = [], None
    for y, d in enumerate(dark):
        if d and start is None:
            start = y
        elif not d and start is not None:
            if y - start > 10:
                bands.append((start, y))
            start = None
    if start is not None and a.shape[0] - start > 10:
        bands.append((start, a.shape[0]))
    return bands


def slice_sheet(unit_id: str, sheet_path: pathlib.Path, emotions: list) -> None:
    im = Image.open(sheet_path).convert("RGB")
    w, h = im.size
    bands = label_bands(im)
    # row content ends where its label band starts; defaults cover unlabeled sheets
    mid_top = next((b[0] for b in bands if h * 0.3 < b[0] < h * 0.7), h // 2)
    bot_top = next((b[0] for b in bands if b[0] >= h * 0.7), h)
    mid_end = next((b[1] for b in bands if h * 0.3 < b[0] < h * 0.7), h // 2)
    quads = [
        (0, 0, w // 2, mid_top), (w // 2, 0, w, mid_top),
        (0, mid_end, w // 2, bot_top), (w // 2, mid_end, w, bot_top),
    ]
    bg = im.getpixel((5, 5))
    for emotion, box in zip(emotions, quads):
        q = im.crop(box)
        side = max(q.width, q.height)
        canvas = Image.new("RGB", (side, side), bg)
        canvas.paste(q, ((side - q.width) // 2, 0))
        out = OUT / f"portrait_{unit_id}_{emotion}.png"
        canvas.save(out)
        print(f"  {out}  ({q.width}x{q.height} -> {side}x{side})")


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--all":
        for sheet in sorted(INBOX.glob("*.png")):
            print(f"{sheet.stem}:")
            slice_sheet(sheet.stem, sheet, DEFAULT_EMOTIONS)
        return
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    unit_id = sys.argv[1]
    sheet = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else INBOX / f"{unit_id}.png"
    emotions = sys.argv[3:7] if len(sys.argv) >= 7 else DEFAULT_EMOTIONS
    print(f"{unit_id}:")
    slice_sheet(unit_id, sheet, emotions)


if __name__ == "__main__":
    main()
