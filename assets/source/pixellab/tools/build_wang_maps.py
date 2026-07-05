"""Classify each 32px tile in the 4x4 Wang atlases by corner signature and
emit wang_maps.json for the Godot TerrainTiles renderer.

Signature bit order: NW=1, NE=2, SW=4, SE=8 — bit set = corner is the
OVERLAY terrain (the non-grass one for land sets; WATER for the water set)."""
from PIL import Image
import json
import os

ART = "/Users/nealsharma/code/Vael Academy/assets/art/pixellab/tilesets"

# which cluster is the overlay terrain, by hue rule per set
SETS = {
    # name: (overlay_is, rule) — rule classifies a corner mean RGB as overlay?
    "grass_water":     lambda r, g, b: b > g,                 # water = blue
    "grass_path":      lambda r, g, b: r > g,                 # dirt = orange
    "grass_forest":    lambda r, g, b: g < 110 and r < 90,    # forest = dark
    "grass_mountain":  lambda r, g, b: abs(r - b) < 30 and abs(r - g) < 30,  # rock = grey
    "grass_fortstone": lambda r, g, b: abs(r - b) < 30 and abs(r - g) < 30,  # stone = grey
}


def corner_means(tile):
    w = 10
    quads = {
        "NW": (2, 2, w, w), "NE": (32 - w - 2, 2, w, w),
        "SW": (2, 32 - w - 2, w, w), "SE": (32 - w - 2, 32 - w - 2, w, w),
    }
    out = {}
    for k, (x, y, ww, hh) in quads.items():
        px = list(tile.crop((x, y, x + ww, y + hh)).getdata())
        n = len(px)
        out[k] = tuple(sum(p[i] for p in px) / n for i in range(3))
    return out


def main():
    result = {}
    for name, is_overlay in SETS.items():
        atlas = Image.open(f"{ART}/{name}_atlas.png").convert("RGB")
        sigmap = {}
        for row in range(4):
            for col in range(4):
                tile = atlas.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
                cm = corner_means(tile)
                sig = 0
                for bit, corner in ((1, "NW"), (2, "NE"), (4, "SW"), (8, "SE")):
                    if is_overlay(*cm[corner]):
                        sig |= bit
                if sig in sigmap:
                    print(f"  ! {name}: duplicate signature {sig} at ({col},{row}) and {sigmap[sig]}")
                else:
                    sigmap[sig] = [col, row]
        missing = [s for s in range(16) if s not in sigmap]
        print(f"{name}: {len(sigmap)}/16 signatures", f"MISSING {missing}" if missing else "COMPLETE")
        result[name] = {str(k): v for k, v in sigmap.items()}
    out = f"{ART}/wang_maps.json"
    json.dump(result, open(out, "w"), indent=1)
    print("wrote", out)


if __name__ == "__main__":
    main()
