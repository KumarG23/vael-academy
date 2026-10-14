# CP-2 — Illustrated moving pilot, 2026-10-14

Open **Title → Dev Jump → Illustrated art pilot**, or run:

```sh
godot res://scenes/proto/illustrated_pilot.tscn
```

The proposed look is warm painted academy architecture with clean illustrated characters and restrained ink/gold UI. This is a moving taste test for Neal, not a production style approval or a campaign migration.

- Arrows/WASD move Kai; **6 / Walk** runs an out-and-back cycle.
- **1–5** show hit, critical, miss, Crown-light and defeat; **Space / Spar** runs an exchange through the real combat resolver.
- **F / Dialogue** shows existing Serra text with the new panel treatment; **R** resets; **Esc** returns to title.

The outcome buttons use controlled presentation specimens (critical damage follows the ×3 formula); Spar uses the actual unit/weapon stats and seeded resolver. No campaign advancement, inventory persistence or save writes occur. Kai and Serra keep their illustrations between actions; attacks, caster hands and target reactions all use the same art scale/foot geometry.

[Watch the complete pilot](pilot.mp4) · [Walk preview](walk.gif) · [Idle](01-idle.png) · [Crown-light](04-cast-impact.png) · [Dialogue](05-dialogue.png)

## Neal’s first motion review

Neal liked the attack and the overall start, and flagged the gait, diagonal whole-body anticipation and Crown-light changing hands. Illustrated anticipation now uses a backward weight shift with zero body rotation; the liked attack artwork stays intact. Casting raises the cast-pose hand before gathering, so the gather and projectile share that hand. Kai has a new low-knee walk sheet, slower travel and a consistent cycle start. The gait remains unresolved: Neal rejected the follow-up motion. An eight-frame ImageGen attempt also repeated legs; cutting articulated limbs from the flattened illustration made the result worse and was reverted. The approved attack/casting changes stay in place. A properly drawn cycle or genuinely separated limb/cape artwork is needed before claiming a natural walk. The unsuccessful Gemini correction is preserved with its prompt, but is not used in-engine. The discarded ImageGen/mesh experiments are not installed. Playback now follows actual travelled distance and walking/idle torso registration is shared; those repairs do not solve the missing gait poses. A separately drawn west-facing head replaces the reflected head on the return walk, keeping the Crown-mark above Kai’s anatomical left brow. This identity rule is recorded in CHARACTER_BIBLE_KAI.md exactly as Neal clarified it.

## Gemini pipeline result

**Working.** Neal restored the Google key under `VAEL_ART_API_KEY` in the project's gitignored `.env`. The scripts read it directly; they also accept the older `GEMINI_API_KEY` name. Nothing exports the key into the Gemini CLI OAuth environment, and credentials are never printed or committed.

The original `gemini_emotions.edit_portrait()` produced a real 1024×1024 PNG in 16.95 seconds. The shared generation function then produced two 2048² pose sheets, a 2752×1536 courtyard and two cleanup edits. Nine Gemini image requests succeeded, including two follow-up walk passes and an authored west-facing head with the mark over the left brow. The opposite-leg correction still failed; it is retained as evidence, not installed. The new runner checks authentication/models and then optionally exercises the real image-edit pipeline:

```sh
uv run --with pillow tools/gemini_pipeline_check.py --generate --output /tmp/vael_gemini_check.png
```

Choose a fresh output filename per smoke test. No retries or batches run from this command. [The saved API-check metadata](gemini-api-check.json) has no key. The established model remains `gemini-3.1-flash-image`; its image editing capability is documented by [Google](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image).

## Sources and reproduction

Final live art is from Gemini. An initial built-in ImageGen sheet served as a pose-layout reference while locating the key. Originals, intermediate edits, prompts and reference hashes are retained in `assets/source/illustrated_pilot/`; no previous game art was overwritten. The cleaned courtyard restores the three established house emblems. Only Kai's attack pose uses the grid-cleanup edit, preserving the other source figures' identity details.

```sh
# Bounded per-asset generator; preserves existing outputs.
uv run --with pillow tools/gemini_pilot_art.py kai serra courtyard
uv run --with pillow tools/gemini_pilot_art.py kai_clean courtyard_clean
uv run --with pillow tools/gemini_pilot_art.py kai_walk kai_head_west

# Neural matting and deterministic preparation, using reviewed sources.
uv run --with pillow --with rembg --with onnxruntime tools/prepare_illustrated_pilot.py
godot --headless --import
```

`kit.json` defines one scale per character, individual foot anchors, reviewed cast/action hand anchors and the walk order. Actors pivot about the feet. Walking uses head/torso alignment to avoid re-centering the body on each moving boot. Exported cutouts retain alpha; matting removes source captions and grid fragments without erasing white collars/metal. The renderer uses linear filtering.

## Verification and acceptance

- **538/538 GUT tests pass, 3,258 assertions.** Seven new tests verify outward flinch/stagger motion and restoration, damage/miss trail data, padded/crouched pose geometry, upright illustrated anticipation and casting-hand continuity, distance-paced frame playback and unmirrored west-facing head art, and live pilot walking/striking/casting/defeat without changing campaign state.
- Real keyboard actions were sent to the title menu, Dev Jump and the new scene; the entry check confirms `res://scenes/proto/illustrated_pilot.tscn`.
- Non-headless Godot rendered and recorded every demo, including resolver-driven spar and the dialogue panel. Screenshots and video are current captures.
- CP1-1–4 are repaired: reaction groups run sequentially and finish before counters, trail intensity/miss alpha reach rendering, poses share scale/anchors, and signature previews initialize their FX profile.
- The inherited suite still reports 13 GUT deprecations and two leaked objects / one resource at exit; the new targeted pilot tests finish cleanly.

## What the pilot establishes, and what needs another art pass

Gemini is suitable for the pilot's character illustrations and environments. It is **not delivering finished animation sheets on the first request**: captions appeared despite the prompt, walk phases repeat, and exact small marks/face fidelity can drift during edits. The four-frame gait is a coarse first pass; it needs authored opposite-leg phases or an articulated rig before full-cast production. Current figures use east/west three-quarter art, not a complete north/south/directional set. Mirroring also needs an asymmetry review for Kai's mark.

Neal's next review should judge the moving character proportions, gait, attack/reaction feel, environmental warmth and UI treatment. A game-wide conversion would separately need layered scenery/collision/occlusion, complete directional and equipment poses, portrait cleanup and a production art brief. The pilot intentionally makes those questions visible before generating the cast. Story/canon stays with the bibles; no new dialogue was authored.
