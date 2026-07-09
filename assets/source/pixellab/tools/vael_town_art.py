"""AW-66: the Town of Vael — building art batch. Queues everything, polls,
downloads raw PNGs to assets/source/pixellab/vael_town/ for matting."""
from pixellab import call
import json, os, re, time, subprocess

OBJECTS = [
 ("kings_castle", 384, 320, "a massive majestic royal castle with high white stone walls, tall towers with deep blue conical roofs, golden banners, a grand fortified gatehouse with a raised portcullis, fantasy king's seat"),
 ("cathedral", 288, 288, "a grand gothic cathedral with a tall bell tower, arched stained glass windows glowing warmly, stone buttresses, huge wooden double doors"),
 ("tavern", 224, 192, "a cozy two-story timber-frame tavern with warm glowing windows, a hanging golden stag sign, a chimney with smoke, barrels by the door"),
 ("smithy", 192, 160, "a stone blacksmith workshop with a big chimney, an anvil sign, an open forge glowing orange, tools on the wall"),
 ("shop_goods", 192, 160, "a friendly general goods store with a striped awning, crates and sacks of goods out front, a wooden shingle sign"),
 ("shop_magic", 192, 160, "an arcane bookshop with a purple awning, glowing runes on the sign, stacked spellbooks in the window, mystical"),
 ("playhouse", 224, 192, "a small fantasy theater playhouse with red curtains visible through the entrance, comedy and tragedy masks sign, festive bunting"),
 ("townhouse_a", 160, 160, "a tidy medieval timber-frame townhouse with a red tiled roof and flower boxes"),
 ("townhouse_b", 160, 160, "a narrow stone townhouse with a blue slate roof and a round attic window"),
 ("townhouse_c", 160, 160, "a plastered townhouse with a green door, ivy on one wall, warm windows"),
 ("market_stall_a", 96, 80, "a wooden market stall with a red and white striped canopy, crates of colorful fruit and vegetables"),
 ("market_stall_b", 96, 80, "a wooden market stall with a blue canopy, bolts of colorful fabric and hanging ribbons"),
 ("fountain_grand", 128, 112, "a grand round marble fountain with two tiers and sparkling water, carved stone base"),
 ("statue_king", 64, 96, "a regal stone statue of a crowned king holding a sword point-down, on a carved pedestal"),
 ("rowboat", 96, 64, "a small wooden rowboat moored with rope, oars inside, seen from above"),
 ("city_gate", 256, 160, "a stone city gate with a wide open arch, twin square towers, kingdom banners, portcullis raised"),
]
DST = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab/vael_town"
os.makedirs(DST, exist_ok=True)
state_p = f"{DST}/state.json"
s = json.load(open(state_p)) if os.path.exists(state_p) else {}

for tag, w, h, desc in OBJECTS:
    if tag in s:
        continue
    while True:
        try:
            t, _ = call("create_map_object", {"description": desc, "width": w, "height": h,
                "view": "high top-down", "detail": "medium detail", "shading": "detailed shading"})
        except Exception as e:
            print(tag, "rpc", str(e)[:60], flush=True); time.sleep(30); continue
        if t.startswith("error"):
            print(tag, "busy:", t[:60], flush=True); time.sleep(45); continue
        break
    s[tag] = re.search(r"id: (\S+)", t).group(1)
    json.dump(s, open(state_p, "w"), indent=1)
    print("queued", tag, flush=True)
    time.sleep(6)

done = set()
while len(done) < len(OBJECTS):
    for tag, *_ in OBJECTS:
        if tag in done:
            continue
        t, _ = call("get_map_object", {"object_id": s[tag]})
        if "status: completed" in t:
            url = next(l.split()[1] for l in t.splitlines() if l.startswith("download:"))
            subprocess.run(["curl", "-sL", url, "-o", f"{DST}/{tag}.png"], check=True)
            done.add(tag)
            print("downloaded", tag, flush=True)
        elif "status: failed" in t:
            done.add(tag)
            print("FAILED", tag, flush=True)
    if len(done) < len(OBJECTS):
        time.sleep(20)
print("TOWN ART COMPLETE", flush=True)
