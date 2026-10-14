#!/usr/bin/env python3
"""CP-2: prepare reviewed Gemini sheets with neural matting + explicit anchors.

Requires Pillow, rembg and onnxruntime. Original sheets are never overwritten.
One scale per character preserves pose proportions; foot coordinates are saved
per frame rather than inferred from padded texture bounds in the renderer.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/illustrated_pilot"
OUT = ROOT / "assets/art/illustrated_pilot"
POSES = ["idle", "action", "parry_hit", "walk_1", "walk_2", "walk_3", "walk_4", "cast", "defeat"]
CANVAS = (640, 640)


def matte(frame: Image.Image, session) -> Image.Image:
    frame = remove(frame, session=session)
    pixels = np.asarray(frame).copy()
    labels, count = ndimage.label(pixels[:, :, 3] > 48)
    if count:
        areas = np.bincount(labels.ravel())
        areas[0] = 0
        largest = int(areas.argmax())
        # Preserve white fabric/metal while removing captions and grid pieces.
        keep = ndimage.binary_dilation(labels == largest, iterations=2)
        pixels[:, :, 3] = np.where(keep, pixels[:, :, 3], 0)
    frame = Image.fromarray(pixels)
    bounds = frame.getbbox()
    if bounds is None:
        raise ValueError("No foreground extracted")
    return frame.crop(bounds)


def main() -> None:
    session = new_session("isnet-general-use")
    OUT.mkdir(parents=True, exist_ok=True)
    for character in ("kai", "serra"):
        source = SOURCE / (character + "_gemini_sheet.png")
        sheet = Image.open(source).convert("RGBA")
        clean_source = SOURCE / (character + "_clean_gemini_sheet.png")
        clean_sheet = Image.open(clean_source).convert("RGBA") if clean_source.exists() else sheet
        width, height = sheet.size
        extracted = []
        for i, pose in enumerate(POSES):
            column, row = i % 3, i // 3
            left, top = round(column * width / 3) + 12, round(row * height / 3) + 12
            right, bottom = round((column + 1) * width / 3) - 12, round((row + 1) * height / 3) - 12
            # Kai's extended blade exceeds the nominal middle cell. Keep its
            # whole tip; the isolated neighboring fragment is removed below.
            if character == "kai" and pose == "action":
                right = round(width * 0.77)
            frame = (clean_sheet if character == "kai" and pose == "action" else sheet).crop((left, top, right, bottom))
            extracted.append((pose, matte(frame, session)))
        idle = extracted[0][1]
        walk_source = SOURCE / (character + "_walk_gemini_sheet.png")
        if walk_source.exists():
            walk_sheet = Image.open(walk_source).convert("RGBA")
            walks = []
            for i in range(4):
                column, row = i % 2, i // 2
                box = (round(column * walk_sheet.width / 2) + 12, round(row * walk_sheet.height / 2) + 12,
                       round((column + 1) * walk_sheet.width / 2) - 12, round((row + 1) * walk_sheet.height / 2) - 12)
                walks.append(matte(walk_sheet.crop(box), session))
            # A 2x2 source has larger figures than the original 3x3 source.
            # Normalize the whole group together, retaining relative heights.
            walk_factor = idle.height / max(frame.height for frame in walks)
            for i, frame in enumerate(walks):
                normalized = frame.resize((round(frame.width * walk_factor), round(frame.height * walk_factor)), Image.Resampling.LANCZOS)
                extracted[i + 3] = ("walk_" + str(i + 1), normalized)
        # Use ONE factor for all nine figures. A crouch stays shorter, not
        # stretched to the idle's height; hands and weapons retain their reach.
        factor = min(540 / idle.height, 608 / max(frame.width for _, frame in extracted))
        destination = OUT / character
        destination.mkdir(exist_ok=True)
        anchors = {}
        head_anchors = {}
        idle_alpha = np.asarray(idle)[:, :, 3]
        idle_head_x = float(np.median(np.nonzero(idle_alpha[:int(idle.height * 0.20), :] > 128)[1]))
        idle_foot_x = float(np.median(np.nonzero(idle_alpha[int(idle.height * 0.80):, :] > 128)[1]))
        idle_head_offset = (idle_head_x - idle_foot_x) * factor
        for pose, frame in extracted:
            resized = frame.resize((round(frame.width * factor), round(frame.height * factor)), Image.Resampling.LANCZOS)
            x = (CANVAS[0] - resized.width) // 2
            y = 604 - resized.height
            # Store the figure's support center from its legs, not the midpoint
            # of an asymmetric sword/cape silhouette.
            alpha = np.asarray(resized)[:, :, 3]
            lower = alpha[int(alpha.shape[0] * 0.80):, :]
            xs = np.nonzero(lower > 128)[1]
            if pose.startswith("walk_"):
                # Keep the head/torso steady as feet alternate; centering every
                # frame on the moving forward boot makes the whole body jitter.
                xs = np.nonzero(alpha[:int(alpha.shape[0] * 0.20), :] > 128)[1]
            support_x = float(np.median(xs)) if xs.size else resized.width * 0.5
            if pose.startswith("walk_"):
                support_x -= idle_head_offset
            canvas = Image.new("RGBA", CANVAS)
            canvas.alpha_composite(resized, (x, y))
            canvas.save(destination / (pose + ".png"))
            anchors[pose] = [round(x + support_x, 2), 604]
            if pose == "idle" or pose.startswith("walk_"):
                head_xs = np.nonzero(alpha[:int(alpha.shape[0] * 0.20), :] > 128)[1]
                head_x = float(np.median(head_xs)) if head_xs.size else resized.width * 0.5
                head_anchors[pose] = [round(x + head_x, 2), y + 101]
            print(character, pose, resized.size, "anchor", anchors[pose], flush=True)
        hands = {"cast": [470, 254], "action": [409, 294]} if character == "kai" else {"cast": [552, 266], "action": [413, 274]}
        manifest = {"source_body_height": round(idle.height * factor, 2), "walk_fps": 7.0, "walk": ["walk_1", "walk_2", "walk_3", "walk_4"], "anchors": anchors, "hands": hands, "generator": "gemini-3.1-flash-image", "source": str(source.relative_to(ROOT)), "action_cleanup_source": str(clean_source.relative_to(ROOT)) if clean_source.exists() else None, "preparation": "isnet-general-use matting; component cleanup; shared character scale; lower-body foot anchors; hand anchors reviewed on 640px output"}
        manifest["walk_source"] = str(walk_source.relative_to(ROOT)) if walk_source.exists() else str(source.relative_to(ROOT))
        manifest["head_anchors"] = head_anchors
        manifest["walk_stride_height"] = 0.65
        head_source = SOURCE / (character + "_head_west_gemini_sheet.png")
        if character == "kai" and head_source.exists():
            head = Image.open(head_source).convert("RGBA")
            head = matte(head.crop((0, 0, head.width, round(head.height * 0.75))), session)
            head = head.resize((round(head.width * 104 / head.height), 104), Image.Resampling.LANCZOS)
            mounted = Image.new("RGBA", (128, 128))
            mounted.alpha_composite(head, ((128 - head.width) // 2, 18))
            mounted.save(destination / "head_west.png")
            manifest["head_west_source"] = str(head_source.relative_to(ROOT))
        (destination / "kit.json").write_text(json.dumps(manifest, indent=2) + "\n")
    courtyard = SOURCE / "courtyard_clean_gemini_sheet.png"
    if not courtyard.exists():
        courtyard = SOURCE / "courtyard_gemini.png"
    Image.open(courtyard).convert("RGB").save(OUT / "courtyard.png")


if __name__ == "__main__":
    main()
