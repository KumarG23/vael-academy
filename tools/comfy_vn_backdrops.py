#!/usr/bin/env python3
"""AW-79: painted VN backdrops on R16 ComfyUI — one image PER STORY BEAT.

Neal's direction: the prologue's story beats deserve painted, storybook-rich
backgrounds (the pixel-room renders barely change while the narrator talks).
Backgrounds are the lane where ComfyUI shines: no characters, no identity
drift — just places and light.

Usage:
    python3 tools/comfy_vn_backdrops.py            # all beats, 3 seeds each
    python3 tools/comfy_vn_backdrops.py forest_path sanctum   # named beats

Output: assets/art_review/vn_backdrops_v1/<beat>_seed<k>.png for Neal's pick;
winners get copied to assets/art/vn/painted/<beat>.png and wired into the
prologue scripts.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

HOST = "http://100.70.146.106:8188"
OUT = Path("/Users/nealsharma/code/Vael Academy/assets/art_review/vn_backdrops_v1")

# The shared visual identity for every VN backdrop — painted storybook fantasy,
# matched to the game's warm register. NO people, ever (portraits overlay).
STYLE = ("beautiful painted fantasy background art, storybook illustration, "
         "visual novel background, rich warm painterly lighting, soft brushwork, "
         "detailed environment concept art, atmospheric depth, no people, empty scene")
NEG = ("people, person, character, figure, silhouette of a person, face, hands, "
       "text, watermark, signature, logo, frame, border, photo, photorealistic, "
       "3d render, blurry, lowres, oversaturated neon")

# beat id -> prompt core. Green = ward-light, gold = hearthlight (canon colors).
BEATS = {
    # Scene 1 — the forest
    "forest_path": "deep ancient forest in late golden afternoon, a faint foraging trail winding between mossy roots and towering trees, shafts of warm sunlight through the canopy, ferns and wildflowers",
    "cave_mouth": "a plain unremarkable cave mouth set into a low rocky hillside at the edge of a deep forest, afternoon light, tall grass and old stones, quiet and ordinary",
    # Scene 2 — the cave and the sanctum
    "cave_dark": "inside a narrow dark cave passage, rough wet stone walls, the last coin of daylight glowing far behind, cold blue darkness ahead",
    "sealed_door": "facing a single flat vast wall of seamless ancient worked stone that fills the frame, deep underground, glowing green runes arranged in one great perfect circle on the wall like a crown drawn in light, the circle of green light is the only light source, cold surrounding darkness, frontal view, symmetrical, monumental scale, sense of being watched",
    "sanctum": "a small round dark stone chamber, in the exact center one jagged dark stone shard LEVITATING in mid-air high above the floor, clearly hovering with empty air beneath it, small golden glowing runes orbiting the floating shard in a ring, warm ember-gold radiance spilling from the floating stone onto the floor below, the only light in the darkness, dust motes drifting, centered composition, quiet awe",
    "light_column": "seen from a distant village at dusk: a colossal column of white-gold light standing up out of a forested hill into the evening sky, awestruck scale, small cottages with warm windows in the foreground distance",
    # Scenes 3–5 — Oakstead (for the next wiring pass)
    "cottage_morning": "inside a humble cozy forager's cottage bedroom in warm morning light, rough wooden beams, a simple bed, a water basin, herbs hanging to dry",
    "kitchen_lantern": "a humble cottage kitchen at night by lantern light, a worn wooden table with an oilcloth bundle tied with soft cord lying on it, two empty chairs, warm and heavy quiet",
    "gate_firstlight": "a cottage gate at first light, a dirt road dropping away toward a wide valley with distant spires far away, cold dawn mist, one warm lit window behind",
}

# v3 concept re-aims (turbo kept painting altars and gothic halls):
# a beat may be (prompt, extra_negative) — the extra bans the failure modes.
BEATS["sealed_door_v3"] = (
    "an enormous ancient round stone door filling the entire frame, set flush "
    "into a rough dark cave wall, thin glowing green lines carved into the door "
    "tracing one great perfect circle like a crown drawn in light, frontal "
    "symmetrical composition, the green tracery is the only light source, cold "
    "darkness pressing in at the edges, monumental, silent",
    "hallway, corridor, columns, pillars, archway, cathedral, hall, statue, "
    "cloaked figure, robed figure, altar, stairs")
BEATS["sanctum_v3"] = (
    "a single massive dark crystal shard floating weightlessly in mid-air at "
    "the center of a small round dark cave chamber, clearly hovering with "
    "empty air between it and the floor, soft warm golden light glowing from "
    "cracks within the crystal, a ring of tiny golden runes circling it in "
    "the air, warm gold light pooling on the bare stone floor beneath, deep "
    "darkness all around the edges, quiet awe, centered composition",
    "altar, pedestal, basin, brazier, bonfire, fire, torch, campfire, table, "
    "columns, pillars, statue, figure, sunbeams, windows")

SEEDS = [31, 47, 62, 78, 93]


def workflow(pos: str, seed: int) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": "DreamShaperXL_Turbo_v2_1.safetensors"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage",
              "inputs": {"width": 1344, "height": 768, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0],
                         "latent_image": ["4", 0], "seed": seed, "steps": 6, "cfg": 2.0,
                         "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "vn_backdrop"}},
    }


def render(beat: str, core, seed: int) -> None:
    extra_neg = ""
    if isinstance(core, tuple):
        core, extra_neg = core
    pos = f"{STYLE}, {core}"
    wf = workflow(pos, seed)
    if extra_neg:
        wf["3"]["inputs"]["text"] = NEG + ", " + extra_neg
    body = json.dumps({"prompt": wf}).encode()
    req = urllib.request.Request(f"{HOST}/prompt", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        pid = json.loads(r.read())["prompt_id"]
    for _ in range(120):
        time.sleep(1.5)
        with urllib.request.urlopen(f"{HOST}/history/{pid}", timeout=30) as r:
            h = json.loads(r.read())
        if pid in h and h[pid].get("outputs"):
            img = h[pid]["outputs"]["7"]["images"][0]
            url = "%s/view?filename=%s&subfolder=%s&type=output" % (
                HOST, urllib.parse.quote(img["filename"]),
                urllib.parse.quote(img.get("subfolder", "")))
            with urllib.request.urlopen(url, timeout=60) as r:
                (OUT / f"{beat}_seed{seed}.png").write_bytes(r.read())
            print(f"done: {beat} seed {seed}", flush=True)
            return
    print(f"TIMEOUT: {beat} seed {seed}", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    picked = sys.argv[1:] or list(BEATS)
    for beat in picked:
        for seed in SEEDS:
            render(beat, BEATS[beat], seed)


if __name__ == "__main__":
    main()
