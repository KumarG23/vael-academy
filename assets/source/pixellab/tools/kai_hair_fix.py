"""Fix the Kai hair state: v1 painted the clothes green instead of the hair.
Re-state with hair-only phrasing, re-chain the evolution, download both."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"

HAIR_EDIT = ("change ONLY the hair color: black hair with a few dark green "
             "highlight streaks on top. Keep every part of the clothing, "
             "cape, headband and equipment exactly the same colors as before")
EVO_EDIT = ("promoted lord: headband removed, glowing silver-white frost-crack "
            "mark across his left temple and brow, longer dark coat with "
            "crimson lining, confident bearing. Hair stays black with dark "
            "green highlight streaks")


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def wait_done(cid, label):
    while True:
        t = get(cid)
        s = re.search(r"status: (\w+)", t)
        if s and s.group(1) in ("completed", "failed"):
            print(label, s.group(1), flush=True)
            return s.group(1) == "completed"
        time.sleep(15)


def queue_state(name, src, edit):
    while True:
        text, _ = call("create_character_state", {
            "character_id": src, "edit_description": edit})
        if not text.startswith("error"):
            cid = re.search(r"id: (\S+)", text).group(1)
            print(f"queued {name} -> {cid}", flush=True)
            return cid
        time.sleep(40)


def download(name, cid):
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
            return
        except Exception as e:
            print("dl retry:", e, flush=True)
            time.sleep(20)


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    hid = queue_state("kai_hair_green2", ids["kai"], HAIR_EDIT)
    ids["kai_hair_green2"] = hid
    if wait_done(hid, "kai_hair_green2"):
        eid = queue_state("kai_evolved2", hid, EVO_EDIT)
        ids["kai_evolved2"] = eid
        wait_done(eid, "kai_evolved2")
        # walk on the evolved form
        while True:
            t, _ = call("animate_character", {
                "character_id": eid, "action_description": "walking",
                "directions": ["east"], "animation_name": "walk_east",
                "mode": "v3"})
            if not t.startswith("error"):
                break
            time.sleep(30)
        while "pending jobs" in get(eid):
            time.sleep(20)
        download("kai_hair_green2", hid)
        download("kai_evolved2", eid)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    print("KAI FIX COMPLETE", flush=True)


if __name__ == "__main__":
    main()
