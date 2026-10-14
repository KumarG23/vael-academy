#!/usr/bin/env python3
"""CP-2: bounded, resumable Gemini art specimens for the illustrated pilot.

uv run --with pillow tools/gemini_pilot_art.py [kai|serra|courtyard ...]
Existing outputs are preserved; failed requests are not automatically retried.
"""
import hashlib
import json
from pathlib import Path
import sys
import time
from gemini_emotions import generate_image, MODEL
from gemini_pipeline_check import read_key, ROOT

OUT = ROOT / "assets/source/illustrated_pilot"
SHEET = """Create a high resolution, clean linework, cel-shaded anime GAME ANIMATION SPRITE SHEET. Exactly 9 FULL BODY figures on a mathematically regular 3 columns x 3 rows equal-cell grid. Each figure stays WITHIN its cell, including all weapons and clothing. Give each cell generous margin on all four sides. ALL FIGURES same height, face, outfit, body proportions, camera and scale. No text, no labels, no grid lines, no decorative frames. Pure flat white background, no shadows or scenery, easy to extract. Human proportions, not chibi, not pixel art. Three-quarter view looking to RIGHT; modestly elevated camera. Fixed relative head height and foot baseline across each cell. Reading order: row1 IDLE ready with weapon lowered, ATTACK extending weapon toward right, HIT bracing with guard up and shoulders back; row2 WALK left leg forward contact, WALK passing left leg planted right knee forward and lifted, WALK right leg forward contact; row3 WALK passing right leg planted left knee forward and lifted, CAST with free palm extended right (weapon lowered), DEFEAT kneeling head lowered. Alternate anatomical left and right legs genuinely in those FOUR walk phases. Character faces right in all standing poses. No motion trails, no baked particles or glows extending into adjacent cells. Every cell shows complete boots and head. The action poses must remain clearly different but the body size identical."""
JOBS = {
    "kai_head_west": {
        "prompt": "Draw ONE isolated head-and-neck game sprite of Kai looking to the LEFT in three-quarter view. Reference1 is his current in-game full-body drawing: MATCH its clean linework, exact face, hairstyle, skin, eye color and restrained cel shading. Reference2 is his canon identity portrait and explicitly shows the correct green Crown-mark over his anatomical LEFT brow: above the eye on the VIEWER RIGHT in this LEFT-facing view. The mark must be above his left brow on the near visible forehead plane, NOT above the viewer-left eyebrow, NOT centered. It is a small distinct green crown, not a tattoo over both eyes. Brown-skinned teenage boy, amber eyes, green-streaked black hair, serious calm face. Turn head LEFT so nose points viewer LEFT, show near ear on VIEWER RIGHT. Preserve age and face from reference1, not portrait's more glossy rendering. COMPLETE head including hair top and sides and a short neck ending just above white uniform collar; no shoulders, no torso, no clothing below neck. One head only, no copies or sheet. Generous margins, plain pure WHITE background, no text, no shadow, no symbols beyond his brow mark. Output a clean sprite cutout for mounting on the existing character body.",
        "refs": ["assets/art/illustrated_pilot/kai/idle.png", "assets/portraits/portrait_kai.png"],
        "aspect": "1:1",
    },
    "kai_walk_opposite": {
        "prompt": "Edit this exact 2x2 animation sprite sheet, preserving the character identity, head position, camera, clothes, sword and scale in all four cells. The top two frames are correct and must stay unchanged. The bottom two frames INCORRECTLY repeat the same leading leg as the top two. REDRAW ONLY THE LEGS BELOW THE BELT in the BOTTOM TWO CELLS to the OPPOSITE phase. In BOTTOM LEFT, the boot connected to the hip on the VIEWER LEFT must stride across in front toward the RIGHT and land heel-first at the forwardmost position, while the boot connected to the hip on the VIEWER RIGHT trails toward the LEFT with raised heel. The diagonal pant-leg crossing and occlusion must switch relative to top left. In BOTTOM RIGHT, the VIEWER-LEFT hip/leg supports the weight with a straight planted boot, and the VIEWER-RIGHT hip/leg bends slightly and passes forward, its toe just above the floor. This is relaxed low-knee walking, no marching. The visible leg occlusion must SWITCH between top-row and bottom-row half-cycles. Keep complete boots, upright torso and same foot baseline; simple anatomically correct gait. Remove all black grid divider lines, output on pure white with no text. Four full-body frames in the same equal 2x2 cell positions.",
        "refs": ["assets/source/illustrated_pilot/kai_walk_gemini_sheet.png"],
        "aspect": "1:1",
    },
    "kai_walk": {
        "prompt": "Create exactly FOUR animation frames of this exact Kai character in a regular 2 columns by 2 rows square sprite sheet, each equal-size cell. Reference 1 is his approved full-body look and outfit. Reference 2 is his face. Preserve his full body proportions, face, brown skin, amber eyes, green-black hair, small green brow crown, navy/gold dress uniform, red cravat and crimson cape, black boots and slender lowered green-edged sword. Camera stays three-quarter facing RIGHT, fixed scale, head/shoulder height and planted foot baseline. This is a relaxed ordinary WALK, NOT a march, jog, skip or high-knee exercise. Knees remain low; the swinging boot passes barely above the paving, never lifted to the waist. Keep torso upright and steady. FRAME1 top-left: anatomical LEFT leg strides forward and plants its HEEL on ground, right foot trails behind with heel raised. FRAME2 top-right: weight shifts onto the planted LEFT leg, RIGHT foot passes underneath the hips with bent knee and toe barely off the ground. FRAME3 bottom-left: anatomical RIGHT leg now strides forward and plants its HEEL on ground, LEFT foot trails back. This must be a distinct OPPOSITE-LEG contact pose, NOT a copy of frame1. FRAME4 bottom-right: weight on planted RIGHT leg, LEFT foot passes underneath the hips, toe barely above ground. Distinct OPPOSITE-LEG passing pose, NOT a copy of frame2. Subtle alternating arm/cape counter-motion, relaxed shoulders, sword safely lowered. Each cell complete head and boots, plentiful margins, no overlapping characters, no grid lines, no text, no captions, no labels, no motion trails, no shadows. Plain pure WHITE background for matting. Clean consistent cel-shaded illustration, no pixel art, no chibi. Anatomically coherent alternating gait that can loop 1-2-3-4.",
        "refs": ["assets/art/illustrated_pilot/kai/idle.png", "assets/portraits/portrait_kai.png"],
        "aspect": "1:1",
    },
    "kai_clean": {
        "prompt": "Edit this exact 3x3 character sprite sheet. REMOVE ALL TEXT, captions, annotations and every black vertical/horizontal grid divider. Replace those markings with pure white background. Preserve all nine character illustrations, their faces, clothes, poses, scale, position and anatomy exactly. All backgrounds plain white. Remove the grid line crossing behind the extended sword. No new labels, no lines, no frames, no typography anywhere. Complete character artwork including sword tip must be kept, not erased. Output the cleaned sprite sheet only.",
        "refs": ["assets/source/illustrated_pilot/kai_gemini_sheet.png"],
        "aspect": "1:1",
    },
    "courtyard_clean": {
        "prompt": "Edit this exact painted academy courtyard. Keep all architecture, composition, light, foliage, fountain, perspective and paving completely unchanged. ONLY change the heraldic designs on the hanging fabric banners: the crimson banner on left should have a GOLD FIREBIRD with spread feathered wings, not a lion; the two blue banners in center should have a SILVER LEVIATHAN sea serpent, not owls; keep the bronze stag on green banner at right. Simple elegant fantasy heraldry, no text or Christian symbols. Preserve painterly style. Output the complete environment.",
        "refs": ["assets/source/illustrated_pilot/courtyard_gemini.png"],
        "aspect": "16:9",
    },
    "kai": {
        "prompt": SHEET + " Reference 1 is Kai's definitive FACE and UNIFORM. Reference 2 is a useful POSE-layout reference only; correct its cramped cell spacing. Kai is a teen boy with brown skin, amber eyes, green-streaked black hair, tiny green crown mark on left brow, navy dress uniform with gold epaulettes and trim, red cravat, short crimson cape, navy trousers and black boots. His sword is slender steel with a restrained green edge, not a lightsaber. In CAST, extend an EMPTY hand; effects will be added in engine. Preserve identifying marks, age and clothing in every frame.",
        "refs": ["assets/portraits/portrait_kai.png", "assets/source/illustrated_pilot/kai_imagegen_sheet.png"],
        "aspect": "1:1",
    },
    "serra": {
        "prompt": SHEET + " Reference 1 is Serra's definitive identity: teenage girl, pale skin, long blonde twin tails, cool blue eyes, silver circlet with blue gems, navy-and-silver academy uniform, white cravat and restrained silver armor. Extend to matching fitted navy trousers, silver-trimmed armored boots and elegant light silver gauntlets. She uses a slim silver LANCE, keep its full point inside every cell; hold it upright in idle and walking, thrust right in attack, guard across torso in hit. Her CAST is a calm defensive blessing gesture, not a fire spell. Reference 2 is another character's sprite sheet for MATCHING ART STYLE, proportions and grid only; do not copy its male face, green hair, red cape, sword or skin color. Serra remains exactly the girl in reference 1. Disciplined poised expression.",
        "refs": ["assets/portraits/portrait_serra.png", "assets/source/illustrated_pilot/kai_gemini_sheet.png"],
        "aspect": "1:1",
    },
    "courtyard": {
        "prompt": "Paint a sumptuous fantasy academy courtyard for a 2D illustrated tactics RPG. Reference image establishes warm painterly storybook atmosphere ONLY, not the forest location. Wide 16:9 scene, warm late afternoon sunlight, ancient cream stone Gothic cloisters, tall arched windows with blue and amber stained glass, ivy and climbing roses, a modest reflecting fountain BACK by the cloister, bronze lanterns and crimson/gold, deep-blue/silver and forest-green/bronze banners representing three equal houses. Feeling of a beloved inhabited school, quiet and luminous. Clean composition, restrained brush texture, harmonious softly painted background complementary to cel-shaded anime characters. Camera moderately elevated, shallow three-quarter view. Lower HALF of image is a spacious OPEN cobblestone terrace where two characters can walk and spar; readable low-detail neutral paving, no furniture or plants blocking the walk area. Architectural detail concentrated in upper half and far sides. No people, no creatures, no text, no logos, no UI, no pixel art, no Christian crosses, no excessive filigree. Full finished environment, not a mockup.",
        "refs": ["assets/art/vn/painted/forest_path.png"],
        "aspect": "16:9",
    },
}


def main() -> int:
    key = read_key(ROOT / ".env")
    if not key:
        print("VAEL_ART_API_KEY missing; no generation requests sent.")
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or ["kai", "serra", "courtyard"]
    for name in names:
        job = JOBS[name]
        output = OUT / (name + "_gemini_sheet.png" if name != "courtyard" else "courtyard_gemini.png")
        if output.exists():
            print(name, "already generated; preserving", flush=True)
            continue
        refs = [(ROOT / ref).read_bytes() for ref in job["refs"]]
        print("Generating", name, "via", MODEL, flush=True)
        started = time.monotonic()
        raw = generate_image(key, job["prompt"], refs, job["aspect"], "2K")
        output.write_bytes(raw)
        record = {"model": MODEL, "prompt": job["prompt"], "references": [{"path": path, "sha256": hashlib.sha256(raw_ref).hexdigest()} for path, raw_ref in zip(job["refs"], refs)], "elapsed_seconds": round(time.monotonic()-started, 2), "output": output.name}
        output.with_suffix(".json").write_text(json.dumps(record, indent=2) + "\n")
        print("Saved", output.name, "in", record["elapsed_seconds"], "seconds", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
