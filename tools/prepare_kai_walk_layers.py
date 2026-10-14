#!/usr/bin/env python3
"""CP-3 REJECTED experiment: reproduce archived parts, never install live art.

uv run --with pillow --with rembg --with onnxruntime tools/prepare_kai_walk_layers.py
"""
from pathlib import Path
import hashlib
import json
from PIL import Image
from rembg import new_session, remove
from prepare_illustrated_pilot import matte, ROOT

SOURCE = ROOT / "assets/source/illustrated_pilot"
OUT = ROOT / "assets/art_review/cp3_walk/rejected_layers"
# Explicit drawing and joint dimensions in the original 640px actor space.
PARTS = {
    "thigh": ("lower", 0, (44, 108), (128, 128), (64, 18), (64, 114)),
    "shin": ("lower", 1, (37, 108), (128, 128), (64, 18), (64, 112)),
    "foot": ("lower", 2, (56, 32), (128, 64), (50, 26), None),
    "cape": ("upper", 0, (192, 310), (256, 336), (128, 20), None),
    "upper_arm": ("upper", 1, (34, 75), (128, 128), (64, 18), (64, 78)),
    "forearm": ("upper", 2, (30, 77), (128, 128), (64, 18), (64, 72)),
    "sword": ("upper", 3, (40, 245), (128, 272), (64, 41), None),
}


def main() -> None:
    session = new_session("isnet-general-use")
    source_paths = {kind: SOURCE / f"kai_walk_{kind}_layers_gemini_sheet.png" for kind in ("lower", "upper")}
    cleaned = SOURCE / "kai_walk_lower_layers_clean_gemini_sheet.png"
    if cleaned.exists():
        source_paths["lower"] = cleaned
    sheets = {kind: Image.open(path).convert("RGBA") for kind, path in source_paths.items()}
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"parts": {}, "source_body_height": 459.28, "stride": 240.0,
                "heel": [43.3, 37.5], "toe": [87.0, 41.4],
                "torso_polygon": [[0, 0], [640, 0], [640, 237], [430, 237], [414, 254],
                                  [422, 319], [424, 401], [329, 401], [338, 323], [342, 281], [326, 248], [310, 237], [0, 237]],
                "torso_texture": "../idle.png", "preparation": "isnet matting and component cleanup; detached art only; explicit source-space pivots"}
    for name, (kind, index, size, canvas_size, pivot, end) in PARTS.items():
        sheet = sheets[kind]
        column, row = index % 2, index // 2
        bounds = (round(column * sheet.width / 2) + 12, round(row * sheet.height / 2) + 12,
                  round((column + 1) * sheet.width / 2) - 12, round((row + 1) * sheet.height / 2) - 12)
        part = matte(sheet.crop(bounds), session).resize(size, Image.Resampling.LANCZOS)
        image = Image.new("RGBA", canvas_size)
        image.alpha_composite(part, ((canvas_size[0] - size[0]) // 2, 10))
        image.save(OUT / (name + ".png"))
        manifest["parts"][name] = {"texture": name + ".png", "pivot": pivot, "end": end}
        print(name, size, flush=True)
    manifest["sources"] = [{"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in source_paths.values()]
    prepare_carry(session, manifest)
    (OUT / "rig.json").write_text(json.dumps(manifest, indent=2) + "\n")


def prepare_carry(session, manifest: dict) -> None:
    """Keep the painted closed grip intact; register the short sleeve and blade.

    The generated sleeve/blade proportions differ from Kai's approved body.
    Native mesh bands shorten only the sleeve and lengthen only the straight
    blade. The entire hand, hilt and guard use one uniform scale, preserving
    their actual grip instead of positioning an open hand over a loose sword.
    """
    source = SOURCE / "kai_walk_grip_gemini_sheet.png"
    image = remove(Image.open(source).convert("RGBA"), session=session)
    image = image.resize((640, 954), Image.Resampling.LANCZOS)
    image.save(OUT / "right_carry.png")
    uv, vertices, polygons = [], [], []
    for y in (0, 449, 572, 954):
        for x in (0, 640):
            uv.append([x, y])
            if y <= 449:
                center_x = 328 + 44 * (y - 104) / 345
                target = [(x - center_x) * .23, (y - 104) * .12]
            else:
                target = [(x - 372) * .23, 41.4 + (y - 449) * .23]
                if y > 572:
                    target[0] -= (y - 572) * .28 * (313 / 353)
                    target[1] += (y - 572) * .28
            vertices.append(target)
    for row in range(3):
        start = row * 2
        polygons.append([start, start + 1, start + 3, start + 2])
    manifest["right_carry_mesh"] = {"texture": "right_carry.png", "uv": uv,
                                     "vertices": vertices, "polygons": polygons}
    manifest["sources"].append({"path": str(source.relative_to(ROOT)),
                                "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    print("right_carry", flush=True)


if __name__ == "__main__":
    main()
