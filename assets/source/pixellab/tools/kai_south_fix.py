"""AW-61: redo the SOUTH walks — the plain "walking" action drifts into
three-quarter turns on the south direction (Neal: "he's turning constantly").
Regenerate walk_south for the battle character + both outfit states with an
explicit face-the-camera action, under fresh animation names.
"""
from pixellab import call, _token
import re
import time
import urllib.request
import os

SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
CHARS = {
    "battle": "1beea603-131f-41c8-8603-1b3e2a9a6eca",
    "school": "4f31ac7c-0b30-45bc-8db4-af80cf00101a",
    "party": "5c1a99ac-d698-46e8-9b88-3d22ebdf0e6a",
}
ACTION = ("walking straight forward toward the camera at a steady pace, body "
          "and face pointed directly at the viewer the entire time, no "
          "turning, symmetric stride")


def retry_call(tool, args, label):
    while True:
        try:
            text, _ = call(tool, args)
        except Exception as e:
            print(f"{label}: rpc {str(e)[:70]}, retry", flush=True)
            time.sleep(30)
            continue
        if text.startswith("error"):
            print(f"{label}: busy, retry", flush=True)
            time.sleep(40)
            continue
        return text


def main():
    for name, cid in CHARS.items():
        retry_call("animate_character", {
            "character_id": cid, "action_description": ACTION,
            "directions": ["south"], "animation_name": "walk_south_v2"}, name)
        print(f"queued {name}", flush=True)
        time.sleep(8)
    # wait for all three to list the new anim
    done = set()
    while len(done) < len(CHARS):
        for name, cid in CHARS.items():
            if name in done:
                continue
            t = retry_call("get_character", {"character_id": cid}, name)
            if "walk-south-v2" in t.replace("_", "-") and "processing" not in t:
                done.add(name)
                print(f"{name} done", flush=True)
        if len(done) < len(CHARS):
            time.sleep(25)
    for name, cid in CHARS.items():
        dst = f"{SRC_ROOT}/kai_sfix_{name}"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{cid}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        with urllib.request.urlopen(req, timeout=180) as r:
            open(f"{dst}/{name}.zip", "wb").write(r.read())
        print(f"downloaded {name}", flush=True)
    print("SOUTH FIX COMPLETE", flush=True)


if __name__ == "__main__":
    main()
