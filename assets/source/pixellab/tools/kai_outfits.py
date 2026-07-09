"""AW-60: Kai outfit variants from the NEW character (kai_v2_crown) — school
uniform + party formalwear (battle gear = the new default set). Each variant is
a character state with its own walk E/N/S. Resumable; run detached.
"""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
STATE = f"{SCRATCH}/kai_outfits3_state.json"
KAI_V2 = "1beea603-131f-41c8-8603-1b3e2a9a6eca"

OUTFITS = {
    "school": ("school uniform outfit: a vivid crimson red academy uniform "
               "jacket with gold trim, gold buttons and gold shoulder boards, "
               "dark trousers, polished shoes, tidy student appearance, keep "
               "the same hair and skin"),
    "party": ("flamboyant festival formalwear: an emerald green and gold "
              "brocade dress coat with swirling gold embroidery, a cream "
              "sash, polished boots, gaudy noble festival style, no weapons, "
              "keep the same hair and skin"),
}


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s):
    json.dump(s, open(STATE, "w"), indent=1)


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def wait_done(cid, label):
    while True:
        m = re.search(r"status: (\w+)", get(cid))
        st = m.group(1) if m else "?"
        if st in ("completed", "failed"):
            print(f"{label}: {st}", flush=True)
            return st == "completed"
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
            print(f"downloaded {name}", flush=True)
            return True
        except Exception as e:
            print(f"download {name}: {str(e)[:80]}, retrying", flush=True)
            time.sleep(20)
    return False


def main():
    s = load_state()
    # 1. the outfit states
    for name, desc in OUTFITS.items():
        if f"{name}_cid" in s:
            continue
        text = retry_call("create_character_state", {
            "character_id": KAI_V2, "edit_description": desc}, name)  # NO palette lock — recolors need freedom
        s[f"{name}_cid"] = re.search(r"id: (\S+)", text).group(1)
        save_state(s)
        print(f"{name} state queued: {s[f'{name}_cid']}", flush=True)
        time.sleep(5)
    for name in OUTFITS:
        if not s.get(f"{name}_done"):
            if not wait_done(s[f"{name}_cid"], name):
                print(f"{name} FAILED — stopping", flush=True)
                return
            s[f"{name}_done"] = True
            save_state(s)

    # 2. walks per outfit, one at a time (job cap)
    for name in OUTFITS:
        for d in ["east", "north", "south"]:
            key = f"{name}_walk_{d}"
            if s.get(key):
                continue
            retry_call("animate_character", {
                "character_id": s[f"{name}_cid"],
                "action_description": "walking", "directions": [d],
                "animation_name": f"walk_{d}"}, key)
            s[key] = True
            save_state(s)
            print(f"queued {key}", flush=True)
            time.sleep(8)

    # 3. wait until each state's three walks are LISTED and nothing's in flight
    for name in OUTFITS:
        if s.get(f"{name}_anims_done"):
            continue
        while True:
            t = get(s[f"{name}_cid"])
            have_all = all(f"({d}," in t for d in ["east", "north", "south"])
            busy = ("processing" in t) or ("queued" in t)
            if have_all and not busy:
                break
            print(f"{name} anims cooking (have_all={have_all})", flush=True)
            time.sleep(30)
        s[f"{name}_anims_done"] = True
        save_state(s)
        print(f"{name} animations done", flush=True)

    # 4. download
    for name in OUTFITS:
        if not s.get(f"{name}_dl"):
            s[f"{name}_dl"] = download(f"kai_v4_{name}", s[f"{name}_cid"])
            save_state(s)
    print("OUTFITS COMPLETE", flush=True)


if __name__ == "__main__":
    main()
