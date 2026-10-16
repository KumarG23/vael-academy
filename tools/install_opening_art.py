#!/usr/bin/env python3
"""VS-1B deterministic extraction of reviewed Gemini masters, no synthesis.
Run only after visual review. Preserve all source versions and output hashes.
"""
from collections import deque
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/source/vs1b_story_art'


def portrait(source: str, name: str, column: int = 0, columns: int = 1, opaque: bool = False) -> None:
    im = Image.open(SRC / (source + '.png')).convert('RGBA')
    if opaque:
        # Match the established cast's square opaque portrait format. No matte
        # extraction or face repainting; retain the original background mood.
        im.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        out = ROOT / f'assets/portraits/portrait_{name}.png'
        im.save(out)
        record.append({'output': str(out.relative_to(ROOT)), 'source': source,
                       'format': 'established_square_portrait_no_matte',
                       'sha256': hashlib.sha256(out.read_bytes()).hexdigest()})
        return
    w, h = im.size
    # Exclude the generated reference sheet's thin column dividers.
    im = im.crop((round(w * column / columns) + (4 if columns > 1 else 0), 0,
                  round(w * (column + 1) / columns) - (4 if columns > 1 else 0), h))
    # Only exterior-connected near-white becomes alpha; eyes/shirt remain intact.
    w, h = im.size
    px = im.load()
    seen = set()
    todo = deque([(x, y) for x in range(w) for y in (0, h-1)] + [(x, y) for y in range(h) for x in (0, w-1)])
    while todo:
        x, y = todo.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if min(r, g, b) < 238:
            continue
        px[x, y] = (r, g, b, 0)
        todo.extend(((x-1, y), (x+1, y), (x, y-1), (x, y+1)))
    if name.startswith('kai_'):
        # Generator outlines can enclose white negative-space pockets between
        # hair locks. Clean only the hair surround, excluding the face/eyes and
        # linen shirt. This is matte cleanup, never facial/costume repainting.
        for y in range(round(h * 0.46)):
            for x in range(w):
                if 0.29 * w < x < 0.71 * w and y > 0.19 * h:
                    continue
                if min(px[x, y][:3]) >= 238:
                    px[x, y] = (*px[x, y][:3], 0)
    im.thumbnail((700, 950), Image.Resampling.LANCZOS)
    out = ROOT / f'assets/portraits/portrait_{name}.png'
    im.save(out)
    record.append({'output': str(out.relative_to(ROOT)), 'source': source, 'column': column,
                   'columns': columns, 'sha256': hashlib.sha256(out.read_bytes()).hexdigest()})


record: list[dict] = []
if __name__ == '__main__':
    selections = json.loads((SRC / 'selections.json').read_text())
    for entry in selections['portraits']:
        portrait(**entry)
    for source, name in selections['backdrops'].items():
        out = ROOT / f'assets/art/vn/painted/{name}.png'
        im = Image.open(SRC / (source + '.png')).convert('RGB')
        im.save(out)
        record.append({'output':str(out.relative_to(ROOT)), 'source':source,
                       'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    (SRC / 'installed.json').write_text(json.dumps(record, indent=2)+'\n')
