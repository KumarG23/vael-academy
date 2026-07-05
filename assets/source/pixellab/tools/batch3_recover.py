"""Recover batch 3: all 25 states completed server-side; the orchestrator
wedged on the mounted-Perrin retry loop. Diagnose the mount once, queue the
kai_evolved walk, wait, download everything, save ids."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


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
            return True
        except Exception as e:
            print(f"dl retry {name}: {e}", flush=True)
            time.sleep(20)
    return False


def main():
    log = open(f"{SCRATCH}/../tasks/bj0z5wr47.output").read()
    pairs = dict(re.findall(r"state queued (\S+) -> (\S+)", log))
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    ids.update(pairs)

    # 1) mounted perrin: try ONCE with raw diagnostics
    text, _ = call("create_character", {
        "description": "golden blond young knight heir in dark navy and "
                       "crimson uniform with gold epaulettes riding an armored "
                       "warhorse with crimson caparison, lance in hand, GBA "
                       "Fire Emblem cavalier style, strong readable silhouette",
        "name": "perrin_mounted", "body_type": "quadruped",
        "template": "horse", "mode": "v3", "size": 48,
        "outline": "single color black outline", "detail": "medium detail"})
    print("MOUNT RAW>>>", text[:400], flush=True)
    m = re.search(r"id: (\S+)", text)
    if m:
        ids["perrin_mounted"] = m.group(1)

    # 2) walk on kai_evolved
    if "kai_evolved" in ids:
        while True:
            t, _ = call("animate_character", {
                "character_id": ids["kai_evolved"],
                "action_description": "walking", "directions": ["east"],
                "animation_name": "walk_east", "mode": "v3"})
            if not t.startswith("error"):
                print("kai_evolved walk queued", flush=True)
                break
            time.sleep(30)

    # 3) wait for mount + walk
    watch = [n for n in ("perrin_mounted", "kai_evolved") if n in ids]
    while True:
        busy = False
        for n in watch:
            t = get(ids[n])
            s = re.search(r"status: (\w+)", t)
            if (s and s.group(1) == "processing") or "pending jobs" in t:
                busy = True
        if not busy:
            break
        time.sleep(25)
    print("all settled", flush=True)

    # 4) download every batch-3 item
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    for name in list(pairs) + (["perrin_mounted"] if "perrin_mounted" in ids else []):
        download(name, ids[name])
    print("RECOVERY COMPLETE", flush=True)


if __name__ == "__main__":
    main()
