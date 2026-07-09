"""Batch 5: outfit variants (school / casual / party) for the four marquee
characters — Kai + the three heirs. States on approved bases."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"

# (new_name, base, edit)
OUTFITS = [
    ("kai_school",   "kai_hair_green2", "school uniform outfit: neat dark navy academy uniform with gold buttons, no cape, no sword, no headband, tidy appearance"),
    ("kai_casual",   "kai_hair_green2", "casual clothes: simple worn forager's shirt with rolled sleeves, patched trousers, comfortable boots, no cape, no sword, relaxed"),
    ("kai_party",    "kai_hair_green2", "formal festival outfit: elegant dark dress coat with subtle crimson embroidery, gold clasp, polished shoes, no weapons"),
    ("serra_school", "serra",  "school uniform outfit: neat deep blue academy uniform with silver trim, no armor, no lance, no shield, tidy"),
    ("serra_casual", "serra",  "casual clothes: simple pale blue blouse and long skirt, hair still in braided twin tails, relaxed off-duty look, no armor, no weapons"),
    ("serra_party",  "serra",  "formal ball gown: elegant navy and silver evening gown with the silver circlet, graceful, no armor, no weapons"),
    ("rina_school", "rina",  "school uniform outfit: neat forest green academy uniform with bronze trim and gold tie, no bow, no quiver, tidy"),
    ("rina_casual", "rina",  "casual clothes: comfortable scholar's cardigan over a simple blouse, reading glasses tucked in collar, relaxed, no bow, no quiver"),
    ("rina_party",  "rina",  "formal festival dress: elegant forest green and gold gown, twin braids styled with extra gold clasps, graceful, no weapons"),
    ("perrin_school","perrin", "school uniform outfit: neat dark navy academy uniform with gold buttons, no cape, no epaulettes, no weapons, tidy"),
    ("perrin_casual","perrin", "casual clothes: open-collar white shirt and riding trousers, relaxed golden-boy charm, no weapons, no cape"),
    ("perrin_party", "perrin", "formal festival outfit: dashing crimson and gold dress uniform with short ceremonial cape, polished boots, no weapons"),
]


def get(cid):
    return call("get_character", {"character_id": cid})[0]


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    new = {}
    # queue with retry
    pending = list(OUTFITS)
    while pending:
        progress = False
        for item in list(pending):
            name, base, edit = item
            t, _ = call("create_character_state", {
                "character_id": ids[base], "edit_description": edit})
            if not t.startswith("error"):
                new[name] = re.search(r"id: (\S+)", t).group(1)
                pending.remove(item)
                progress = True
                print(f"queued {name} -> {new[name]}", flush=True)
        if pending and not progress:
            time.sleep(50)

    # wait all
    done = set()
    while len(done) < len(new):
        for n, cid in new.items():
            if n in done:
                continue
            t = get(cid)
            s = re.search(r"status: (\w+)", t)
            if s and s.group(1) in ("completed", "failed"):
                done.add(n)
                print(f"{n}: {s.group(1)}", flush=True)
        if len(done) < len(new):
            time.sleep(30)

    # walks (hub outfits need walking!)
    for n, cid in new.items():
        while True:
            t, _ = call("animate_character", {
                "character_id": cid, "action_description": "walking",
                "directions": ["east"], "animation_name": "walk_east",
                "mode": "v3"})
            if not t.startswith("error"):
                print("walk queued:", n, flush=True)
                break
            time.sleep(40)
        time.sleep(3)
    while True:
        busy = [n for n, c in new.items() if "pending jobs" in get(c)]
        if not busy:
            break
        time.sleep(30)

    # download
    ids.update(new)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    for n, cid in new.items():
        dst = f"{SRC_ROOT}/{n}_v1"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{cid}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        for _ in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    open(f"{dst}/{n}_character.zip", "wb").write(r.read())
                open(f"{dst}/character_info.txt", "w").write(get(cid))
                print("downloaded", n, flush=True)
                break
            except Exception as e:
                print("dl retry", n, e, flush=True)
                time.sleep(20)
    print("BATCH5 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
