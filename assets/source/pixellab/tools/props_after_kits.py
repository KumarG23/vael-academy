"""Playtest-3 prop pack, CHAINED after the battle-kit rollout (Neal: line up
new props once the current PixelLab job is done). Waits for cast_rollout2 to
finish, then generates a fresh set of room/campus props, trims them, drops them
in assets/art/pixellab/props/, and builds a review sheet. Does NOT auto-place
them in rooms — that's a reviewed step next session ("props that work").

Run detached:  cd .../tools && nohup python3 props_after_kits.py > props2.log 2>&1 &
"""
import sys, os, time, re, json, subprocess, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab import call, _token
from PIL import Image

SCRATCH = os.path.dirname(os.path.abspath(__file__))
ROOT = "/Users/nealsharma/code/Vael Academy"
KIT_STATE = f"{SCRATCH}/cast_rollout2_state.json"
IDS_F = f"{SCRATCH}/prop_pack2_ids.json"
STYLE = (", GBA Fire Emblem overworld object, high top-down view, rich saturated "
         "colors, opulent noble academy, gold trim, transparent background")

# (name, description, width, height)
PROPS = [
    ("chalkboard", "large dark slate chalkboard on a carved wooden frame with faint chalk diagrams", 64, 56),
    ("lectern", "tall carved wooden lectern with an open book and a reading candle", 32, 56),
    ("globe_stand", "ornate world globe on a polished wooden stand with brass rings", 40, 56),
    ("student_desk", "small wooden school desk with an inkwell and a stack of papers", 40, 40),
    ("reading_desk", "wooden reading desk with an open tome, scrolls and a lit candle", 56, 40),
    ("book_stack", "tall teetering stack of leather-bound books", 32, 40),
    ("display_case", "glass display case on a pedestal holding a glowing warded relic", 40, 64),
    ("brazier", "tall iron brazier bowl with dancing flames on a tripod", 32, 56),
    ("war_banner", "tall standing war banner on a spear pole, crimson and gold heraldry", 40, 72),
    ("grand_hearth", "massive carved stone fireplace hearth with a roaring fire and a mantel", 80, 64),
    ("wine_rack", "wooden rack of wine bottles and a small keg", 48, 48),
    ("archery_target", "round straw archery target on a wooden stand with arrows stuck in it", 40, 48),
    ("wall_torch", "iron wall sconce holding a burning torch", 24, 40),
    ("potted_plant", "tall leafy potted plant in a decorated ceramic urn", 32, 56),
    ("tapestry", "long hanging wall tapestry with woven heraldic imagery and gold fringe", 40, 64),
    ("treasure_chest", "sturdy iron-banded wooden treasure chest with a gold lock", 40, 32),
    ("market_stall", "wooden merchant market stall with a striped awning and goods on the counter", 72, 64),
    ("fruit_cart", "wooden hand cart piled with colorful fruit and produce", 56, 48),
]


def wait_for_kits():
    print("waiting for the battle-kit rollout to finish...", flush=True)
    while True:
        try:
            st = json.load(open(KIT_STATE))
            phases = [v.get("phase") for v in st.values()]
            done = sum(1 for p in phases if p == "done")
            if len(phases) >= 14 and all(p == "done" for p in phases):
                print(f"kits done ({done}) — starting prop pack", flush=True)
                return
            print(f"  kits {done}/14 done; sleeping", flush=True)
        except Exception as e:
            print("  (state read:", e, ")", flush=True)
        time.sleep(180)


def gen():
    pids = json.load(open(IDS_F)) if os.path.exists(IDS_F) else {}
    for name, desc, w, h in PROPS:
        if name in pids:
            continue
        while True:
            t, _ = call("create_map_object", {"description": desc + STYLE,
                "width": w, "height": h, "view": "high top-down"})
            if "id:" in t and not t.lower().startswith("error"):
                pids[name] = re.search(r"id: (\S+)", t).group(1)
                json.dump(pids, open(IDS_F, "w"), indent=1)
                print("queued", name, flush=True)
                break
            if "validation" in t.lower():
                print(f"PERMANENT ({name}): {t[:160]} — skipping", flush=True)
                pids[name] = ""
                break
            time.sleep(30)
        time.sleep(2)

    src = f"{ROOT}/assets/source/pixellab/prop_pack2"
    os.makedirs(src, exist_ok=True)
    review = []
    for name, _d, _w, _h in PROPS:
        oid = pids.get(name, "")
        if oid == "":
            continue
        while True:
            t, _ = call("get_map_object", {"object_id": oid})
            if "status: completed" in t:
                dst = f"{src}/{name}.png"
                subprocess.run(["curl", "-sL", "-H", f"Authorization: Bearer {_token()}",
                    "-o", dst, f"https://api.pixellab.ai/mcp/map-objects/{oid}/download"], check=True)
                # trim transparent border, install into props/
                try:
                    im = Image.open(dst).convert("RGBA")
                    bb = im.getbbox()
                    if bb:
                        im = im.crop(bb)
                    im.save(f"{ROOT}/assets/art/pixellab/props/{name}.png")
                    review.append((name, im))
                    print("installed", name, im.size, flush=True)
                except Exception as e:
                    print(name, "process error", e, flush=True)
                break
            if "status: failed" in t:
                print(name, "FAILED", flush=True)
                break
            time.sleep(25)

    # review sheet
    if review:
        cell = 160
        cols = 6
        rows = (len(review) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell, rows * cell), (28, 30, 38, 255))
        from PIL import ImageDraw
        d = ImageDraw.Draw(sheet)
        for i, (name, im) in enumerate(review):
            thumb = im.copy()
            thumb.thumbnail((cell - 16, cell - 28), Image.NEAREST)
            x = (i % cols) * cell
            y = (i // cols) * cell
            sheet.alpha_composite(thumb, (x + (cell - thumb.width) // 2, y + 4))
            d.text((x + 6, y + cell - 16), name, fill=(255, 230, 150))
        os.makedirs(f"{ROOT}/assets/art_review/props_pack2", exist_ok=True)
        sheet.convert("RGB").save(f"{ROOT}/assets/art_review/props_pack2/prop_pack2_sheet.png")
        print("REVIEW SHEET saved", flush=True)
    print("PROP PACK 2 COMPLETE", flush=True)


wait_for_kits()
gen()
