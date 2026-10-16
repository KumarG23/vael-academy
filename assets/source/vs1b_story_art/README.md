# VS-1B story artwork — provenance and visual review

Source package: `docs/story_packages/vs1b/` (archive SHA256
`eec8ebddd6c2cc50903f1f7f578a7b88da6b1b2ebe4cb7bac85ad73f2b42bd8e`).
Baseline `ede37ffb` already contained flow/gating but no dedicated road paintings.

**Neal's correction during review:** new portraits must match the **exact existing
cast portrait style**. The first white-background portrait batch drifted and is
superseded. Painted story environments may remain if characters are recognizable.
Final candidates use the existing square portrait format/background, direct
clothing-only edits of approved Kai, and original Kai/Serra/Rina style references
for the supporting cast. They are visual-review candidates, not final new canon.

## Reuse before generation

Inspected all seven existing painted VN environments and original Kai/unmarked
Kai/Perrin/Serra/Rina portraits. Reused forest, cave, waking cottage, night kitchen,
goodbye and original heirs. The morning still relights the SAME night kitchen.
No existing Tam/Essa/Hesta/commoner Kai/child/warden portraits or road stills existed.
Original cast files are never overwritten. New IDs are scoped to opening JSON.

## Selected masters

| Runtime art | Source |
|---|---|
| Kitchen morning (one still throughout banter) | `kitchen_morning_v1.png` |
| Hesta handoff | `waystation_v2.png` |
| Approaching smoke | `approach_v1.png` |
| Well/cart raid | `raid_environment_v2.png` |
| Kai diverts the axe brigand | `kai_rush_v3.png` |
| Four strangers; Perrin mounted | `strangers_v3.png` |
| Recovering square | `aftermath_v3.png` |
| Bread/child/mother | `bread_v3.png` |
| Pre-cave commoner Kai | `kai_portrait_style_nomark_v1.png` |
| Marked commoner Kai | `kai_portrait_style_marked_v1.png` |
| Five commoner expressions | `kai_expression_{happy,determined,angry,sad,surprised}_style_v3.png` |
| Tam/Essa/Hesta/child/warden | `{id}_portrait_style_v2.png` |

Kai's anatomical LEFT mark remains on viewer-right brow in frontal portraits;
it is absent before the cave. Commoner costume is oatmeal linen/brown vest.
The second style-emotion pass was superseded because editing old expression
references preserved their obsolete centered mark. Final expressions derive
from the corrected commoner base. No controlled spell or magic projectile is
shown on the road. Painterly characters are illustrative staging; pixel world,
map actors and approved illustrated combat are unchanged.

## Iteration record

All masters and receipts remain, including rejected work. Major rejects:
large crown; upright cart; warden mistaken for a second Hesta; casually drawn
sword at waystation; Perrin off horse; duplicated Kai/horse/cart; Rina doing the
wrong task; duplicate Rina; baked-in fake dialogue UI; bread too low/large;
flat white cutout portrait style rejected by Neal. The selected recovering
square shows ordinary villagers working; named teens' narrated actions can
happen off frame. No misleading duplicate figures remain in selected paintings.

Native review exposed white matte pockets and competing full-size duplicate
portraits at the bread shot. Final square portraits avoid matte extraction;
bread alone uses small framed insets, preserving faces, text and central offer.
`bread-standard-before.png` is explicitly rejected historical comparison; use
final `aftermath-11.png` and the playback for current presentation.

## Reproduction and accounting

`tools/gemini_opening_art.py` uses the established `gemini_emotions.generate_image`
with configured `VAEL_ART_API_KEY`, model **gemini-3.1-flash-image**, 2K requests.
No credentials are stored in prompts/receipts. `jobs.json` preserves exact prompts
and reference paths; individual receipts include hashes, elapsed time and status.
`selections.json` and `installed.json` identify final paths and output hashes.
`tools/install_opening_art.py` installs reviewed PNGs without creative synthesis.
Final portraits retain square opaque cast framing; old matte code only reproduces
superseded cutout candidates. Godot imports final art; source folder is ignored.

**45 Gemini requests: 44 delivered images, one connection-close failure.**
The existing helper does not return dollar billing; no invented dollar total.
No PixelLab portrait/roster rollout, music purchase or generated VO. The separately
authorized single PixelLab map fire cost **8 subscription generations**; see
`../pixellab/vs1b_fire/` and `VS1B_VFX_PILOT.md`.

Review evidence, in-engine screenshots, playback and tests:
`assets/art_review/vs1b_package/README.md`. The art/prose are ready for Neal's taste
review; technical checks do not constitute aesthetic approval.
