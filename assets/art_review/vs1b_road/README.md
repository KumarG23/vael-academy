# VS-1B — revised road sequence evidence

2026-10-16; baseline f0c43294 (VS-1A). Main writing/integration notes and exact
missing painted assets: [VS1B_STORY_NOTES.md](../../../VS1B_STORY_NOTES.md).
The new prose is a playable draft for Neal's edit against his locked beats.

## Reproduce

```sh
godot --path . -s res://assets/art_review/vs1b_road/smoke.gd
godot --headless -s res://assets/art_review/vs1b_road/preview_gate_check.gd
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

The [graphical smoke](smoke.gd) starts from actual Title New Game/Classic input,
reads all five existing Awakening scenes in order, then the 20-panel road
handoff/rescue. The original four students, five raiders, original positions,
stats, terrain and objective are unchanged. Combat seed1 is selected for a
reproducible check. AIBrain chooses legal player commands; real cursor/menu/
forecast inputs run through the production combat resolver, enemy turns,
durability, XP and victory pipeline. Kai's equipment is his real sword; every
Kai action asserts the locked spell is unusable and Magic is absent. Other
students retain their normal kits. Native victory occurs in round5.

The runner asserts Victory is still hidden while the 19-panel bread aftermath
plays, then dismisses the result, chooses Tidemark through the real pitch/oath,
and reaches Week1 campus with the mark and story flags retained, without
Crownspark permission. [Final log](smoke-log.txt). No player saves are written,
overwritten or deleted. Reading is accelerated, so this is automated playable
flow proof, not a natural-duration human playtest or approval of dramatic pacing.

[Preview isolation check](preview_gate_check.gd) exercises both CP-2 and A/B
sandboxes while holding the original Crownspark resource alive. Each uses an
explicit private spell copy, keeps Campaign unchanged, and leaves the original
gate intact through construction, local magic selection and destruction.
The full-suite isolation regression caught an initial deep-copy mistake:
UnitDef.duplicate(true) did not isolate external spell resources. Fixed with
explicit per-spell copies and a replacement typed array; no default campaign
permission is granted to keep a demo working. [Final check log](preview-gate-log.txt).

**Full GUT: 576/576 tests, 3,967 assertions, 86 scripts, 148.688s.**

Focused story/Crownspark/campaign/VN tests: **35/35, 226 assertions, 1.034s**.
[Focused log](gut-focused-log.txt). Full-suite totals are recorded in HANDOFF,
MASTER_PLAN §10 and [the full log](gut-full-log.txt). Tests cover intro-before-
control, victory-only aftermath-before-result, seen flags, completed-road and
mid-battle save routing, old equipped spell repair/uses, native snapshot lock,
mark/school flags not granting control, explicit permission save/load, optional
art fallbacks, and all previously established three-house continuation checks.
Inherited deprecations/exit cleanup reports are identified in the full log;
there are no new runtime errors in final checks.

## Native 1152×648 captures

| Moment | Evidence |
|---|---|
| Hesta's intentional departure | [01](01-hesta-handoff.png) |
| Mother and boy in danger | [02](02-endangered-family.png) |
| Kai acts / involuntary flare | [03](03-involuntary-mark.png) |
| Serra organizes protection | [04](04-serra-organizes.png) |
| Rina spots the objective | [05](05-rina-observes.png) |
| Original playable map | [06](06-road-playable.png) |
| Kai's real action menu | [07](07-kai-no-controlled-magic.png) |
| Native attack forecast | [08](08-native-forecast.png) |
| Essa's bundle | [09](09-bread-bundle.png) |
| Kai shares bread | [10](10-bread-offer.png) |
| Perrin slows down | [11](11-perrin-cloak.png) |
| An invitation to walk together | [12](12-walk-with-us.png) |
| Victory only after the aftermath | [13](13-victory-after-bread.png) |
| Tidemark, Week1 campus | [14](14-tidemark-campus.png) |

These are screenshots of existing assets/text presentation, not new paintings.
The handoff and bread stills are absent, so their configured fallback is black;
the aftermath uses the pixel map until its painting exists. Survivors/Hesta use
existing fallback portrait cards; Kai's commoner-outfit portrait set is still
missing. Narrative actions are narrated/still-frame beats, not new map animation
or civilian units. All three heirs remain initial acquaintances, not instant
friends. No new voice/music/image generation or external spend. The existing
battle theme resumes after the intro, the aftermath pauses music, and house
choice restores the campus track. No academy arrival rewrite or new Vision.
