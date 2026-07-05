"""Re-extract every batch-3 state from its group zip using the CORRECT
folder (state zips contain the whole group: base + all sibling states;
folder names are slugified edit-description prefixes)."""
from pl_process import shared_window
from PIL import Image
import glob
import os
import subprocess

SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
ART_ROOT = "/Users/nealsharma/code/Vael Academy/assets/art/pixellab"
ORDER = ["south", "south-east", "east", "north-east", "north", "north-west",
         "west", "south-west"]

# state name -> folder inside its group zip
FOLDER = {
    "wren_hair_pink": "hair_recolored_to_so",
    "isolde_hair_blue": "hair_recolored_to_de",
    "vesper_hair_mint": "hair_recolored_to_pa",
    "thessaly_hair_teal": "hair_recolored_to_da",
    "liora_hair_violet": "hair_recolored_to_ri",
    "kai_hair_green": "hair_recolored_to_bl",
    "kai_hair_green2": "change_ONLY_the_hair",
    "kai_evolved": "promoted_lord_headb",
    "kai_evolved2": "promoted_lord_headb_2",
    "brenna_general": "promoted_to_general",
    "wren_bishop": "promoted_to_bishop",
    "serra_general": "promoted_to_general",
    "corin_sniper": "promoted_to_sniper_e",
    "perrin_paladin": "promoted_to_paladin",
    "dain_warrior": "promoted_to_warrior",
    "liora_sage": "promoted_to_sage_flo",
    "osric_general": "promoted_to_general",
    "elowen_bishop": "promoted_to_bishop_f",
    "isolde_sage": "promoted_to_sage_or",
    "fenn_sentinel": "promoted_to_sentinel",
    "bertram_sentinel": "promoted_to_sentinel",
    "thessaly_sniper": "promoted_to_sniper_m",
    "corvin_sage": "promoted_to_sage_gra",
    "marlow_assassin": "promoted_to_assassin",
    "vesper_bishop": "promoted_to_bishop_r",
    "rurik_berserker": "promoted_to_berserke",
    "tm_soldier_sword2": "the_spear_is_gone_en",
}


def pick_folder(unpacked: str, want: str) -> str:
    dirs = [d for d in os.listdir(unpacked)
            if os.path.isdir(os.path.join(unpacked, d))]
    if want in dirs:
        return os.path.join(unpacked, want)
    # prefix fallback (slug truncation varies a little)
    matches = [d for d in dirs if d.startswith(want[:14])]
    if len(matches) == 1:
        return os.path.join(unpacked, matches[0])
    raise RuntimeError(f"ambiguous/missing folder for {want}: {dirs}")


def reprocess(name):
    src = f"{SRC_ROOT}/{name}_v1"
    zips = glob.glob(f"{src}/*_character.zip")
    subprocess.run(["rm", "-rf", f"{src}/unpacked"], check=True)
    subprocess.run(["unzip", "-o", "-q", zips[0], "-d", f"{src}/unpacked"], check=True)
    root = pick_folder(f"{src}/unpacked", FOLDER[name])
    art = f"{ART_ROOT}/{name}"
    os.makedirs(f"{art}/rotations", exist_ok=True)
    rots = [Image.open(f"{root}/rotations/{d}.png").convert("RGBA") for d in ORDER]
    win = shared_window(rots)
    for d, f in zip(ORDER, rots):
        f.crop(win).save(f"{art}/rotations/{d}.png")
    card = Image.new("RGBA", (8 * 32 * 5 + 45, 32 * 5 + 10), (30, 30, 34, 255))
    for i, d in enumerate(ORDER):
        im = Image.open(f"{art}/rotations/{d}.png").resize((160, 160), Image.NEAREST)
        card.alpha_composite(im, (5 + i * 165, 5))
    card.save(f"{art}/rotations_card.png")
    # walk if this state's own folder has one
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
    print(f"reprocessed {name} <- {os.path.basename(root)}")


if __name__ == "__main__":
    fails = []
    for name in FOLDER:
        try:
            reprocess(name)
        except Exception as e:
            fails.append((name, str(e)[:100]))
    print("FAILS:", fails if fails else "none")
