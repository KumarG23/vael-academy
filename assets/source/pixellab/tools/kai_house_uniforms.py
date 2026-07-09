"""AW-62: look-test — Kai modelling the Tidemark and Thornrook school uniforms
(rotations only, no walks; approval precedes the full-cast batch next month)."""
from pixellab import call, _token
import json, os, re, time, urllib.request

SRC = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
KAI = "1beea603-131f-41c8-8603-1b3e2a9a6eca"
STATE = os.path.dirname(os.path.abspath(__file__)) + "/kai_house_uni_state.json"
UNIFORMS = {
    "tidemark": ("school uniform outfit: a deep ocean-blue academy uniform "
                 "jacket with silver trim, silver buttons and silver shoulder "
                 "boards, dark trousers, polished shoes, tidy student "
                 "appearance, keep the same hair and skin"),
    "thornrook": ("school uniform outfit: a forest green academy uniform "
                  "jacket with bronze trim, bronze buttons and bronze shoulder "
                  "boards, dark trousers, polished shoes, tidy student "
                  "appearance, keep the same hair and skin"),
}

def main():
    s = json.load(open(STATE)) if os.path.exists(STATE) else {}
    for name, desc in UNIFORMS.items():
        if f"{name}_cid" in s:
            continue
        while True:
            t, _ = call("create_character_state", {"character_id": KAI, "edit_description": desc})
            if not t.startswith("error"):
                break
            time.sleep(40)
        s[f"{name}_cid"] = re.search(r"id: (\S+)", t).group(1)
        json.dump(s, open(STATE, "w"))
        print(f"queued {name}", flush=True)
        time.sleep(5)
    for name in UNIFORMS:
        while True:
            t, _ = call("get_character", {"character_id": s[f"{name}_cid"]})
            m = re.search(r"status: (\w+)", t)
            if m and m.group(1) in ("completed", "failed"):
                print(name, m.group(1), flush=True)
                break
            time.sleep(20)
    for name in UNIFORMS:
        dst = f"{SRC}/kai_uni_{name}"
        os.makedirs(dst, exist_ok=True)
        req = urllib.request.Request(
            f"https://api.pixellab.ai/mcp/characters/{s[f'{name}_cid']}/download",
            headers={"Authorization": f"Bearer {_token()}"})
        with urllib.request.urlopen(req, timeout=180) as r:
            open(f"{dst}/{name}.zip", "wb").write(r.read())
        print("downloaded", name, flush=True)
    print("UNIFORMS COMPLETE", flush=True)

main()
