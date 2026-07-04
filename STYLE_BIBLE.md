# STYLE_BIBLE.md — AW-1 (draft, awaiting Neal's sign-off)

The authoritative look for every production asset (MASTER_PLAN §8). **Consistency law:
no production asset is generated except from these templates and params.** Exemplars
live in `assets/art_review/aw1_style_bible/` (filenames carry their seeds); every
exemplar reproduces from the recorded seed + template on the R16.

## 1. The look, in one paragraph

**Full painted 2D. No pixel art, no anime cel, no photo-real.** Dark Deity's painted
busts (rich saturated color, dramatic side light, visible brushwork) × The Banner
Saga's painted landscapes (thick impasto oil, muted naturalistic palette, high-angle
dioramas) × Darkest Dungeon's splash drama (chiaroscuro, radial energy, spectacle
from a single still). Everything should look like it was painted by one studio hand:
oil/gouache texture always visible, edges confident, light warm and directional.

## 2. Palettes

**Master:** warm darks (never pure black — use deep warm browns/umbers `#1a1417`–`#2b2026`),
candle-warm highlights, muted naturalistic greens/earths for landscapes.

| House | Primary | Secondary | Light note |
|---|---|---|---|
| Emberwing | crimson `#C72929` | gold `#EDC24A` | warm side light, ember glow |
| Tidemark | deep blue `#294F9E` | silver `#BFCCDB` | cool side light, storm grey |
| Thornrook | forest green `#2E6B3D` | bronze `#B88C4D` | dappled woodland light |

(Values match `data/houses/*.tres`; art accents should sample these, not invent.)

## 3. Fixed generation parameters (all templates)

- **Box:** R16 ComfyUI (`http://100.70.146.106:8188`, Tailnet only)
- **Checkpoint:** `DreamShaperXL_Turbo_v2_1.safetensors`
- **Sampler:** `euler` · scheduler `sgm_uniform` · **steps 6 · cfg 2.0 · denoise 1.0**
- **Resolutions:** portrait 1024×1024 · standee 832×1216 · map backdrop / room /
  splash / vista 1344×768 (upscale passes are AW-2/AW-3 work)
- **Base negative (always):** `photo, photorealistic, 3d render, cgi, anime, cel
  shading, pixel art, text, watermark, signature, logo, frame, border, blurry,
  lowres, deformed, extra fingers, mutated hands`
- Driver reference: the WO-AW-1 session used a 40-line stdlib script
  (`POST /prompt` → poll `/history` → `GET /view`); AW-3 productionizes it.

## 4. Prompt templates

Substitute `[...]`; keep every fixed phrase — they carry the style.

**PORTRAIT** (dialogue bust; expressions: neutral/happy/angry/hurt)
> painted fantasy character portrait, waist-up bust, [age] year old [description],
> [house primary] and [house secondary] academy uniform, [expression], **plain dark
> background**, dramatic [warm/cool] side lighting, expressive visible oil-paint
> brushwork, rich saturated color, strong clean silhouette, painted illustration

**STANDEE** (map figure; rembg-friendly)
> painted full-body fantasy character illustration, [description] standing [simple
> pose] holding [weapon], [house colors] academy uniform, full figure head to feet,
> **plain flat light grey studio background**, bold visible oil-paint brushwork,
> strong clean silhouette, rich saturated color, stylized painted game art
>
> extra negative: `figurine, statue, pedestal, display base, round base`

**MAP BACKDROP** (battlefield painting; invisible grid goes on top)
> impressionist oil painting of [battlefield description] viewed from high above at
> a steep angle, thick impasto brushstrokes, visible canvas texture, [landmarks:
> fort / forest grove / pond / road], hand-painted storybook illustration, muted
> natural palette, [light], painterly, no people
>
> extra negative: `photograph, aerial photo, satellite, drone, realistic photo,
> tabletop map, cartoon, grid, car, truck, vehicle, modern`

**CASTLE ROOM** (walkable-castle backdrops, M6)
> hand-painted castle interior, [room description], [light source], thick expressive
> oil paint brushwork, storybook matte painting, [mood], no people

**CLASH SPLASH** (crit/kill cut-in, WO-2.5 consumer)
> dynamic painted attack cut-in illustration, close up of [character] [attack action]
> toward the viewer, [house colors + energy type] trailing the [weapon], radial speed
> lines, extreme foreshortening, dramatic chiaroscuro lighting, dark [smoky/stormy]
> background, bold oil paint brushstrokes, high drama fantasy splash art

**VISTA / BACKGROUND** (title, castle exteriors, cutscene wides)
> gouache painting, [scene] , soft brush texture, storybook art, [palette note],
> [time of day], no people

## 5. Known model behaviors (learned this session — don't relearn them)

1. **Landscapes drift photo-real** unless anchored by a named medium
   ("impressionist oil painting", "gouache painting", "thick impasto") — "matte
   painting" alone is NOT enough. Failure cases: seeds 301/303 (aerial photos).
2. **"Standee" is a trap word** — produces a figurine on a display base (seed 201).
   Say "full-body painted character illustration"; keep the pedestal negatives.
3. **"Map" pulls toward VTT/tabletop clip-art** (seed 302). Describe a painted
   *landscape from above*, never a "map".
4. **Period drift:** "wagon" produced a 1950s pickup (seed 307) — say "wooden
   hand-cart", keep `car, truck, vehicle, modern` in landscape negatives.
5. **Oil paintings grow fake signatures** (seed 601 bottom-left) — negative includes
   `signature`, but **QC every landscape corner** anyway.
6. **Ages skew up**: say "16 year old academy student", not "young soldier" (seed 101
   reads mid-20s; seed 102 reads right).
7. **Backgrounds wander on portraits** (seed 104's forest) — production portraits
   must keep "plain dark background" or compositing suffers; regenerate drifted ones.
8. Uniform ornament gravitates Napoleonic (epaulettes/medals). Fine in moderation for
   a war college; prune with "fitted tunic" when it dominates.
9. Vael itself must read **fortified war college on old Warder stone** — heavy square
   keep, three banners; the seed-601 fairy-tale spires are the wrong direction (kept
   as a palette exemplar only).

## 6. Exemplar index (all in `assets/art_review/aw1_style_bible/`)

| Template | Exemplars (seed in filename) |
|---|---|
| Portrait | a_classic 101 · b_kai_archetype 102 · c_tidemark_heiress 103 · d_thornrook_scholar 104 · e_veteran_teacher 105 · f_happy_expression 106 · g_healer 107 |
| Standee | a_emberwing_soldier 202 · b_tidemark_knight 203 · c_thornrook_archer 204 · d_battle_mage 205 |
| Map backdrop | a_field_morning 304 · b_field_afternoon 306 · c_autumn_road 308 |
| Castle room | a_feast_hall 401 · b_library 402 · c_training_yard 403 |
| Clash splash | a_emberwing_sword 501 · b_tidemark_lance 502 · c_thornrook_bow 503 |
| Vista | a_gouache_valley 305 · b_castle_lake 601 |

## 7. Open items for the sign-off review (Neal)

- Approve/redirect the overall look per template (the acceptance gate for AW-1).
- Portrait brushwork range: seed 102 (chunky oil) vs 103 (smoother) — both in-range,
  or pick one pole to enforce?
- Map backdrop angle: seed 304's ~55° is the recommendation (steeper reads VTT,
  shallower reads vista) — confirm.
- Character-specific looks (real Kai, Serra, etc.) are AW-4's job via locked
  reference sheets + img2img expression variants — these exemplars are archetypes.
- LoRA/finetune consideration (AW-3): if style cohesion across hundreds of assets
  needs tightening, a style LoRA trained on approved exemplars is the lever.
