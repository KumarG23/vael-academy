"""Batch 2: the remaining 16 named characters + 2 state proofs.
Wave-queues under the 10-concurrent-job cap, walks everyone, downloads all."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"

STYLE = ", GBA Fire Emblem style, strong readable silhouette"
CAST2 = {
    # Emberwing (navy uniform + crimson/gold)
    "perrin":   "young male tactics-RPG cavalier heir, charismatic golden-boy grin, short golden blond hair, fair skin, dark navy academy uniform with crimson half-cape and gold epaulettes, riding boots, lance and sword at belt",
    "dain":     "young male tactics-RPG fighter student, big brash grin, broad muscular build, short dark red hair, tan skin, sleeveless dark navy academy uniform with crimson trim, heavy battle axe over shoulder",
    "liora":    "young female tactics-RPG fire mage student, proud noble bearing, long dark hair with a crimson ribbon, warm brown skin, dark navy academy uniform with crimson-gold trim and short mage cloak, open fire tome with small flame",
    # Tidemark (deep blue + silver)
    "osric":    "young male tactics-RPG armored knight student, calm immovable bearing, short sandy hair, heavy deep blue plate armor with silver trim over uniform, greatshield and lance",
    "elowen":   "young female tactics-RPG healer priest student, serene kind face, long silver-white hair, deep blue and white priestess robe with silver trim, healing staff",
    "isolde":   "young female tactics-RPG faith mage student, formal reserved bearing, dark hair in a tight bun, deep blue scholar robe with silver clasps, glowing blue tome",
    "fenn":     "young male tactics-RPG skirmisher student, playful grin, messy sea-green hair, light deep blue uniform with silver trim and short cloak, javelin and small buckler, quick light stance",
    "bertram":  "large young male tactics-RPG halberdier student, solid dependable bearing, short brown hair and stubble, deep blue uniform with silver pauldrons and chainmail, long halberd",
    # Thornrook (forest green + bronze)
    "thessaly": "young female tactics-RPG sniper student, focused sharp gaze, dark hair in a long ponytail, forest green uniform with bronze trim and hooded half-cloak, longbow and quiver",
    "corvin":   "young male tactics-RPG scholar mage student, thoughtful bookish look, round glasses, neat black hair, forest green robe with bronze trim over uniform, thick tome under arm",
    "marlow":   "young male tactics-RPG thief scout student, sly street-smart grin, tousled brown hair, bandana scarf, fitted forest green uniform with bronze buckles, twin daggers, light crouched stance",
    "vesper":   "young female tactics-RPG research healer student, precise clinical calm, ash-blonde hair in a braided crown, forest green and cream robe with bronze trim, staff and satchel of instruments",
    "rurik":    "young male tactics-RPG hunter warrior student, rugged outdoorsman look, shaggy dark hair, fur-trimmed forest green uniform with bronze clasps, hunting axe",
    # Teachers
    "callan":   "middle-aged male tactics-RPG war instructor, scarred weathered face, short grey-streaked dark hair, burn scar on jaw, dark navy officer uniform with crimson mantle and gold rank braid, arming sword, commanding presence",
    "maren":    "middle-aged female tactics-RPG knight instructor, stern disciplined face, steel-grey hair in a tight braid, deep blue and silver officer armor with long coat, tall lance, commanding presence",
    "alaric":   "elderly male tactics-RPG scholar instructor, wise dry-humored face, white beard, forest green and bronze archivist robes with hanging seals and keys, gnarled staff",
}

# state proofs: (new_name, source_name_in_ids, edit)
STATES = [
    ("kael_swordmaster", "kael",
     "promoted to swordmaster: longer flowing coat with crimson trim, ornate curved blade, more confident veteran stance"),
    ("tm_soldier_sword", "tm_soldier",
     "wielding a one-handed sword and round shield instead of the spear"),
]


def try_create(name, desc):
    text, _ = call("create_character", {
        "description": desc + STYLE, "name": name, "mode": "v3", "size": 32,
        "outline": "single color black outline", "detail": "medium detail"})
    if text.startswith("error"):
        return None
    m = re.search(r"id: (\S+)", text)
    return m.group(1) if m else None


def try_state(name, src_id, edit):
    text, _ = call("create_character_state", {
        "character_id": src_id, "edit_description": edit})
    if text.startswith("error"):
        print(f"state {name} deferred: {text[:120]}", flush=True)
        return None
    m = re.search(r"id: (\S+)", text)
    return m.group(1) if m else None


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    ids.setdefault("kai", "471c7fb8-afa9-4dd6-aaba-9b440a08427b")
    new_ids = {}

    # 1. queue all creations (retry on job-cap 429)
    pending = dict(CAST2)
    while pending:
        progress = False
        for name in list(pending):
            cid = try_create(name, pending[name])
            if cid:
                new_ids[name] = cid
                del pending[name]
                progress = True
                print(f"queued {name} -> {cid}", flush=True)
        if pending and not progress:
            time.sleep(50)

    # 2. wait for characters
    done = set()
    while len(done) < len(new_ids):
        for name, cid in new_ids.items():
            if name in done:
                continue
            t = get(cid)
            s = re.search(r"status: (\w+)", t)
            if s and s.group(1) in ("completed", "failed"):
                done.add(name)
                print(f"character {s.group(1)}: {name}", flush=True)
        if len(done) < len(new_ids):
            time.sleep(30)

    # 3. state proofs
    for sname, src, edit in STATES:
        sid = None
        while sid is None:
            sid = try_state(sname, ids.get(src) or new_ids.get(src), edit)
            if sid is None:
                time.sleep(50)
        new_ids[sname] = sid
        print(f"state queued {sname} -> {sid}", flush=True)

    # 4. walks for everything new (states get walks too)
    for name, cid in new_ids.items():
        while True:
            # states need their character to finish first
            t = get(cid)
            s = re.search(r"status: (\w+)", t)
            if s and s.group(1) == "completed":
                pass
            elif s and s.group(1) == "failed":
                print(f"SKIP walk, failed: {name}", flush=True)
                break
            else:
                time.sleep(25)
                continue
            text, _ = call("animate_character", {
                "character_id": cid, "action_description": "walking",
                "directions": ["east"], "animation_name": "walk_east",
                "mode": "v3"})
            if text.startswith("error"):
                time.sleep(45)
            else:
                print(f"walk queued: {name}", flush=True)
                break

    # 5. wait for all walks
    while True:
        busy = [n for n, c in new_ids.items() if "pending jobs" in get(c)]
        if not busy:
            break
        time.sleep(30)
    print("all walks done", flush=True)

    # 6. download
    ids.update(new_ids)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    for name, cid in new_ids.items():
        dst = f"{SRC_ROOT}/{name}_v1"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{cid}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        for _ in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    open(f"{dst}/{name}_character.zip", "wb").write(r.read())
                open(f"{dst}/character_info.txt", "w").write(get(cid))
                print(f"downloaded {name}", flush=True)
                break
            except Exception as e:
                print(f"retry {name}: {e}", flush=True)
                time.sleep(20)
    print("BATCH2 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
