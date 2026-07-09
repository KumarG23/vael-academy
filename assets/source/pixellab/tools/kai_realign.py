"""AW-59: Kai sprite re-align — regenerate his PixelLab character to match the
new Gemini portrait canon (green-streaked black hair, amber eyes, navy dress
uniform with gold epaulettes, red cravat, glowing green crown mark).

Phase 1 (this script, resumable): create the character (v3), queue walking
animations east/north/south, queue the weaponless empty-hands state, download
all zips. Processing to engine sprites happens interactively afterwards.

State: kai_realign_state.json. Run detached; safe to re-run.
"""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
STATE = f"{SCRATCH}/kai_realign_state.json"

DESC = ("full body young male academy lord standing, wearing a dark navy "
        "military dress uniform coat with gold epaulettes and gold trim, "
        "dark trousers and boots, a small red cravat at the white collar, "
        "black hair with vivid green highlight streaks, warm brown skin, "
        "heroic adventurer proportions, complete figure head to feet")

WEAPONLESS = ("empty hands, not holding any weapon or item, hands relaxed at "
              "his sides, keep every part of the outfit, hair and colors "
              "exactly the same")


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s):
    json.dump(s, open(STATE, "w"), indent=1)


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def status_of(text):
    m = re.search(r"status: (\w+)", text)
    return m.group(1) if m else "?"


def wait_done(cid, label):
    while True:
        s = status_of(get(cid))
        if s in ("completed", "failed"):
            print(f"{label}: {s}", flush=True)
            return s == "completed"
        time.sleep(20)


def retry_call(tool, args, label):
    while True:
        try:
            text, _ = call(tool, args)
        except Exception as e:
            print(f"{label}: rpc error {str(e)[:80]}, retrying", flush=True)
            time.sleep(30)
            continue
        if text.startswith("error"):
            print(f"{label}: busy ({text[:60]}), retrying", flush=True)
            time.sleep(40)
            continue
        return text


def download(name, cid):
    dst = f"{SRC_ROOT}/{name}"
    os.makedirs(dst, exist_ok=True)
    req = urllib.request.Request(
        f"https://api.pixellab.ai/mcp/characters/{cid}/download",
        headers={"Authorization": f"Bearer {_token()}"})
    for _ in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                open(f"{dst}/{name}.zip", "wb").write(r.read())
            open(f"{dst}/character_info.txt", "w").write(get(cid))
            print(f"downloaded {name}", flush=True)
            return True
        except Exception as e:
            print(f"download {name}: {str(e)[:80]}, retrying", flush=True)
            time.sleep(20)
    return False


def main():
    s = load_state()

    # 1. the new character
    if "cid" not in s:
        text = retry_call("create_character", {
            "description": DESC, "name": "kai_v2_crown", "mode": "v3",
            "size": 32, "outline": "single color black outline",
            "detail": "medium detail"}, "create")
        s["cid"] = re.search(r"id: (\S+)", text).group(1)
        save_state(s)
        print(f"character queued: {s['cid']}", flush=True)
    if not s.get("cid_done"):
        if not wait_done(s["cid"], "character"):
            print("CHARACTER FAILED — stopping", flush=True)
            return
        s["cid_done"] = True
        save_state(s)

    # 2. walking animations, one direction at a time (job cap friendliness)
    for d in ["east", "north", "south"]:
        key = f"walk_{d}"
        if s.get(key + "_queued"):
            continue
        retry_call("animate_character", {
            "character_id": s["cid"], "action_description": "walking",
            "directions": [d], "animation_name": f"walk_{d}"}, key)
        s[key + "_queued"] = True
        save_state(s)
        print(f"queued {key}", flush=True)
        time.sleep(10)

    # 3. the weaponless empty-hands state (for the CombatRig body_map set)
    if "state_cid" not in s:
        text = retry_call("create_character_state", {
            "character_id": s["cid"], "edit_description": WEAPONLESS,
            "use_color_palette_from_reference": True}, "weaponless")
        s["state_cid"] = re.search(r"id: (\S+)", text).group(1)
        save_state(s)
        print(f"weaponless state queued: {s['state_cid']}", flush=True)

    # 4. wait for everything on the character (anims report through get_character)
    #    and for the state character, then download both zips.
    if not s.get("anims_done"):
        while True:
            t = get(s["cid"])
            # a finished walk lists as e.g. "custom-walking (north, 9f)" — require
            # ALL three directions listed AND nothing still in flight.
            have_all = all(f"({d}," in t for d in ["east", "north", "south"])
            busy = ("processing" in t) or ("queued" in t)
            if have_all and not busy:
                break
            print(f"anims cooking (have_all={have_all}, busy={busy})", flush=True)
            time.sleep(30)
        s["anims_done"] = True
        save_state(s)
        print("animations done", flush=True)
    if not s.get("state_done"):
        wait_done(s["state_cid"], "weaponless state")
        s["state_done"] = True
        save_state(s)

    if not s.get("downloaded"):
        ok1 = download("kai_v2", s["cid"])
        ok2 = download("kai_v2_weaponless", s["state_cid"])
        s["downloaded"] = ok1 and ok2
        save_state(s)
    print("PHASE 1 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
