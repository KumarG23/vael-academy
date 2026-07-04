"""Orchestrate the cast build: finish queuing, wait for characters, queue
walk animations (respecting the 10-concurrent-job cap), download everything."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"

PENDING_CREATES = {
    "tm_knight": "generic tactics-RPG armored knight trooper, heavy deep blue full plate armor with silver trim, closed helm, tower shield and lance, slow heavy bearing, GBA Fire Emblem enemy knight style, strong readable silhouette",
    "tm_mage": "generic tactics-RPG battle mage trooper, deep blue hooded robe with silver trim, face shadowed under hood, glowing spell tome held open, GBA Fire Emblem enemy mage style, strong readable silhouette",
}


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def status_of(text):
    m = re.search(r"status: (\w+)", text)
    return m.group(1) if m else "?"


def try_create(name, desc):
    text, _ = call("create_character", {
        "description": desc, "name": name, "mode": "v3", "size": 32,
        "outline": "single color black outline", "detail": "medium detail"})
    if "error" in text[:20]:
        return None
    m = re.search(r"id: (\S+)", text)
    return m.group(1) if m else None


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))

    # 1. finish queuing the last two when slots open
    pending = dict(PENDING_CREATES)
    while pending:
        for name in list(pending):
            cid = try_create(name, pending[name])
            if cid:
                ids[name] = cid
                del pending[name]
                print(f"queued {name} -> {cid}", flush=True)
        if pending:
            time.sleep(45)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)

    # 2. wait for all characters to complete
    done = set()
    while len(done) < len(ids):
        for name, cid in ids.items():
            if name in done:
                continue
            s = status_of(get(cid))
            if s == "completed":
                done.add(name)
                print(f"character done: {name}", flush=True)
            elif s == "failed":
                print(f"CHARACTER FAILED: {name}", flush=True)
                done.add(name)
        if len(done) < len(ids):
            time.sleep(30)

    # 3. queue walk_east for each (respect job cap: 2 at a time)
    walked = set()
    for name, cid in ids.items():
        ok = False
        while not ok:
            text, _ = call("animate_character", {
                "character_id": cid, "action_description": "walking",
                "directions": ["east"], "animation_name": "walk_east",
                "mode": "v3"})
            if "error" in text[:20]:
                time.sleep(40)
            else:
                ok = True
                print(f"walk queued: {name}", flush=True)
        time.sleep(5)

    # 4. wait for walks
    while True:
        busy = False
        for name, cid in ids.items():
            if "pending jobs" in get(cid):
                busy = True
                break
        if not busy:
            break
        time.sleep(30)
    print("all walks done", flush=True)

    # 5. download zips
    for name, cid in ids.items():
        dst = f"{SRC_ROOT}/{name}_v1"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{cid}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    blob = r.read()
                open(f"{dst}/{name}_character.zip", "wb").write(blob)
                open(f"{dst}/character_info.txt", "w").write(get(cid))
                print(f"downloaded {name}: {len(blob)} bytes", flush=True)
                break
            except Exception as e:
                print(f"download retry {name}: {e}", flush=True)
                time.sleep(20)
    print("ORCHESTRATION COMPLETE", flush=True)


if __name__ == "__main__":
    main()
