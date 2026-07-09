"""AW-67: interior props + townsfolk NPC characters for the Vael interiors."""
from pixellab import call
import json, os, re, time, subprocess

PROPS = [
 ("shop_counter", 96, 64, "a polished wooden shop counter with a brass till and wrapped parcels, seen from above-front"),
 ("stocked_shelf", 64, 88, "a tall wooden shop shelf fully stocked with jars, boxes, bottles and folded cloth, front view"),
 ("forge_anvil", 96, 96, "a blacksmith forge with glowing coals beside a heavy iron anvil on a stump, tools leaning"),
 ("weapon_rack", 64, 80, "a wooden weapon rack holding swords, an axe and a spear, front view"),
 ("bar_counter", 128, 64, "a long tavern bar counter with mugs, a keg at the end, warm wood, front view"),
 ("pew", 72, 40, "a simple wooden church pew bench, front view"),
 ("altar", 96, 88, "a stone chantry altar with white cloth, golden candlesticks and a small flame bowl, front view"),
]
NPCS = [
 ("marta", "a warm middle-aged shopkeeper woman with brown hair in a bun, a green dress with a cream apron, sleeves rolled, friendly, full body standing"),
 ("bram", "a broad burly blacksmith man with a black beard, soot-marked leather apron over bare arms, heavy gloves tucked in belt, full body standing"),
 ("sylvie", "a sharp-eyed arcane bookseller woman with silver-streaked dark hair, round spectacles, a deep purple shawl over dark robes, full body standing"),
 ("odo", "a jolly round tavern keeper man with a big rust mustache, rolled white shirt, brown vest with a stag pin, carrying a towel, full body standing"),
 ("enna", "a serene elderly prioress woman in cream and gold ceremonial robes with a simple wimple, kind lined face, full body standing"),
]
DST = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab/vael_interiors"
os.makedirs(DST, exist_ok=True)
sp = f"{DST}/state.json"
s = json.load(open(sp)) if os.path.exists(sp) else {}

def save(): json.dump(s, open(sp, "w"), indent=1)

for tag, w, h, desc in PROPS:
    if "prop_" + tag in s: continue
    while True:
        t, _ = call("create_map_object", {"description": desc, "width": w, "height": h,
            "view": "high top-down", "detail": "medium detail", "shading": "detailed shading"})
        if not t.startswith("error"): break
        time.sleep(45)
    s["prop_" + tag] = re.search(r"id: (\S+)", t).group(1); save()
    print("queued prop", tag, flush=True); time.sleep(6)

for tag, desc in NPCS:
    if "npc_" + tag in s: continue
    while True:
        t, _ = call("create_character", {"description": desc, "name": "vael_" + tag,
            "mode": "v3", "size": 32, "outline": "single color black outline", "detail": "medium detail"})
        if not t.startswith("error"): break
        time.sleep(45)
    s["npc_" + tag] = re.search(r"id: (\S+)", t).group(1); save()
    print("queued npc", tag, flush=True); time.sleep(6)

done = set()
keys = ["prop_" + t for t, *_ in PROPS] + ["npc_" + t for t, _ in NPCS]
while len(done) < len(keys):
    for k in keys:
        if k in done: continue
        if k.startswith("prop_"):
            t, _ = call("get_map_object", {"object_id": s[k]})
            if "status: completed" in t:
                url = next(l.split()[1] for l in t.splitlines() if l.startswith("download:"))
                subprocess.run(["curl", "-sL", url, "-o", f"{DST}/{k}.png"], check=True)
                done.add(k); print("downloaded", k, flush=True)
            elif "status: failed" in t:
                done.add(k); print("FAILED", k, flush=True)
        else:
            t, _ = call("get_character", {"character_id": s[k]})
            m = re.search(r"status: (\w+)", t)
            if m and m.group(1) == "completed":
                import urllib.request
                from pixellab import _token
                req = urllib.request.Request(f"https://api.pixellab.ai/mcp/characters/{s[k]}/download",
                    headers={"Authorization": f"Bearer {_token()}"})
                with urllib.request.urlopen(req, timeout=180) as r:
                    open(f"{DST}/{k}.zip", "wb").write(r.read())
                done.add(k); print("downloaded", k, flush=True)
            elif m and m.group(1) == "failed":
                done.add(k); print("FAILED", k, flush=True)
    if len(done) < len(keys):
        time.sleep(25)
print("INTERIORS ART COMPLETE", flush=True)
