"""Weapon library for the on-map cut-out battle direction: detailed, side-profile
weapon sprites that attach to a rig's hand and swap by weapon type. Cheap
(one map-object each). Grip toward the LEFT, blade/head toward the RIGHT."""
import sys, os, time, re, json, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab import call, _token
from PIL import Image
ROOT = "/Users/nealsharma/code/Vael Academy"
IDS = os.path.join(os.path.dirname(__file__), "weapon_ids.json")
STYLE = (", side view weapon sprite held horizontally, pommel/grip on the left "
         "and point/head on the right, clean pixel art, rich colors, "
         "gold and steel detail, transparent background")
WEAPONS = [
    ("sword", "an ornate knights longsword, straight steel blade, crossguard, wrapped grip" + STYLE, 64, 32),
    ("lance", "a long cavalry lance, wooden shaft, steel leaf-shaped spearhead, collar" + STYLE, 72, 32),
    ("axe", "a heavy battle axe, thick wooden haft, broad curved steel head" + STYLE, 56, 34),
    ("bow", "a curved recurve war bow, taut string, wooden limbs with horn tips" + STYLE, 48, 40),
    ("tome", "a thick arcane spellbook tome, open, glowing runes on the pages, leather cover" + STYLE, 40, 32),
    ("staff", "a healer's staff, long wooden shaft topped with a glowing blue-white gem in a filigree setting" + STYLE, 32, 64),
]
def main():
    pids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    for name, desc, w, h in WEAPONS:
        if pids.get(name): continue
        while True:
            t, _ = call("create_map_object", {"description": desc, "width": w, "height": h, "view": "side"})
            if "id:" in t and not t.lower().startswith("error"):
                pids[name] = re.search(r"id: (\S+)", t).group(1)
                json.dump(pids, open(IDS, "w"), indent=1); print("queued", name, flush=True); break
            if "validation" in t.lower():
                print("PERMANENT", name, t[:140], flush=True); pids[name] = ""; break
            time.sleep(30)
        time.sleep(2)
    os.makedirs(f"{ROOT}/assets/art/cutout/weapons", exist_ok=True)
    for name, _d, _w, _h in WEAPONS:
        oid = pids.get(name, "")
        if not oid: continue
        while True:
            t, _ = call("get_map_object", {"object_id": oid})
            if "status: completed" in t:
                dst = f"{ROOT}/assets/art/cutout/weapons/{name}.png"
                subprocess.run(["curl", "-sL", "-H", f"Authorization: Bearer {_token()}", "-o", dst,
                    f"https://api.pixellab.ai/mcp/map-objects/{oid}/download"], check=True)
                try:
                    im = Image.open(dst).convert("RGBA"); bb = im.getbbox()
                    if bb: im.crop(bb).save(dst)
                    print("got", name, im.size, flush=True)
                except Exception as e: print(name, "proc err", e, flush=True)
                break
            if "status: failed" in t: print(name, "FAILED", flush=True); break
            time.sleep(20)
    print("WEAPON LIBRARY COMPLETE", flush=True)
main()
