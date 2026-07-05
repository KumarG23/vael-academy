"""Batch 4: kai_evolved3 (no marks), walks for all 17 approved evolutions,
and two Wang tilesets for the maps comparison."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"

EVOLVED = ["brenna_general", "wren_bishop", "serra_general", "corin_sniper",
           "perrin_paladin", "dain_warrior", "liora_sage", "osric_general",
           "elowen_bishop", "isolde_sage", "fenn_sentinel", "bertram_sentinel",
           "thessaly_sniper", "corvin_sage", "marlow_assassin", "vesper_bishop",
           "rurik_berserker"]

TILESETS = {
    "grass_water": {"lower_description": "clear blue lake water with gentle ripples",
                    "upper_description": "lush green grass meadow",
                    "transition_size": 0.25,
                    "transition_description": "muddy bank with reeds",
                    "tile_size": {"width": 32, "height": 32}},
    "grass_path":  {"lower_description": "packed dirt road with small stones",
                    "upper_description": "lush green grass meadow",
                    "transition_size": 0.0,
                    "tile_size": {"width": 32, "height": 32}},
}


def get(cid):
    return call("get_character", {"character_id": cid})[0]


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))

    # 1) kai_evolved3: clean face, no marks
    while True:
        t, _ = call("create_character_state", {
            "character_id": ids["kai_hair_green2"],
            "edit_description": "promoted lord: headband removed completely "
                                "with no trace of it, clean face with no "
                                "facial marks, longer dark coat with crimson "
                                "lining, confident bearing"})
        if not t.startswith("error"):
            ids["kai_evolved3"] = re.search(r"id: (\S+)", t).group(1)
            print("kai_evolved3 queued ->", ids["kai_evolved3"], flush=True)
            break
        time.sleep(45)

    # 2) tilesets
    tset_ids = {}
    for name, args in TILESETS.items():
        while True:
            t, _ = call("create_topdown_tileset", args)
            if not t.startswith("error"):
                m = re.search(r"id: (\S+)", t)
                tset_ids[name] = m.group(1)
                print(f"tileset {name} -> {m.group(1)}", flush=True)
                break
            time.sleep(45)
    json.dump(tset_ids, open(f"{SCRATCH}/tileset_ids.json", "w"), indent=1)

    # 3) walks for evolved forms (retry under job cap)
    for n in EVOLVED:
        while True:
            t, _ = call("animate_character", {
                "character_id": ids[n], "action_description": "walking",
                "directions": ["east"], "animation_name": "walk_east",
                "mode": "v3"})
            if not t.startswith("error"):
                print("walk queued:", n, flush=True)
                break
            time.sleep(40)
        time.sleep(4)

    # 4) kai_evolved3 completion + walk
    while True:
        t = get(ids["kai_evolved3"])
        s = re.search(r"status: (\w+)", t)
        if s and s.group(1) in ("completed", "failed"):
            print("kai_evolved3:", s.group(1), flush=True)
            break
        time.sleep(20)
    while True:
        t, _ = call("animate_character", {
            "character_id": ids["kai_evolved3"], "action_description": "walking",
            "directions": ["east"], "animation_name": "walk_east", "mode": "v3"})
        if not t.startswith("error"):
            break
        time.sleep(40)

    # 5) wait for all walks
    watch = EVOLVED + ["kai_evolved3"]
    while True:
        busy = [n for n in watch if "pending jobs" in get(ids[n])]
        if not busy:
            break
        time.sleep(30)
    print("walks done", flush=True)

    # 6) downloads (characters)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    for n in watch:
        dst = f"{SRC_ROOT}/{n}_v1"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{ids[n]}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        for _ in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    open(f"{dst}/{n}_character.zip", "wb").write(r.read())
                open(f"{dst}/character_info.txt", "w").write(get(ids[n]))
                print("downloaded", n, flush=True)
                break
            except Exception as e:
                print("dl retry", n, e, flush=True)
                time.sleep(20)

    # 7) tilesets: poll + report (downloads handled after inspection)
    for name, tid in tset_ids.items():
        while True:
            t, _ = call("get_topdown_tileset", {"tileset_id": tid})
            if "completed" in t[:200] or "failed" in t[:200]:
                print(f"tileset {name}: done", flush=True)
                open(f"{SRC_ROOT}/tilesets/{name}_info.txt", "w").write(t) if os.path.isdir(f"{SRC_ROOT}/tilesets") or not os.makedirs(f"{SRC_ROOT}/tilesets", exist_ok=True) else None
                break
            time.sleep(25)
    print("BATCH4 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
