"""Batch 3: fixes (corin walk, staff walks), hair-color states, Kai new hair
+ evolution, 17 promotions, weapon-swap retry, mounted Perrin experiment."""
from pixellab import call, _token
import json
import os
import re
import time
import urllib.request

SCRATCH = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = "/Users/nealsharma/code/Vael Academy/assets/source/pixellab"
STAFF_WALK = ("walking, holding the staff low at the side in one hand, "
              "staff angled behind the body, face fully visible")

# hair-color proposal states (rotations only, for Neal's pick)
HAIR_STATES = [
    ("wren_hair_pink", "wren", "hair recolored to soft pastel pink"),
    ("isolde_hair_blue", "isolde", "hair recolored to deep midnight blue"),
    ("vesper_hair_mint", "vesper", "hair recolored to pale mint green"),
    ("thessaly_hair_teal", "thessaly", "hair recolored to dark teal"),
    ("liora_hair_violet", "liora", "hair recolored to rich violet purple"),
    ("kai_hair_green", "kai", "hair recolored to black with dark green highlights"),
]

PROMOTIONS = [
    ("brenna_general", "brenna", "promoted to general: heavier ornate crimson-gold plate armor, larger tower shield, plumed helm carried under arm"),
    ("wren_bishop", "wren", "promoted to bishop: ornate white and crimson vestments with gold embroidery, taller radiant staff"),
    ("serra_general", "serra", "promoted to general: full ornate navy and silver plate armor, larger lance, commander's half-cape"),
    ("corin_sniper", "corin", "promoted to sniper: elegant longbow, hooded green and bronze ranger cloak, quiver of fine arrows"),
    ("perrin_paladin", "perrin", "promoted to paladin: gleaming gold-trimmed armor over the uniform, longer crimson cape, ornate lance"),
    ("dain_warrior", "dain", "promoted to warrior: heavier pauldron on one shoulder, twin battle axes, war paint"),
    ("liora_sage", "liora", "promoted to sage: flowing mage robes with gold sigils over the uniform, floating fire tome"),
    ("osric_general", "osric", "promoted to general: massive ornate blue plate armor, greatshield with silver leviathan crest"),
    ("elowen_bishop", "elowen", "promoted to bishop: flowing white and blue vestments with silver embroidery, radiant crystal staff"),
    ("isolde_sage", "isolde", "promoted to sage: ornate scholar robes with silver runes, floating glowing tome"),
    ("fenn_sentinel", "fenn", "promoted to sentinel: reinforced light armor with silver trim, longer winged javelin, flowing short cape"),
    ("bertram_sentinel", "bertram", "promoted to sentinel: heavy plated blue armor, ornate halberd with silver blade"),
    ("thessaly_sniper", "thessaly", "promoted to sniper: masterwork longbow, longer hooded cloak, bronze arm guard"),
    ("corvin_sage", "corvin", "promoted to sage: grand green scholar robes with bronze trim, floating open tome with glowing script"),
    ("marlow_assassin", "marlow", "promoted to assassin: darker fitted gear with hood up, longer twin blades, half-mask scarf"),
    ("vesper_bishop", "vesper", "promoted to bishop: refined green and cream vestments with bronze embroidery, tall crystal-tipped staff"),
    ("rurik_berserker", "rurik", "promoted to berserker: bare-armed fur and bronze war gear, massive two-handed axe, wild hair"),
]

WEAPON_RETRY = ("tm_soldier_sword2", "tm_soldier",
                "the spear is gone entirely; he holds a short steel arming "
                "sword raised in his right hand and a round wooden shield "
                "strapped on his left arm")


def get(cid):
    text, _ = call("get_character", {"character_id": cid})
    return text


def wait_completed(cid, label):
    while True:
        t = get(cid)
        s = re.search(r"status: (\w+)", t)
        if s and s.group(1) in ("completed", "failed"):
            print(f"{label}: {s.group(1)}", flush=True)
            return s.group(1) == "completed"
        time.sleep(20)


def queue_state(name, src_id, edit, palette=False):
    while True:
        text, _ = call("create_character_state", {
            "character_id": src_id, "edit_description": edit,
            "use_color_palette_from_reference": palette})
        if not text.startswith("error"):
            m = re.search(r"id: (\S+)", text)
            print(f"state queued {name} -> {m.group(1)}", flush=True)
            return m.group(1)
        time.sleep(45)


def queue_walk(cid, name, action="walking"):
    while True:
        text, _ = call("animate_character", {
            "character_id": cid, "action_description": action,
            "directions": ["east"], "animation_name": "walk_east", "mode": "v3"})
        if not text.startswith("error"):
            print(f"walk queued: {name}", flush=True)
            return
        time.sleep(40)


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
            return
        except Exception as e:
            print(f"retry dl {name}: {e}", flush=True)
            time.sleep(20)


def main():
    ids = json.load(open(f"{SCRATCH}/cast_ids.json"))
    new = {}

    # 1) fix walks: corin (missing), vesper + alaric (staff over face)
    for n in ("vesper", "alaric"):
        call("delete_animation", {"character_id": ids[n],
                                  "animation_type": "walking", "confirm": True})
        queue_walk(ids[n], n, STAFF_WALK)
    queue_walk(ids["corin"], "corin")

    # 2) hair states
    for name, src, edit in HAIR_STATES:
        new[name] = queue_state(name, ids[src], edit)

    # 3) kai evolution chained from the green-hair state
    if wait_completed(new["kai_hair_green"], "kai_hair_green"):
        new["kai_evolved"] = queue_state(
            "kai_evolved", new["kai_hair_green"],
            "promoted lord: headband removed, glowing silver-white frost-crack "
            "mark across his left temple and brow, longer dark coat with "
            "crimson lining, confident bearing")
    else:
        new["kai_evolved"] = queue_state(
            "kai_evolved", ids["kai"],
            "promoted lord: black hair with dark green highlights, headband "
            "removed, glowing silver-white frost-crack mark across his left "
            "temple and brow, longer dark coat with crimson lining")

    # 4) promotions
    for name, src, edit in PROMOTIONS:
        new[name] = queue_state(name, ids[src], edit)

    # 5) weapon retry + mounted perrin
    wname, wsrc, wedit = WEAPON_RETRY
    new[wname] = queue_state(wname, ids[wsrc], wedit)
    while True:
        text, _ = call("create_character", {
            "description": "golden blond young knight heir in dark navy and "
                           "crimson uniform with gold epaulettes riding an "
                           "armored warhorse with crimson caparison, lance in "
                           "hand, GBA Fire Emblem cavalier style, strong "
                           "readable silhouette",
            "name": "perrin_mounted", "body_type": "quadruped",
            "template": "horse", "mode": "v3", "size": 48,
            "outline": "single color black outline", "detail": "medium detail"})
        if not text.startswith("error"):
            m = re.search(r"id: (\S+)", text)
            new["perrin_mounted"] = m.group(1)
            print(f"mounted queued -> {m.group(1)}", flush=True)
            break
        time.sleep(45)

    # 6) wait all new characters
    for name, cid in new.items():
        wait_completed(cid, name)

    # 7) walk for kai_evolved only (sells the mark in motion)
    queue_walk(new["kai_evolved"], "kai_evolved")

    # 8) wait for all pending jobs everywhere (walk fixes + evolved walk)
    watch = {**{n: ids[n] for n in ("corin", "vesper", "alaric")},
             "kai_evolved": new["kai_evolved"]}
    while True:
        busy = [n for n, c in watch.items() if "pending jobs" in get(c)]
        if not busy:
            break
        time.sleep(25)
    print("all jobs settled", flush=True)

    # 9) downloads: re-download fixed characters + all new states
    ids.update(new)
    json.dump(ids, open(f"{SCRATCH}/cast_ids.json", "w"), indent=1)
    for n in ("corin", "vesper", "alaric"):
        download(n, ids[n])
    for name, cid in new.items():
        download(name, cid)
    print("BATCH3 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
