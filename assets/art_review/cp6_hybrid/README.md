# CP-6 — Battle-art A/B comparison and illustrated color pass

One work order, based on green **32cf058c**. The initial hybrid-combat brief
became an A/B evaluation while uncommitted; this is not a second WO.

**Neal's comparative review:** "the 2d version is definitely better than the
pixel version. just not as colorful or magical looking as the pixel art."
The final pass keeps illustrated B as the default and strengthens warmth,
Crown emerald, magical weapon light, gathering motes and hit/critical effects.
A remains runnable and preserved as comparison evidence. This is not full-cast
or finished-art approval.

## Open / play

Title → Dev Jump → **Battle art A/B comparison**, or:

```sh
godot res://scenes/proto/hybrid_combat_pilot.tscn
```

Use **A / B** or the header toggle to select the presentation; use arrow keys
and Enter to select Kai, move, open Attack/Magic, choose Serra and confirm the
forecast. Map selection, pathfinding, equipment and forecast use BattleView.
This is a repeatable local sandbox: no campaign progression, saving, XP or
weapon-use changes. Empty cells do not open the production field/save menu.

**1** sword, **2** critical, **3** miss, **4** magic*, **5** defeat, **6** paired
A/B reel, **R** reset. Buttons also expose Credits and return to Title.
*A magic currently uses its existing sword attack as the delivery gesture;
it is explicitly a placeholder, not proof of a finished pixel casting cycle.

[Final A/B video](comparison.mp4) · [Illustrated color pass](illustrated.mp4)

## Fairness and concrete scenario inputs

Both versions use the same original UnitDefs, weapons, terrain, seeded
CombatResolver and complete ordered StrikeResults, including counters and
follow-ups. Review selection searches an independent seed to exhibit the
requested outcome; it never fabricates a StrikeResult or consumes the live
combat RNG. Free play resolves once with its live RNG and replays that result.
HP updates at each player's actual contact event, and the map retains it.

| Case | Seed | Native ordered outcome (Kai initiates) |
|---|---:|---|
| Sword | 1 | Kai 6 → Serra 20; Serra counter 11 → Kai 15; Kai follow-up 6 → Serra 14 |
| Critical | 12 | Kai crit 18 → Serra 8; Serra counter misses; Kai crit 18 → Serra 0 |
| Miss | 0 | Kai misses; Serra counter 11 → Kai 15; Kai follow-up 6 → Serra 20 |
| Crown-light | 0 | Range 2, two 8-damage bolts → Serra 10; lance cannot counter |
| Defeat | 1 | Local Serra starts wounded at 6 HP; ordinary 6-damage hit defeats her |

All other scenarios start both actors at 26 HP. No permanent stats/formulas,
weapon data, RNG roll order, saves, canon or campaign content were changed.

Both are captured at the actual game viewport **1152×648 / 60fps**. B's
1280×720 staging scales uniformly to 0.9. A is normalized to the same visible
body height (about 306px): one standing-body measurement per kit, so Serra's
raised lance does not shrink her body. Filtering: nearest A/map, linear B.
The actors use each candidate's intended matching background; this is a
comparison of complete presentations, not a blinded single-variable test.

## Reuse audit

| Existing work | CP-6 treatment |
|---|---|
| StrikeResult / CombatResolver / CombatForecast / CombatRNG | Reused unchanged; complete native exchanges in both variants. |
| CombatRig | B subclasses its pose/registration/outcome/FX-profile hooks. No original pose/art or CP-2 animation changes. |
| JuiceController | One additive rig-factory hook defaults to the same CombatRig. B reuses its strike/impact/HP/sound/hit-stop pipeline; shared hit classification remains HitReaction. |
| HitReaction | Unchanged. B uses whole parry/hit/defeat poses + translation, with squash/wobble disabled locally. Miss evasion begins before contact. |
| BattlePopup | A subclasses the existing PixelLab player: comparison body-scale registration and pre-contact dodge only. Production player and original frames are unchanged. |
| Pixel map / units / tactical menus | Existing BattleView, TerrainTiles, cursor, pathfinding, forecast and pixel sprites. Sandbox overrides exclude campaign overlay/completion/saves. |
| CP-3 | Rejected procedural gait/anatomy is not used. |
| CP-4 / CP-5 | Preserved in place as isolated references, not used in either battle candidate. |

## Existing PixelLab assets and usage

Kai: character **bd17ee88-5685-455b-b9a6-465c6706d855**.
Serra: **d40d9a93-7610-44c5-b556-894ef5b9fecf**.
IDs and generation state: assets/source/pixellab/tools/cast_ids.json and
cast_rollout_state.json. Original ZIPs remain in the respective *_battle_pro
source folders. Generation/processing code: cast_rollout.py.

Each kit has 9 idle frames, 9 attack wind-up + 9 strike, 9 critical wind-up +
9 critical strike, 7 hit and 9 KO frames. Old single-segment attack/crit copies
are compatibility fallbacks, not extra unique authored motion. All four
wind/strike seams are pixel-identical at their join. The established processor
uses one union crop window per character across states (Kai 166×162, Serra
207×124 runtime canvases), retaining consistent alignment. No per-frame edits
or new cleanup in CP-6. A uses shared timing, ghost trails, hit-stop, pixel
projectiles and reaction playback.

**New PixelLab generation calls: 0. New Gemini/ImageGen calls: 0. New cleanup
frames: 0. Incremental generation spend: 0.** Neal reports PixelLab is active;
this test uses that resource's existing outputs strategically. No fresh
success-rate, account balance, plan price or hours-per-character benchmark was
measured, so this test cannot claim a specific roster budget or subscription
ROI. Earlier logs are historical costs, not a current estimate. No Qwen tool
was available in this session; visual assessment is Codex + Neal's review.

## Comparison and recommendation

| Criterion | A — PixelLab frames | B — illustrated whole poses |
|---|---|---|
| Motion | Continuous authored ready/strike/recovery and strong green sword trails; lively idle. | Fewer discrete silhouette changes; the short guard→thrust reads cleanly. Less secondary motion; a broad swing/recovery would need actual poses. |
| Cohesion | Wind/strike joins are exact; pixel frames keep connected anatomy. Attack art includes extra weapon/afterimage shapes that can read as doubled weapons. | Each pose is a complete intact illustration; no detachable limbs or procedural rig. Pose changes are still visible and cannot create unseen anatomy. |
| Identity | Recognizable green-haired, red-caped Kai; older dark battle outfit/headband and armored Serra differ from the newer illustrated references. Would need approved reference refresh before production. | Stronger match to the established face/costume/proportions. Kai stays on the source-facing left; no invented reverse head or Crown-mark view. |
| Color / magic | Saturated scene and conspicuous green blade effects win the initial color/magic comparison. Pixel spell gesture is not ready. | Initial treatment was too dim and effects too white. Final pass restores warm backdrop color, adds emerald blade light/gathering motes, a larger animated Crown projectile and colored impacts; no character repaint. |
| Production | Existing shared kit pipeline is viable; generated sequences still need review for weapon duplicates, crop alignment, clothing and frame continuity. Need multiple 7–9-frame sequences per character. | Existing five poses cover this test; shared timing/FX scale well. Missing weapon-class gestures need a bounded still-art pass, not endless mesh fixes. |
| World fit | Naturally consistent pixel map/battle aesthetic. | Clean pixel→illustrated→pixel transition feels intentional; painted courtyard retains the academy identity. Different resolution alone does not decide quality. |
| Cost/value | Existing subscription outputs offer genuine reuse; no new generation required. Fresh yield/cost remains unmeasured. | Existing approved art plus free effects and Godot provides a low incremental-cost path. Additional poses still have review/cleanup cost. |

**Recommendation after the actual A/B review: choose B's illustrated battle
characters and shared pose/timing/FX approach; keep pixel exploration/tactics.**
Neal explicitly prefers B's visual result. Borrow A's saturation, elemental
color and magical accents through high-resolution Godot/HD effects. Continue
using PixelLab for pixel world assets and retain its battle pipeline as a
fallback/reference; Gemini is useful for approved still key poses, portraits,
splashes and backgrounds. Avoid mixing pixel and illustrated actors in the same
combat shot, and do not generate complete Gemini animation sheets.

The final color pass is ready for Neal's review. It does not prove full roster
coverage: sword/lance thrusts and Crown-light are represented, not axes, bows,
all spells or directional artwork. No dedicated illustrated sword draw,
broad slash or independent recovery pose exists; this slice uses guard/action/
idle rather than distorting the art. A single view does not provide a true
turn. Stop here before cast production.

## Free effects / attribution

Only five 256px HD sheets and two CC0 particle textures were imported. Full
candidate evaluation, licenses, exact credit lines, hashes and adaptations:
[assets/source/hybrid_combat_fx/README.md](../../source/hybrid_combat_fx/README.md).
Credits are accessible in-engine. No paid animation service was added.

## Capture / validation

`capture.gd` replays A then B for each matching scenario and writes screenshots
to /tmp/vael-cp6-captures. Use a real renderer:

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp6-color-ab.avi \\
  -s assets/art_review/cp6_hybrid/capture.gd
```

The movie contains existing game SFX/music. Logs and automated-test results
are retained here. Automated checks establish deterministic results, contact
HP application, real tactical input, filtering and recovery—not taste approval.

**Final verification:** 552/552 tests, 3,572 assertions, 82 scripts, 103.327s.
Focused comparison suite: 5/5 tests, 186 assertions, 66.282s. The inherited
13 GUT deprecations and two ObjectDB/one resource exit reports remain.
No new runtime script errors in the rendered comparison or illustrated reel.

Source generation and PixelLab asset hashes: `pixel-kit-manifest.json`.
The final A/B reel is 62.32s; the illustrated-only reel is 26.63s, with audio.
Reproduce the latter with `capture_illustrated.gd` in the same movie command.

Title-menu input → comparison (B default) → Title and the standalone chapter
builder were verified separately; logs and entry_check.gd are included.
