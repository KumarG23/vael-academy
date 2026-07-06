"""CAST ROLLOUT 2 (playtest-3, Neal's go 2026-07-06): unique pro-mode battle
kits + chained two-part choreography for the 14 named cast still missing kits,
so EVERY combat unit animates (no fallback). Designs match the approved
portraits; choreography is class-flavored. Resumable state machine, processes
each character into engine kit dirs + a review GIF as it finishes.

Self-contained (does NOT import cast_rollout, whose module body runs a rollout).
Run detached:  cd .../tools && nohup python3 cast_rollout2.py > rollout2.log 2>&1 &
"""
import sys, os, time, re, json, base64, io, zipfile, glob, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab import call, _token
from PIL import Image

SCRATCH = os.path.dirname(os.path.abspath(__file__))
ROOT = "/Users/nealsharma/code/Vael Academy"
STATE_F = f"{SCRATCH}/cast_rollout2_state.json"
IDS_F = f"{SCRATCH}/cast2_kits_ids.json"
STYLE = ", GBA Fire Emblem battle animation style, dynamic ready stance"

# Designs read off the APPROVED portraits (assets/portraits/portrait_<id>.png);
# house palettes: Emberwing crimson/gold, Tidemark blue/silver, Thornrook green/bronze.
CAST = {
 # --- Emberwing ---
 "perrin": {
  "desc": "dashing young cavalier officer, tousled golden-blonde hair, blue eyes, white and dark military uniform with gold epaulettes and a flowing crimson cape, a slender cavalry lance" + STYLE,
  "idle": "upright officer's ready stance, cavalry lance held at an angle, crimson cape stirring in the wind",
  "aw": "levels the lance and rocks back onto his heel, cape flaring, gathering momentum for a charge",
  "as": "surges forward in a galloping lunge driving the lance in a sweeping cavalry thrust at the strike point, cape snapping, then wheels back to stance",
  "cw": "spins the lance overhead in a flashing flourish and sets his feet, cape billowing wide",
  "cs": "explodes forward in a full charging lance run, a bright arc of speed trailing the point as it skewers the strike point, ending in a proud upright flourish"},
 "dain": {
  "desc": "brash muscular young fighter, dark brown skin, messy dark-red hair, sleeveless dark tunic with crimson wrappings baring strong arms, a big broad battle-axe, wide grin" + STYLE,
  "idle": "loose cocky stance, big axe resting across his shoulders, rolling his neck",
  "aw": "grins wide and heaves the axe back low behind him, coiling his whole body",
  "as": "swings the axe up in a brutal rising arc through the strike point, spinning with the follow-through, then catches it back on his shoulder",
  "cw": "roars and winds the axe around his head in a building spin, dust kicking up",
  "cs": "unleashes a whirling double-swing cyclone crashing through the strike point, ending planted with the axe head buried and a triumphant shout"},
 "liora": {
  "desc": "passionate young battle-mage girl, magenta-purple twintail hair, red eyes, white blouse with a crimson ascot and a red flame-lined cape, an open fire tome wreathed in embers" + STYLE,
  "idle": "holds the burning tome at her hip, embers drifting up, hair and cape lifting on the heat",
  "aw": "throws the tome open as a swelling ball of fire gathers in her free hand",
  "as": "hurls a roaring fireball that bursts in flame at the strike point, cape flaring, then the flames settle",
  "cw": "spins with the tome as a spiraling firestorm winds up around her, hair streaming",
  "cs": "unleashes a towering column of roaring flame erupting through the strike point, embers raining, then flourishes the tome shut"},
 # --- Tidemark ---
 "osric": {
  "desc": "immovable young armored knight, short blonde hair, blue eyes, heavy blue-and-silver Tidemark plate armor, a tall tower shield and a long steel lance" + STYLE,
  "idle": "planted behind his tall shield, lance couched, heavy and unmoving",
  "aw": "sets the shield and draws the lance back, plates locking, weight sinking low",
  "as": "rams the shield forward and drives the lance in a heavy piercing thrust at the strike point, then anchors back behind the shield",
  "cw": "hoists the great lance high overhead in both gauntlets, shield lowered",
  "cs": "brings the lance down in a crushing overhead impale through the strike point, armor ringing, then levels it back to guard"},
 "elowen": {
  "desc": "serene young cleric girl, long pale ice-blue hair, gentle blue eyes, flowing white-and-blue robes with gold trim, a silver healer's staff topped with a glowing blue gem" + STYLE,
  "idle": "cradles the staff, robes drifting, a soft blue shimmer at the gem",
  "aw": "lifts the staff overhead as cool blue light gathers into a halo above her",
  "as": "the halo bursts into a spreading ring of gentle blue light at the strike point, robes billowing, then settles",
  "cw": "kneels and plants the staff as ribbons of blue light and snow-like sigils rise around her",
  "cs": "a radiant blue pillar of healing light erupts upward, sigils flaring outward like frost, then fades as she rises"},
 "isolde": {
  "desc": "precise young mage girl, dark navy-blue bobbed hair, cool blue eyes, a blue hooded cloak clasped at the throat over white robes, an open tome ringed with frost" + STYLE,
  "idle": "holds the frost-ringed tome level, pages still, a chill mist curling off it",
  "aw": "opens the tome as a sharp shard of blue ice crystallizes and grows above her palm",
  "as": "fires a lance of jagged ice that shatters against the strike point, cloak snapping, then lowers the tome",
  "cw": "the tome's pages whirl as a ring of spinning ice shards forms around her",
  "cs": "looses a fanning storm of ice spears into the strike point in a burst of frost, then closes the tome crisply"},
 "fenn": {
  "desc": "nimble young archer, tousled bright teal-green hair, green eyes, a light white-and-blue cloak over travel leathers, a curved recurve bow and a quiver of arrows" + STYLE,
  "idle": "light on his feet, bow held low with an arrow loosely nocked, scanning",
  "aw": "draws an arrow, nocks it, and pulls the string to a full taut draw, sighting down the shaft",
  "as": "looses the arrow in a snapping shot that streaks to the strike point, then relaxes the bow",
  "cw": "draws back three arrows at once, the string straining, a keen focus in his eyes",
  "cs": "unleashes a rapid three-arrow volley streaking through the strike point, then spins the bow back to ready"},
 "bertram": {
  "desc": "weathered veteran soldier, greying brown hair, stern lined face, blue-grey scaled armor over a diamond-quilted gambeson, a long steel spear and a round shield" + STYLE,
  "idle": "seasoned guard stance, spear held steady, shield ready, calm and watchful",
  "aw": "rolls the spear once and couches it, stepping into a practiced thrusting stance",
  "as": "drives a hard clean piercing spear thrust into the strike point, then snaps back to guard",
  "cw": "crouches and draws the spear far back, shield raised, coiling with veteran control",
  "cs": "steps in with a vaulting two-step thrust driving the spear through the strike point, then plants it and squares the shield"},
 # --- Thornrook ---
 "corin": {
  "desc": "poised young Thornrook leader girl, auburn hair in a long side braid, brown eyes, freckles, a white shirt with a forest-green vest and a bronze-gold cravat, an open reason tome glowing green" + STYLE,
  "idle": "holds the glowing green tome with quiet composure, pages stirring, a faint green light",
  "aw": "opens the tome as a swirling orb of green wind-magic gathers above her hand",
  "as": "sends a cutting blade of green wind slicing to the strike point, braid whipping, then lowers the tome",
  "cw": "the tome's pages spin as concentric green sigils rotate into being around her",
  "cs": "unleashes a fanning gale of green cutting arcs through the strike point, then snaps the tome shut with poise"},
 "thessaly": {
  "desc": "patient young archer girl, black hair, green eyes, a deep forest-green hooded cloak over leathers, a tall longbow and a quiver of arrows" + STYLE,
  "idle": "still and patient, longbow held low, an arrow lightly nocked, hood up",
  "aw": "draws an arrow smoothly to a long steady full draw, sighting with calm precision",
  "as": "looses a clean piercing shot that streaks to the strike point, then lowers the bow",
  "cw": "draws back a single arrow wreathed in green light, string trembling with held power",
  "cs": "releases a devastating power-shot streaking through the strike point in a green streak, then sweeps the bow back to ready"},
 "corvin": {
  "desc": "bookish young mage, messy black hair, round glasses, a forest-green scholar's cloak over a white shirt, a thick tome held open in one hand" + STYLE,
  "idle": "peers at the open tome pushing his glasses up, faint green arcane motes drifting",
  "aw": "flips the tome open wider as a lattice of green arcane runes assembles above it",
  "as": "casts a bursting bolt of green arcane force at the strike point, cloak stirring, then studies the tome",
  "cw": "the tome's pages flip wildly as a dense web of green sigils spins up around him",
  "cs": "unleashes a cascading barrage of green rune-blasts into the strike point, then adjusts his glasses as the sigils fade"},
 "marlow": {
  "desc": "quick young rogue-swordsman, wavy brown hair, amber eyes, a blue scarf and a short travel cloak over dark leathers, a slender light sword" + STYLE,
  "idle": "loose agile stance, light blade held low and reversed, scarf drifting",
  "aw": "shifts weight onto his back foot and cocks the blade back, a sly focus, ready to dart",
  "as": "darts in with a swift slashing cut across the strike point, then flips the blade and slides back",
  "cw": "sinks low into a sprinter's crouch, an afterimage shimmer building, blade trailing",
  "cs": "blurs forward with a flurry of crossing quick-slashes at the strike point, ending crouched with the blade extended behind"},
 "vesper": {
  "desc": "kind young cleric girl, mint-green hair with a small flower circlet, green eyes, white-and-green robes, a slender staff crowned with a glowing green blossom" + STYLE,
  "idle": "holds the blossom staff close, robes and hair drifting, a soft green glow",
  "aw": "raises the staff as warm green light gathers into a blooming halo above her",
  "as": "the halo opens into a spreading ring of green petals and light at the strike point, then settles",
  "cw": "kneels and plants the staff as spiraling green vines and light sigils rise around her",
  "cs": "a radiant green pillar of life-light blooms upward, petals and sigils flaring out, then fades as she rises"},
 "rurik": {
  "desc": "rugged young frontline fighter, shaggy brown hair, brown eyes, a heavy fur-collared cloak over worn leathers and a green sash, a big bearded battle-axe" + STYLE,
  "idle": "sturdy planted stance, big axe resting head-down, shoulders rolling",
  "aw": "hauls the axe back low over his shoulder, planting his feet, coiling his weight",
  "as": "delivers a heavy diagonal axe chop through the strike point, following through low, then hauls it back up",
  "cw": "grips the axe two-handed and winds up a powerful overhead swing, growling",
  "cs": "brings the axe down in a mighty earth-cracking overhead cleave through the strike point, then wrenches it free and stands tall"},
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

def wait_for_anim(cid, dest, base_folder, slug):
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

def last_frame_b64(zdata, base_folder, slug):
    z, anims = zip_anims(zdata, base_folder)
    folder = find_folder(anims, slug)
    names = sorted(n for n in z.namelist()
                   if n.startswith(f"{base_folder}/animations/{folder}/east/") and n.endswith(".png"))
    return base64.b64encode(z.read(names[-1])).decode()

def _slug(s):
    return s.replace(",", "").replace("'", "").replace(" ", "_")

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
        folder = find_folder(anims, _slug(slug))
        if folder is None:
            print(f"  !! {char}/{t} missing (slug miss)", flush=True)
            continue
        per[t] = frames_of(folder)
    allf = [f for fs in per.values() for f in fs]
    boxes = [f.getbbox() for f in allf if f.getbbox()]
    win = (min(b[0] for b in boxes), min(b[1] for b in boxes),
           max(b[2] for b in boxes), max(b[3] for b in boxes))
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
    seq = []
    for t in ["idle", "attack", "crit", "hit", "ko"]:
        fs = [f.crop(win) for f in per.get(t, [])]
        seq += fs + (fs[-1:] * 2 if fs else [])
    gif = []
    for f in seq:
        bg = Image.new("RGBA", f.size, (28, 30, 38, 255)); bg.alpha_composite(f)
        gif.append(bg.resize((f.size[0]*2, f.size[1]*2), Image.NEAREST).convert("RGB"))
    os.makedirs(f"{ROOT}/assets/art_review/combat_kits", exist_ok=True)
    gif[0].save(f"{ROOT}/assets/art_review/combat_kits/{char}_battle_pro.gif",
                save_all=True, append_images=gif[1:], duration=100, loop=0)
    print(f"  {char} PROCESSED: {[(k, len(v)) for k, v in per.items()]}", flush=True)


ids = json.load(open(IDS_F)) if os.path.exists(IDS_F) else {}
st = load_state()
order = list(CAST.keys())
print(f"CAST2 ROLLOUT: {len(order)} kits -> {order}", flush=True)

while True:
    all_done = True
    creating = [c for c in order if st.get(c, {}).get("phase") == "base_creating"]
    for char in order:
        cs = st.get(char, {})
        phase = cs.get("phase", "none")
        spec = CAST[char]
        if phase == "done":
            continue
        all_done = False
        if phase == "none":
            if len(creating) >= 1:
                continue  # one pro base at a time (job-cap safe)
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
                zdata, bf = wait_for_anim(cs["cid"], f"{dst}/{char}_battle_pro.zip",
                    f"{char}_battle_pro", _slug(spec["cw"]))
                aw_last = last_frame_b64(zdata, bf, _slug(spec["aw"]))
                cw_last = last_frame_b64(zdata, bf, _slug(spec["cw"]))
                cs["base_folder"] = bf
                queue_anim(cs["cid"], "attack_strike_east", 8, spec["as"], start_b64=aw_last)
                queue_anim(cs["cid"], "crit_strike_east", 8, spec["cs"], start_b64=cw_last)
                cs["phase"] = "strikes"; save_state(st)
                print(f"{char}: strikes queued (chained)", flush=True)
        elif phase == "strikes":
            if not char_busy(cs["cid"]):
                dst = f"{ROOT}/assets/source/pixellab/{char}_battle_pro"
                zdata, _bf2 = wait_for_anim(cs["cid"], f"{dst}/{char}_battle_pro.zip",
                    cs["base_folder"], _slug(spec["cs"]))
                process_char(char, zdata, cs["base_folder"], spec)
                ids[char + "_battle_pro"] = cs["cid"]
                json.dump(ids, open(IDS_F, "w"), indent=1)
                cs["phase"] = "done"; save_state(st)
                bal, _ = call("get_balance", {})
                line = [l for l in bal.splitlines() if "remaining" in l]
                print(f"{char}: DONE | {line[0] if line else bal.splitlines()[0]}", flush=True)
    if all_done:
        break
    time.sleep(30)
print("CAST2 ROLLOUT COMPLETE", flush=True)
