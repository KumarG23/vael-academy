"""AW-66b: re-roll the three flawed town buildings — NO TEXT anywhere (the
model can't spell); pictorial signs only. Smithy becomes a real exterior."""
from pixellab import call
import json, os, re, time, subprocess

OBJECTS = [
 ("playhouse", 224, 192, "a small fantasy theater playhouse, red curtains visible through the entrance arch, a hanging sign showing ONLY two carved drama masks (one smiling, one weeping), festive bunting, warm lanterns, absolutely no text, no letters, no words anywhere"),
 ("shop_goods", 192, 160, "a friendly general goods store exterior with a red and white striped awning, crates and sacks of goods out front, a hanging wooden shingle sign showing ONLY a barrel and scales symbol, absolutely no text, no letters, no words anywhere"),
 ("smithy", 192, 160, "a sturdy stone blacksmith building exterior with a slate roof, a big smoking chimney, an open forge glow through the doorway, a hanging sign showing ONLY an anvil symbol, horseshoes on the wall, absolutely no text, no letters, no words anywhere"),
]
DST = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab/vael_town"
s = {}
for tag, w, h, desc in OBJECTS:
    while True:
        t, _ = call("create_map_object", {"description": desc, "width": w, "height": h,
            "view": "high top-down", "detail": "medium detail", "shading": "detailed shading"})
        if not t.startswith("error"):
            break
        time.sleep(45)
    s[tag] = re.search(r"id: (\S+)", t).group(1)
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
            done.add(tag); print("FAILED", tag, flush=True)
    if len(done) < len(OBJECTS):
        time.sleep(20)
print("FIXES COMPLETE", flush=True)
