"""Assemble the cast review package: per character, unzip, crop rotations +
walk to 32x32 (shared window), build cards/strips/GIFs, then one gallery."""
from pl_process import shared_window
from PIL import Image
import glob
import json
import os
import subprocess

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
ART_ROOT = "/Users/nealsharma/code/Vael Academy/assets/art/pixellab"
ORDER = ["south", "south-east", "east", "north-east", "north", "north-west",
         "west", "south-west"]


def process_character(name):
    src = f"{SRC_ROOT}/{name}_v1"
    zips = glob.glob(f"{src}/*_character.zip")
    if not zips:
        print(f"!! no zip for {name}")
        return None
    subprocess.run(["unzip", "-o", "-q", zips[0], "-d", f"{src}/unpacked"], check=True)
    # find the character folder (name may be capitalized inside)
    roots = glob.glob(f"{src}/unpacked/*/rotations")
    root = os.path.dirname(roots[0])
    art = f"{ART_ROOT}/{name}"
    os.makedirs(f"{art}/rotations", exist_ok=True)

    rots = [Image.open(f"{root}/rotations/{d}.png").convert("RGBA") for d in ORDER]
    win = shared_window(rots)
    for d, f in zip(ORDER, rots):
        f.crop(win).save(f"{art}/rotations/{d}.png")

    # rotation card 5x
    card = Image.new("RGBA", (8 * 32 * 5 + 45, 32 * 5 + 10), (30, 30, 34, 255))
    for i, d in enumerate(ORDER):
        im = Image.open(f"{art}/rotations/{d}.png").resize((160, 160), Image.NEAREST)
        card.alpha_composite(im, (5 + i * 165, 5))
    card.save(f"{art}/rotations_card.png")

    # walk animation
    wdirs = glob.glob(f"{root}/animations/*/east")
    if wdirs:
        frames = [Image.open(f).convert("RGBA")
                  for f in sorted(glob.glob(f"{wdirs[0]}/frame_*.png"))]
        wwin = shared_window(frames)
        os.makedirs(f"{art}/walk_east", exist_ok=True)
        outs = []
        for i, f in enumerate(frames, 1):
            c = f.crop(wwin)
            c.save(f"{art}/walk_east/walk_f{i}.png")
            outs.append(c)
        gif = []
        for c in outs:
            g = Image.new("RGBA", (192, 192), (40, 44, 40, 255))
            g.alpha_composite(c.resize((192, 192), Image.NEAREST))
            gif.append(g)
        gif[0].save(f"{art}/walk_east/walk.gif", save_all=True,
                    append_images=gif[1:], duration=140, loop=0)
    print(f"processed {name}")
    return art


if __name__ == "__main__":
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    for name in ids:
        process_character(name)
    print("cast review assets ready")
