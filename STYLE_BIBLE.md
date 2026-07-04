# STYLE_BIBLE.md — AW-1 v6.1 (sprite tier: GBA-FE register locked in practice)

> **v6.1 (2026-07-04, AW-7 v2): THE TWO-TIER TEMPLATE EXISTS.** Kai has both
> tiers at GBA-FE fidelity (`assets/art_review/aw8_kai_v2/`). What v2 proved,
> keep for AW-8:
> - **Pipeline:** coordinate-paint Python (`assets/sprites/sources/generators/`)
>   — a `Canvas` char-grid painted with rect/line/px/row-patch calls, rendered
>   to PNG via a palette dict, iterated against 8×/16× zooms and side-by-side
>   sample comparisons. Hand-counted full rows stay banned; small explicit
>   row-patches (a head, a fist+hilt) are fine and are where the quality lives.
>   `.aseprite` files are exports, not sources.
> - **Battle tier (48×64) rules that made it read as GBA-FE:** ¾ posed figure
>   (sword-over-shoulder; never symmetric standing), cape flared into a triangle
>   with irregular fold streaks + zigzag hem, 3–4 shade ramps per material with
>   tinted near-black outline (#160d12), gold accents (placket, buttons, buckle,
>   boot-cuff tips), 1–2 px specular glints on the blade, face = fringe locks at
>   varying depths + 1×2 dark pupil + 1 px white glint + nose as silhouette
>   step. Kai's temple mark: 2 px silver diagonal on skin at the hairline.
> - **Map tier (32×32, faces right, engine flips):** chibi ≈ 26 px tall, head
>   ≈ 11 px, simple bold shapes — NO white eye glint at this scale (googly),
>   1×2 chunky pupils; crimson mini-cape off the shoulders reads as "lord" at
>   map zoom; 4-frame walk = contact A / passing / contact B (far leg forward,
>   drawn darker) / passing, passing poses ride 1 px lower and double as the
>   idle-bob pair (f2/f4); cape hem sways 1 px between passing frames.
> - **Palette:** shared ramp dict in `kai_battle.py` (skin/hair/jacket/cape/
>   gold/leather/steel/trousers + mark) — reuse it as the base cast palette;
>   house palettes swap the cape/jacket/gold ramps only.
> - **In-engine driving for validation:** MCP key events don't reach polled
>   input — use `Input.action_press/release` taps and `InputEventAction` for
>   confirm/cancel via `execute_game_script`; capture walk GIFs with an
>   injected per-frame `save_png` node, never `capture_frames` (misses the
>   window to MCP latency).

> **v6 (2026-07-04, overnight AW-7 bake-off): SPRITE TIER SPEC — first real data.**
> Neal reviewed the first pixel output mid-session: "already a thousand percent
> better… but needs more detail and flare, needs more uniqueness." He replaced
> `sample/` with GBA-FE-fidelity references (Marth GBA-style, Three Houses
> fan-sprites, a Reddit artist's multi-year FE sprite set). **Reference only — do
> not copy; use as the bar for detail/flare.** What the samples establish:
> - **Two-tier sprite architecture** (exactly GBA FE): a small readable **map
>   sprite** (chibi, big head, ~32px) and a detailed **battle/showcase sprite**
>   (~48×64, realistic proportions, cape/cloth motion, 3–5 shade ramps per
>   material, strong silhouette). AW-8 must produce both per class.
> - **Flare checklist** for the battle tier: cape or cloth element, material
>   ramps (not flat fills), 1–2 specular glints (weapon edge, temple mark),
>   asymmetric details (sash, shoulder plate), readable face with eye whites.
> - **Palette:** endesga-32 (Lospec) worked; stay palette-locked per sprite,
>   ~16–21 colors on the battle tier, fewer on the map tier.
> - **Pipeline that actually worked tonight:** Aseprite MCP `execute_script` Lua
>   with **programmatically built** pixel grids (python char-matrix → putPixel
>   loops — hand-counted rows are banned; they mis-align). R16 ComfyUI sprite
>   diffusion remains untested for sprites; hand-pixel + palette-swap is the
>   proven path so far.
> - **Engine consumption (live):** `Unit` builds `SpriteFrames` from
>   `assets/sprites/units/<id>/walk_f1-4.png` at runtime — walk 8fps, idle 2fps
>   (frames 2/4), `TEXTURE_FILTER_NEAREST`, scale = cell/32, flip_h from travel
>   direction. Supersedes the standee hook on the map.
> Bake-off deliverables for the style pick live in `assets/art_review/aw7_bakeoff/`.

> **v5 (2026-07-04): THE TIER SPLIT.** Neal's verdict after the in-engine test:
> painted portraits in dialogue work ("looks good"); static standees on the map do
> NOT ("doesn't work for me at all") — anything that MOVES needs real animation.
> Research confirmed the genre answer: Dark Deity itself ships **pixel/sprite map
> and battle animations under its painted busts**. The bible therefore governs
> three tiers:
> 1. **Painted tier (this document, AW-1):** dialogue busts, splashes, map
>    backdrops, rooms, vistas — approved register stands (Corin-704, vivid
>    environments).
> 2. **Sprite tier (spec finalized by AW-7 pilot):** battle units + campus
>    avatars/NPCs — chunky stylized sprites ~48–64px, idle/walk×4-dir/attack/hit/KO
>    cycles, class-based sheets + house palettes. Generated locally (R16 ComfyUI
>    sprite workflows + pixel-art LoRA, palette-locked), cleaned in LibreSprite/
>    Piskel (free), consumed by Godot `AnimatedSprite2D`. Low resolution is the
>    feature: it hides AI frame drift and keeps animation tractable.
> 3. **Juice tier (code, WO-2.5):** unchanged.
> The static-standee template (§ below) is RETIRED for map use; the engine's
> standee hook remains as a dev fallback only. Portrait/splash/environment
> templates are unaffected.

> **v4 (2026-07-04): validated IN THE ENGINE.** After static composite mocks failed
> review, the AW-6 texture hooks were landed early as AW-1 validation: `Unit` draws
> `assets/standees/standee_<id>.png` (house ring + HP bar + all tweens unchanged)
> and `DialogueScene` draws `assets/portraits/portrait_<id>.png` per side — both
> convention-based, zero effect when no art exists, all 268 tests green. Kai is the
> live proof (engine screenshots in `assets/art_review/aw1_style_bible/engine_*`).
> Background stripping is **rembg with alpha matting** (isnet-general-use) — the
> hand-rolled flood-fill keyer failed exactly as expected and is banned.
> **Castle movement answer (M6):** standees glide with a subtle bob (Banner Saga),
> matching the no-frame-animation art language; Godot's built-in Skeleton2D cutout
> rig is the free upgrade path if jointed walk cycles are ever wanted. No paid
> software anywhere in the pipeline.

> **v3 (2026-07-04):** Neal picked Pole A with Corin seed 704 as the reference ("95%
> perfect"), asked for the cast to be **normalized to her register** plus a **+5%
> charm dial** on the heroines, and confirmed the **vivid environment pole** via the
> feast hall. v3 delivers the normalized template (seeds 901/902/904/905 — which
> also serve as the fresh-seed reproduction check) and extends vivid rooms (library
> 906). **Charm rule:** "+5%" is implemented as expression/eyes/grace/stylish fit —
> FE-official-art level, hard-capped there (cast is 15–18; never past genre level).

The authoritative look for every production asset (MASTER_PLAN §8). **Consistency law:
no production asset is generated except from these templates and params.** Exemplars
live in `assets/art_review/aw1_style_bible/` (filenames carry their seeds).

> **v2 (2026-07-04), after Neal's review of v1:** v1's oil-painting realism read as
> "real people," not game characters. v2 pivots characters to **stylized,
> anime-influenced game art (Dark Deity register)** per Neal's six reference images
> in `sample/`. Sample 5 (outlined cel archer) is the strongest character target;
> samples 1–2 set the vivid storybook register for environments. Characters should
> be attractive, stylized, *drawn* — never photoreal. v1's painterly-oil exemplars
> remain in the folder as the rejected-for-characters / candidate-for-environments
> record.

## 1. The look, in one paragraph (v2)

**Stylized 2D game art.** Characters: anime-influenced faces (large expressive eyes,
clean features), bold clean linework with cel-to-soft painted shading, vivid
saturated color, attractive genre-standard designs — Fire Emblem / Dark Deity
official-art energy. Environments: hand-painted stylized game backdrops — clean
bold shapes, saturated storybook color (Runefall-vista energy), painterly but never
photoreal. Nothing in the game should look like a photograph or a real person.

## 2. Battle presentation spec (locked — art is made to this)

The engine draws a flat grid with upright unit chips (no perspective transform), so:
- **Map backdrops** are painted at a **high oblique angle (~55–60°)** — steep enough
  to read as a board, shallow enough to keep landmark silhouettes.
- **Standees** are drawn **upright, full-body, ¾ view**, composited onto the map as
  billboards with a house-color base ring (pipeline adds the ring).
- Portraits/busts face the camera (VN framing); splashes are wide cut-ins.

## 3. Palettes

**Master:** vivid saturated color over warm darks (never pure black; deep warm
umbers `#1a1417`–`#2b2026`). Environments: saturated storybook greens/earths.

| House | Primary | Secondary | Light note |
|---|---|---|---|
| Emberwing | crimson `#C72929` | gold `#EDC24A` | warm light, ember glow |
| Tidemark | deep blue `#294F9E` | silver `#BFCCDB` | cool light, storm grey |
| Thornrook | forest green `#2E6B3D` | bronze `#B88C4D` | dappled woodland light |

(Values match `data/houses/*.tres`; art accents sample these, not invent.)

## 4. Models & fixed parameters

- **Box:** R16 ComfyUI (`http://100.70.146.106:8188`, Tailnet only)
- **Pole A (recommended) — DreamShaperXL_Turbo_v2_1.safetensors:** euler /
  sgm_uniform / **steps 6 / cfg 2.0** / denoise 1.0 (~2s per render)
- **Pole B — animagine-xl-3.1.safetensors** (installed 2026-07-04 via Manager API):
  euler_ancestral / **steps 28 / cfg 6** / quality tags `masterpiece, best quality,
  very aesthetic` + danbooru-style `1girl/1boy` phrasing (~15s per render)
- **Resolutions:** portrait 1024×1024 · standee 832×1216 · backdrop / room / splash
  / vista 1344×768 (upscale passes are AW-2/AW-3 work)
- **Base negative (always):** `photo, photorealistic, realistic face, real person,
  3d render, cgi, oil painting, impasto, text, watermark, signature, logo, frame,
  border, blurry, lowres, deformed, extra fingers, mutated hands`

## 5. Prompt templates (v2)

**CHARACTER PORTRAIT — THE template (v3 normalized; exemplars 901/902/904, origin 704)**
> 2D game character art, clean bright anime cel shading with fine ink outlines,
> large expressive eyes, tactical RPG portrait, waist-up bust,
> [beautiful/handsome] [age] year old [description], [elegant] [house primary] and
> [house secondary] academy uniform [detail], [charming expression], vivid flat
> saturated colors, simple flat dark [house-tinted] background, stylized official
> game art[, charming and graceful — heroines only, the +5% dial]
>
> extra negative: `painterly, heavy shading, muted colors` (+ `armor, pauldrons`
> for non-armored characters; + `antlers, horns, forest, trees` for Corin/Thornrook)

**CHARACTER PORTRAIT — POLE B "full anime" (Animagine; exemplars 801/802)**
> masterpiece, best quality, very aesthetic, [1girl/1boy], waist-up portrait,
> [description], [house colors] fantasy academy uniform, tactical rpg official
> character art, painterly anime style, plain dark background
>
> negative: `lowres, bad anatomy, bad hands, worst quality, low quality,
> photorealistic, 3d, watermark, signature, text`

**STANDEE (Pole A; exemplar 705)**
> 2D game character art, flat cel shading with bold clean ink outlines, anime
> influenced full-body tactical RPG unit art, [description] standing [simple pose]
> holding a single [weapon], full figure head to feet, vivid saturated colors,
> simple flat pale grey background, stylized official game art, strong readable
> silhouette
>
> extra negative: `figurine, statue, pedestal, display base, round base, multiple
> weapons, two swords`

**CLASH SPLASH (Pole A; exemplar 707)**
> 2D game art, flat cel shading with bold clean ink outlines, dynamic anime attack
> cut-in, [character] [attack action] toward the viewer, [house energy] wreathing
> the [weapon], radial speed lines, dramatic foreshortening, vivid saturated colors,
> dark smoky background, stylized official tactical RPG splash art

**MAP BACKDROP — vivid stylized (recommended to match cel characters; exemplar 708)**
> vibrant stylized fantasy battlefield seen from high above at a steep angle,
> hand-painted game art, clean bold shapes, saturated storybook colors, [landmarks],
> lush painterly rendering, no people, high quality game environment art
>
> extra negative: `photograph, aerial photo, satellite, drone, tabletop map, grid,
> car, truck, vehicle, modern`
>
> *(v1's "impressionist oil" backdrop — exemplars 304/306/308 — stays a candidate
> if Neal prefers muted maps under cel characters.)*

**CASTLE ROOM — vivid stylized (exemplar 709; v1 painterly 401/402/403 also candidates)**
> vibrant stylized fantasy castle interior, [room description], [light], hand-painted
> game art, clean bold shapes, saturated storybook colors, [mood], no people, high
> quality game environment art

**VISTA / TITLE (v1 exemplars 305/601 remain the reference)**
> gouache painting, [scene], soft brush texture, storybook art, [palette note],
> [time of day], no people
>
> *Vael itself must read fortified war college on old Warder stone — heavy square
> keep, three banners — not the fairy-tale palace of exemplar 601.*

## 6. Known model behaviors (v1 + v2 — don't relearn these)

1. **DreamShaper drifts photo/semi-real on faces** — the full cel keyword stack
   ("2D game character art, flat cel shading, bold clean ink outlines, anime
   influenced") is what unlocks the style; softer phrasings collapse back to
   realism, worst on female faces (v2 seeds 701/702).
2. **Landscapes drift photoreal** without a named medium ("hand-painted game art",
   "impressionist oil", "gouache"); "matte painting" alone is not enough.
3. **"Standee" is a trap word** — figurine on a pedestal (seed 201). "Wagon" is a
   period trap — produced a 1950s pickup (seed 307). Oil landscapes grow **fake
   painter signatures** (seed 601) — QC corners.
4. **"Map" pulls toward VTT clip-art** (seed 302). Describe a landscape from above.
5. **Ages skew up** on DreamShaper ("young soldier" reads 25+; say "16 year old
   academy student") and **down** on Animagine (everyone reads younger).
6. **Ornament nouns get literal**: "antler ornament" grew antlers from Corin's head
   (seeds 701/702/704-adjacent) — use "small golden stag brooch on her collar" and
   negative `antlers, horns`.
7. **Animagine is weak at full-body standees** (seed 803: faceless) — use Pole A for
   standees regardless of the portrait pole.
7b. **Green palettes pull forest backgrounds** (Corin 901, archer standee 905) even
   with `forest, trees` in the negative — production portraits/standees must be
   QC'd for background drift and regenerated until the flat background holds.
7c. **Small identity details don't render from text** (Kai's silver temple mark,
   exact braids) — that's AW-4's job: locked reference sheets + inpainting, not
   prompt-wrestling.
8. **ComfyUI model-switching bug (v0.26.0):** swapping checkpoints can crash
   `CheckpointLoaderSimple` with `IndexError ... free_memory` — POST `/free`
   `{"unload_models": true, "free_memory": true}`, wait ~5s, retry. Freshly
   downloaded checkpoints also need ~20s to settle before first load.

## 7. Exemplar index (`assets/art_review/aw1_style_bible/`)

**v2 (current direction):**
| Template | Exemplars |
|---|---|
| Portrait, Pole A (rec) | kai 703 · corin 704 · serra 706 |
| Portrait, Pole B | corin 801 · kai 802 |
| Standee (Pole A) | soldier 705 |
| Splash (Pole A) | sword 707 |
| Backdrop, vivid | field 708 |
| Room, vivid | feast hall 709 |

**v1 (painterly-oil record; environments still candidates):** portraits 101–107,
standees 202–205, oil backdrops 304/306/308, rooms 401–403, splashes 501–503,
vistas 305/601.

## 7b. From concepts to game assets (the production path)

In-game composite mocks live in `assets/art_review/aw1_style_bible/`
(`mock_dialogue_ingame.jpg`, `mock_battle_ingame.jpg`). The engine hooks already
exist — programmer art was built first precisely so these are art-only swaps:

| Asset | Pipeline | Engine hook (already built) |
|---|---|---|
| Portraits | template render → QC vs 704 → rembg alpha → crop → `portrait_<unit>_<expression>.png`; expressions via img2img/inpaint off the locked base (AW-4) | `DialogueScene` carries a `portrait` id per line since WO-3.1; swap placeholder card → texture (AW-6) |
| Standees | render 832×1216 → rembg → downscale ~96–128px | `Unit._draw` token → standee texture; house ring + tweens stay code (AW-6) |
| Map backdrops | terrain blockout → img2img/ControlNet so landmarks land on cells → upscale ≥2560×1920 → touch-up (AW-2) | `ChapterDef.backdrop` exists since WO-0.2; battle already draws it |
| Rooms / vistas / splashes | straight renders at spec → retouch | castle scenes (M6) / title (4.3) / `ClashSplash` texture swap |
| Consistency | locked reference sheet per character; expressions inpainted, never regenerated fresh; optional character/style LoRA + IPAdapter when the cast scales | AW-4 |

## 8. Sign-off state

- ~~Character pole~~ **DECIDED: Pole A, Corin-704 register, +5% charm.**
  v3 normalized the cast (902 Serra and 904 Kai approved; 901 Corin REJECTED —
  "riding the edge of anime-ish and realistic"). **Corin 704 is the canonical
  face reference.** QC rule: every face must read *fully drawn*; anything sliding
  semi-real is rerolled, no exceptions (901 is the kept out-of-range example).
- ~~Environment pole~~ **DECIDED (v2 review): vivid stylized** (feast hall 709
  anchor; library 906; backdrop 708).
- Vista treatment (v1 gouache) — unchallenged; stands.
- **Remaining: Neal's yes/no on v3.** On yes → AW-1 ✅ and AW-2/3/4/5 unblock
  (AW-4 first: locked reference sheets for the real cast).
