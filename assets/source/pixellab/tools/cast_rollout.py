"""THE CAST ROLLOUT (Neal's go, 2026-07-05): pro-mode battle sprites +
chained two-part class choreography for the eight kit characters, plus
Kai's stab redo. Resumable state machine; processes each character into
engine kit dirs + review GIF as it completes."""
import sys, os, time, re, json, base64, io, zipfile, glob, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab import call, _token
from pl_process import shared_window  # noqa (import proves availability)
from PIL import Image

SCRATCH = os.path.dirname(os.path.abspath(__file__))
ROOT = "/Users/nealsharma/code/Vael Academy"
STATE_F = f"{SCRATCH}/cast_rollout_state.json"
STYLE = ", GBA Fire Emblem battle animation style, dynamic ready stance"

CAST = {
 "kael": {
  "desc": "lithe young myrmidon duelist, crimson dark-red hair, dark academy coat with crimson accents, slim curved blade in a sheath at his hip, calm sharp eyes" + STYLE,
  "idle": "iaijutsu ready stance, hand hovering over the sheathed blade, coat swaying gently",
  "aw": "grips the sheathed blade and sinks into a deep iaijutsu draw stance, tension coiling, a faint gleam along the scabbard",
  "as": "instant blinding draw-cut, the blade a silver arc across the strike point, then flicks the blade clean and re-sheathes smoothly",
  "cw": "vanishes low into a sprinter's crouch, afterimage shimmer building around him, hand locked on the hilt",
  "cs": "blurs forward with three crossing slashes in one motion, silver arcs crossing at the strike point, ending sheathed with his back half-turned"},
 "brenna": {
  "desc": "stalwart young female armored knight, black hair, heavy crimson-accented plate armor, tower shield and sturdy lance" + STYLE,
  "idle": "braced behind her tower shield, lance couched, steady heavy breathing",
  "aw": "raises her tower shield and draws the lance back, armor plates setting, weight sinking into her back foot",
  "as": "smashes the shield forward and drives the lance through in a piercing thrust at the strike point, then recovers behind the shield",
  "cw": "plants her feet wide and hoists the lance high overhead with both hands, shield slung at her side",
  "cs": "brings the lance crashing down in a devastating overhead slam, dust bursting at the impact, then levels it back into guard"},
 "wren": {
  "desc": "gentle young cleric girl, pale cream-blonde hair, white robes with crimson trim, wooden healer's staff with a glowing head" + STYLE,
  "idle": "holds her staff close, robes and hair drifting gently, a soft golden shimmer at the staff head",
  "aw": "raises the staff overhead with both hands as golden light gathers into a growing halo above her",
  "as": "the halo bursts outward in an expanding ring of golden light at the strike point, robes billowing, then settles back to stance",
  "cw": "kneels and plants the staff as spinning golden sigils rise around her",
  "cs": "a blinding pillar of radiant light erupts upward around her, sigils flaring outward, then fades as she rises"},
 "serra": {
  "desc": "regal young female knight, long golden blonde hair, polished blue and silver Tidemark plate armor, tall lance" + STYLE,
  "idle": "regal ready stance, lance held tall, long hair drifting",
  "aw": "couches the lance low and braces into a charging stance, plate armor setting, eyes locked forward",
  "as": "lunges forward driving the lance in a piercing skewer at the strike point, hair whipping, then plants and recovers tall",
  "cw": "crouches deep with the lance drawn fully back, cold blue light glinting along its length",
  "cs": "leaps forward and drives the lance down in a devastating pinning skewer, hair flaring, ending in a proud upright recovery"},
 "tm_soldier": {
  "desc": "disciplined soldier in steel blue-grey helmet and dark blue uniform, round shield on his back, long spear" + STYLE,
  "idle": "steady guard stance, spear held ready, slight sway",
  "aw": "twirls the spear once overhead and couches it, stepping into a deep thrusting stance",
  "as": "lunges with a hard piercing spear thrust at the strike point, then snaps the spear back to guard",
  "cw": "crouches and coils, the spear drawn far back behind him, knuckles whitening",
  "cs": "leaping vaulting thrust driving the spear point down into the strike point, then lands back in guard"},
 "tm_knight": {
  "desc": "hulking armored knight in massive blue-silver plate armor with white accents, huge great lance, slow and unstoppable" + STYLE,
  "idle": "immovable heavy stance, great lance grounded, armor plates shifting with each breath",
  "aw": "hefts the great lance slowly overhead, massive armor plates shifting with the weight",
  "as": "crushing two-handed overhead slam at the strike point, dust bursting on impact, then drags the lance back to guard",
  "cw": "lowers into an unstoppable charging stance, lance leveled, visor glinting",
  "cs": "charges a thunderous step forward and delivers a devastating skewering drive through the strike point, then plants the lance triumphantly"},
 "tm_mage": {
  "desc": "hooded dark mage in grey-violet and deep blue robes, face shadowed, ancient tome floating open in his hands" + STYLE,
  "idle": "hovers a hand over the open tome, pages stirring, faint dark motes drifting",
  "aw": "opens the tome wide as a crackling dark orb gathers and swells between his hands",
  "as": "hurls the crackling dark orb at the strike point where it bursts, robes whipping, then closes the tome",
  "cw": "the tome's pages whirl violently as a storm of dark sigils spins up around him",
  "cs": "unleashes a fanning eruption of dark bolts into the strike point, then snaps the tome shut as the hood settles"},
 "bandit": {
  "desc": "hulking scarred bandit brigand, wild dark hair and stubble, bare chest with leather harness, heavy brutal iron axe" + STYLE,
  "idle": "hunched menacing stance, axe resting on his shoulder, chest heaving",
  "aw": "hefts the heavy axe high overhead with both hands, muscles coiling, leaning far back",
  "as": "brutal overhead chop crashing down through the strike point, follow-through burying low, then wrenches the axe back up",
  "cw": "roars and coils into a deep crouch, the axe trailing low behind him",
  "cs": "berserk leaping slam, crashing the axe down through the strike point with his whole body, ending hunched over the impact"},
}
HIT = "staggers backward from a heavy blow, gritting against it"
KO = "drops the weapon, sways, and collapses to the ground, defeated"

def load_state():
    return json.load(open(STATE_F)) if os.path.exists(STATE_F) else {}
def save_state(st):
    json.dump(st, open(STATE_F, "w"), indent=1)

def rpc_retry(tool, args, label):
    while True:
        t, _ = call(tool, args)
        low = t.lower()
        if "confirm" in low and "cost" in low:
            args = dict(args); args["confirm_cost"] = True
            continue
        if not low.startswith("error"):
            return t
        if "422" in low or "validation" in low:
            raise SystemExit(f"PERMANENT ({label}): {t[:250]}")
        print(f"  retry {label}: {t[:80]}", flush=True)
        time.sleep(35)

def char_busy(cid):
    t, _ = call("get_character", {"character_id": cid})
    return ("status: creating" in t) or ("pending jobs" in t) or ("processing" in t)

def wait_for_anim(cid, dest, base_folder, slug):
    """Wait until the character is idle AND the animation actually exists in
    the downloaded zip (queuing has a registration lag)."""
    time.sleep(12)
    while True:
        while char_busy(cid):
            time.sleep(25)
        zdata = download_zip(cid, dest)
        _, anims = zip_anims(zdata, base_folder)
        if not anims:
            z2 = zipfile.ZipFile(io.BytesIO(zdata))
            base_folder = sorted(set(n.split("/")[0] for n in z2.namelist()))[0]
            _, anims = zip_anims(zdata, base_folder)
        if find_folder(anims, slug):
            return zdata, base_folder
        print("  anim not in zip yet, waiting...", flush=True)
        time.sleep(25)


def queue_anim(cid, name, fc, action, start_b64=None):
    args = {"character_id": cid, "action_description": action,
            "directions": ["east"], "animation_name": name,
            "mode": "v3", "frame_count": fc}
    if start_b64:
        args["custom_start_frame_base64"] = start_b64
        args["keep_first_frame"] = True
    rpc_retry("animate_character", args, name)
    print("  queued", name, flush=True)
    time.sleep(2)

def download_zip(cid, dest):
    req = urllib.request.Request(
        f"https://api.pixellab.ai/mcp/characters/{cid}/download",
        headers={"Authorization": f"Bearer {_token()}"})
    for _ in range(6):
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                data = r.read()
            open(dest, "wb").write(data)
            return data
        except Exception as e:
            print("  dl retry", e, flush=True)
            time.sleep(25)
    raise SystemExit("download failed: " + cid)

def zip_anims(zdata, base_folder):
    z = zipfile.ZipFile(io.BytesIO(zdata))
    return z, sorted(set(n.split("/")[2] for n in z.namelist()
                     if n.startswith(f"{base_folder}/animations/")))

def find_folder(anims, slug):
    key = re.sub(r"[^a-z0-9]", "", slug.lower())[:30]
    for a in anims:
        if re.sub(r"[^a-z0-9]", "", a.lower()).startswith(key):
            return a
    return None

def last_frame_b64(zdata, base_folder, slug):
    z, anims = zip_anims(zdata, base_folder)
    folder = find_folder(anims, slug)
    names = sorted(n for n in z.namelist()
                   if n.startswith(f"{base_folder}/animations/{folder}/east/") and n.endswith(".png"))
    return base64.b64encode(z.read(names[-1])).decode()

def process_char(char, zdata, base_folder, spec):
    z, anims = zip_anims(zdata, base_folder)
    def frames_of(folder):
        names = sorted(n for n in z.namelist()
                       if n.startswith(f"{base_folder}/animations/{folder}/east/") and n.endswith(".png"))
        return [Image.open(io.BytesIO(z.read(n))).convert("RGBA") for n in names]
    slugs = {"idle": spec["idle"], "hit": HIT, "ko": KO,
             "attack_wind": spec["aw"], "attack_strike": spec["as"],
             "crit_wind": spec["cw"], "crit_strike": spec["cs"]}
    per = {}
    for t, slug in slugs.items():
        folder = find_folder(anims, slug.replace(",", "").replace("'", "").replace(" ", "_"))
        if folder is None:
            print(f"  !! {char}/{t} missing (slug miss)", flush=True)
            continue
        per[t] = frames_of(folder)
    allf = [f for fs in per.values() for f in fs]
    boxes = [f.getbbox() for f in allf if f.getbbox()]
    win = (min(b[0] for b in boxes), min(b[1] for b in boxes),
           max(b[2] for b in boxes), max(b[3] for b in boxes))
    # synthesized single-segment fallbacks keep has_kit + old path alive
    per["attack"] = per.get("attack_wind", []) + per.get("attack_strike", [])
    per["crit"] = per.get("crit_wind", []) + per.get("crit_strike", [])
    for target, fs in per.items():
        if not fs:
            continue
        out = f"{ROOT}/assets/art/pixellab/{char}/{target}_east"
        os.makedirs(out, exist_ok=True)
        for old in glob.glob(f"{out}/{target}_f*.png"):
            os.remove(old)
        for i, f in enumerate(fs):
            f.crop(win).save(f"{out}/{target}_f{i+1}.png")
    # review GIF
    seq = []
    for t in ["idle", "attack", "crit", "hit", "ko"]:
        fs = [f.crop(win) for f in per.get(t, [])]
        seq += fs + (fs[-1:] * 2 if fs else [])
    gif = []
    for f in seq:
        bg = Image.new("RGBA", f.size, (28, 30, 38, 255)); bg.alpha_composite(f)
        gif.append(bg.resize((f.size[0]*2, f.size[1]*2), Image.NEAREST).convert("RGB"))
    gif[0].save(f"{ROOT}/assets/art_review/combat_kits/{char}_battle_pro.gif",
                save_all=True, append_images=gif[1:], duration=100, loop=0)
    print(f"  {char} PROCESSED: {[(k, len(v)) for k, v in per.items()]}", flush=True)

ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
st = load_state()

# --- Kai stab redo first (chained pair on the existing pro character) ---
if not st.get("kai_stab_done"):
    kcid = ids["kai_battle_pro"]
    queue_anim(kcid, "stab_wind_east", 8,
        "draws the glowing green sword back to his hip in a fencer's stance, coiling low, the green energy compressing into a brilliant point at the blade tip")
    zdata, _bf = wait_for_anim(kcid, f"{ROOT}/assets/source/pixellab/kai_battle_pro/kai_battle_pro.zip",
        "kai_battle_pro", "draws_the_glowing_green_sword")
    wl = last_frame_b64(zdata, "kai_battle_pro", "draws_the_glowing_green_sword")
    queue_anim(kcid, "stab_strike_east", 8,
        "explodes forward in a lightning-fast piercing thrust, green energy spiraling around the fully extended blade like a drill at the strike point, then whips the blade back to stance",
        start_b64=wl)
    zdata, _bf = wait_for_anim(kcid, f"{ROOT}/assets/source/pixellab/kai_battle_pro/kai_battle_pro.zip",
        "kai_battle_pro", "explodes_forward_in_a_lightning")
    z, anims = zip_anims(zdata, "kai_battle_pro")
    def kf(slug):
        folder = find_folder(anims, slug)
        names = sorted(n for n in z.namelist()
                       if n.startswith(f"kai_battle_pro/animations/{folder}/east/") and n.endswith(".png"))
        return [Image.open(io.BytesIO(z.read(n))).convert("RGBA") for n in names]
    wind = kf("draws_the_glowing_green_sword")
    strike = kf("explodes_forward_in_a_lightning")
    win = (29, 38, 195, 200)  # kai's established window
    for target, fs in [("attack_wind", wind), ("attack_strike", strike), ("attack", wind + strike)]:
        out = f"{ROOT}/assets/art/pixellab/kai/{target}_east"
        for old in glob.glob(f"{out}/{target}_f*.png"):
            os.remove(old)
        os.makedirs(out, exist_ok=True)
        for i, f in enumerate(fs):
            f.crop(win).save(f"{out}/{target}_f{i+1}.png")
    print("KAI STAB INSTALLED", flush=True)
    st["kai_stab_done"] = True
    save_state(st)

# --- the cast state machine ---
order = list(CAST.keys())
while True:
    all_done = True
    creating = [c for c in order if st.get(c, {}).get("phase") in ("base_creating",)]
    for char in order:
        cs = st.get(char, {})
        phase = cs.get("phase", "none")
        spec = CAST[char]
        if phase == "done":
            continue
        all_done = False
        if phase == "none":
            if len(creating) >= 1:
                continue  # one pro base at a time
            t = rpc_retry("create_character", {"description": spec["desc"],
                "name": f"{char}_battle_pro", "mode": "pro", "size": 128,
                "detail": "high detail"}, f"{char} base")
            cs = {"cid": re.search(r"id: (\S+)", t).group(1), "phase": "base_creating"}
            st[char] = cs; save_state(st)
            creating.append(char)
            print(f"{char}: base creating -> {cs['cid']}", flush=True)
        elif phase == "base_creating":
            if not char_busy(cs["cid"]):
                queue_anim(cs["cid"], "idle_east", 8, spec["idle"])
                queue_anim(cs["cid"], "hit_east", 6, HIT)
                queue_anim(cs["cid"], "ko_east", 8, KO)
                queue_anim(cs["cid"], "attack_wind_east", 8, spec["aw"])
                queue_anim(cs["cid"], "crit_wind_east", 8, spec["cw"])
                cs["phase"] = "anims1"; save_state(st)
                print(f"{char}: anims1 queued", flush=True)
        elif phase == "anims1":
            if not char_busy(cs["cid"]):
                dst = f"{ROOT}/assets/source/pixellab/{char}_battle_pro"
                os.makedirs(dst, exist_ok=True)
                slug_cw = spec["cw"].replace(",", "").replace("'", "").replace(" ", "_")
                zdata, bf = wait_for_anim(cs["cid"], f"{dst}/{char}_battle_pro.zip",
                    f"{char}_battle_pro", slug_cw)
                aw_last = last_frame_b64(zdata, bf, spec["aw"].replace(",", "").replace("'", "").replace(" ", "_"))
                cw_last = last_frame_b64(zdata, bf, spec["cw"].replace(",", "").replace("'", "").replace(" ", "_"))
                cs["base_folder"] = bf
                queue_anim(cs["cid"], "attack_strike_east", 8, spec["as"], start_b64=aw_last)
                queue_anim(cs["cid"], "crit_strike_east", 8, spec["cs"], start_b64=cw_last)
                cs["phase"] = "strikes"; save_state(st)
                print(f"{char}: strikes queued (chained)", flush=True)
        elif phase == "strikes":
            if not char_busy(cs["cid"]):
                dst = f"{ROOT}/assets/source/pixellab/{char}_battle_pro"
                slug_cs = spec["cs"].replace(",", "").replace("'", "").replace(" ", "_")
                zdata, _bf2 = wait_for_anim(cs["cid"], f"{dst}/{char}_battle_pro.zip",
                    cs["base_folder"], slug_cs)
                process_char(char, zdata, cs["base_folder"], spec)
                ids[char + "_battle_pro"] = cs["cid"]
                json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
                cs["phase"] = "done"; save_state(st)
                bal, _ = call("get_balance", {})
                print(f"{char}: DONE | {bal.splitlines()[1]}", flush=True)
    if all_done:
        break
    time.sleep(30)
print("CAST ROLLOUT COMPLETE", flush=True)
