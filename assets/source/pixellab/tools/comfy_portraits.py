"""Cast portrait batch on R16 ComfyUI — Pole A per STYLE_BIBLE v3 template.
Hair colors follow the ACTIVE PROPOSALS (pink/blue/mint/teal/violet + Kai's
black-green) so portraits match the sprite recolor review."""
import json
import time
import urllib.request
import os

HOST = "http://100.70.146.106:8188"
OUT = "/Users/nealsharma/code/Vael Academy/assets/art_review/portraits_cast_v1"

BASE_NEG = ("photo, photorealistic, realistic face, real person, 3d render, "
            "cgi, oil painting, impasto, text, watermark, signature, logo, "
            "frame, border, blurry, lowres, deformed, extra fingers, "
            "mutated hands, painterly, heavy shading, muted colors")
NO_ARMOR = ", armor, pauldrons"
NO_FOREST = ", antlers, horns, forest, trees"

E = ("crimson and gold", "dark warm crimson-tinted")
T = ("deep blue and silver", "dark storm-blue-tinted")
R = ("forest green and bronze", "dark green-tinted")

# name: (seed, prompt-core, house, armored?, thornrook?, heroine?)
CAST = {
 "kael":    (1101, "handsome 17 year old young man with tousled auburn red hair and an easy warm grin", E, False, False, False),
 "brenna":  (1102, "beautiful 18 year old young woman with a chestnut brown practical braid and a steady wry look, crimson and gold plate armor over the uniform", E, True, False, True),
 "wren":    (1103, "beautiful 16 year old young woman with soft pastel pink hair and a gentle quiet presence, cream healer robe with crimson trim over the uniform", E, False, False, True),
 "perrin":  (1104, "handsome 18 year old young man with short golden blond hair and a charismatic confident grin, crimson half-cape with gold epaulettes", E, False, False, False),
 "dain":    (1105, "handsome rugged 17 year old young man with short dark red hair and a big brash grin, broad shoulders, sleeveless uniform", E, False, False, False),
 "liora":   (1106, "beautiful 17 year old young woman with long rich violet purple hair tied with a crimson ribbon, proud noble bearing, small flame hovering by her hand", E, False, False, True),
 "osric":   (1107, "handsome 18 year old young man with short sandy hair and a calm immovable look, deep blue plate armor over the uniform", T, True, False, False),
 "elowen":  (1108, "beautiful 17 year old young woman with long silver white hair and a serene kind face, white and blue priestess robe with silver trim", T, False, False, True),
 "isolde":  (1109, "beautiful 17 year old young woman with deep midnight blue hair in a tight formal bun, reserved scholarly bearing, silver-clasped robe", T, False, False, True),
 "fenn":    (1110, "handsome 16 year old young man with messy sea green hair and a playful mischievous grin, short cloak", T, False, False, False),
 "bertram": (1111, "handsome large 18 year old young man with short brown hair and light stubble, solid dependable bearing, chainmail under the uniform", T, True, False, False),
 "thessaly":(1112, "beautiful 17 year old young woman with dark teal hair in a long ponytail and a sharp focused gaze, hooded half-cloak", R, False, True, True),
 "corvin":  (1113, "handsome 17 year old young man with neat black hair and round glasses, thoughtful bookish look, scholar robe", R, False, True, False),
 "marlow":  (1114, "handsome 16 year old young man with tousled brown hair and a blue bandana, sly street-smart grin, fitted scout gear", R, False, True, False),
 "vesper":  (1115, "beautiful 17 year old young woman with pale mint green hair in a braided crown, precise clinical calm, green and cream healer robe", R, False, True, True),
 "rurik":   (1116, "handsome rugged 17 year old young man with shaggy dark hair, outdoorsman look, fur-trimmed uniform", R, False, True, False),
 "callan":  (1117, "handsome weathered 45 year old veteran officer with grey-streaked dark hair and an old burn scar on his jaw, commanding presence, crimson mantle with gold rank braid", E, False, False, False),
 "maren":   (1118, "stern dignified 40 year old woman knight with steel grey hair in a tight braid, disciplined bearing, blue and silver officer armor with long coat", T, True, False, False),
 "alaric":  (1119, "wise 70 year old elderly scholar with a white beard and dry humored eyes, green and bronze archivist robes with hanging seals", R, False, True, False),
 "kai_v2":  (1120, "handsome 17 year old young man with warm brown skin and short practical black hair with dark green highlights, faint silver-white frost-crack mark at his left temple, quietly determined look", E, False, False, False),
}


def workflow(pos, neg, seed):
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": "DreamShaperXL_Turbo_v2_1.safetensors"}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": pos, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": neg, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage",
              "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"model": ["1", 0], "positive": ["2", 0],
                         "negative": ["3", 0], "latent_image": ["4", 0],
                         "seed": seed, "steps": 6, "cfg": 2.0,
                         "sampler_name": "euler", "scheduler": "sgm_uniform",
                         "denoise": 1.0}},
        "6": {"class_type": "VAEDecode",
              "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"images": ["6", 0], "filename_prefix": "cast_portrait"}},
    }


def render(name, seed, core, house, armored, thornrook, heroine):
    colors, bg = house
    charm = ", charming and graceful" if heroine else ""
    pos = (f"2D game character art, clean bright anime cel shading with fine "
           f"ink outlines, large expressive eyes, tactical RPG portrait, "
           f"waist-up bust, {core}, elegant {colors} academy uniform, "
           f"vivid flat saturated colors, simple flat {bg} background, "
           f"stylized official game art{charm}")
    neg = BASE_NEG + ("" if armored else NO_ARMOR) + (NO_FOREST if thornrook else "")
    body = json.dumps({"prompt": workflow(pos, neg, seed)}).encode()
    req = urllib.request.Request(f"{HOST}/prompt", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        pid = json.loads(r.read())["prompt_id"]
    # poll history
    for _ in range(120):
        time.sleep(1.5)
        with urllib.request.urlopen(f"{HOST}/history/{pid}", timeout=30) as r:
            h = json.loads(r.read())
        if pid in h and h[pid].get("outputs"):
            imgs = h[pid]["outputs"]["7"]["images"]
            fn = imgs[0]["filename"]
            sub = imgs[0].get("subfolder", "")
            url = f"{HOST}/view?filename={urllib.parse.quote(fn)}&subfolder={urllib.parse.quote(sub)}&type=output"
            with urllib.request.urlopen(url, timeout=60) as r:
                open(f"{OUT}/{name}_seed{seed}.png", "wb").write(r.read())
            print(f"portrait done: {name} (seed {seed})", flush=True)
            return
    print(f"TIMEOUT: {name}", flush=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (seed, core, house, armored, thorn, heroine) in CAST.items():
        render(name, seed, core, house, armored, thorn, heroine)
    print("PORTRAITS COMPLETE", flush=True)
