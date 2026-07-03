# MASTER_PLAN.md — Emberline Tactics (working title)

**A Fire Emblem–style tactics RPG in Godot 4.x, built by Fable (Claude) working milestone by milestone.**

This document is the single source of truth. Every work session starts by reading this file. Fable implements one work order at a time, verifies acceptance criteria, updates the STATUS section, and stops. Nothing outside the current work order gets built "while we're in there."

---

## 1. Vision

A 2D grid-based tactics RPG in the spirit of GBA-era Fire Emblem and Dark Deity:

- **Great story, great characters.** A small cast (8–12 playable units for the slice) whose personalities emerge through support conversations, not just cutscenes.
- **Character development through combat AND story.** Units grow mechanically (levels, promotions) and narratively (support bonds unlocked by fighting together). The two systems feed each other.
- **Incredible turn-based combat.** The classic loop: read the map, weigh terrain, exploit the weapon triangle, decide who risks the crit. Deterministic, inspectable math. No physics, no real time.
- **An academy at the heart of it.** A military academy hub (Three Houses' Officers Academy energy) with three rival houses — distinct colors, banners, personalities, and combat leanings spanning swords, lances, bows, magic, and faith. Between battles you return to the academy: talk to your house, train, manage the roster, take the next mission. House identity soaks into everything — UI theming, roster, supports, and who you face across the field.

**Non-goals (for the vertical slice):** 3D, multiplayer, procedural maps, voice acting, controller support, mobile. Do not build these. Do not scaffold for them.

**Definition of the vertical slice (end state of this plan):** One full loop of the game's real shape: **academy hub → mission briefing → one complete chapter (the inter-house Mock Battle) → outro → back to the hub with the roster changed by what happened.** Concretely: 4 playable units from the player's house, a rival house as the opposing force (6+ units + house leader), working level-ups, one support conversation unlockable through that battle, house-themed UI, save/load, and win/loss handling. When that loop exists and is fun, the plan gets extended.

---

## 2. Tech Stack & Conventions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.x (latest stable) | Text-based scenes/resources, ideal for AI-driven diffs |
| Language | GDScript, typed (`var x: int`) | Best model fluency, fastest iteration |
| Scenes | `.tscn` text format | Reviewable diffs |
| Data | Custom `Resource` classes saved as `.tres` | Units/classes/weapons/maps as data, not code |
| Version control | Git, one branch per work order optional | Small commits, message = work order ID |
| Tests | GUT (Godot Unit Test) for pure logic | Combat math and pathfinding MUST have tests |

### Project layout (create in WO-0.1, never reorganize without a work order)

```
res://
  src/
    core/         # Grid, pathfinding, turn manager, event bus
    combat/       # Combat resolver, damage formulas, forecast
    units/        # Unit node, unit state, stats
    ai/           # Enemy AI behaviors
    ui/           # Cursor, menus, forecast panel, dialogue box
    progression/  # Level-up, promotion, supports
    save/         # Save/load
  data/
    classes/      # ClassDef .tres files
    units/        # UnitDef .tres files
    weapons/      # WeaponDef .tres files
    chapters/     # ChapterDef .tres files
    supports/     # Support conversation data
  scenes/
    battle/       # Battle scene, map scenes
    dialogue/     # VN-style dialogue scene
    title/
  tests/          # GUT tests mirroring src/
  assets/         # Placeholder art (see §8)
```

### Coding rules for Fable

1. **Typed GDScript everywhere.** Signals typed where possible.
2. **Logic/presentation split.** Combat resolution, pathfinding, and AI are pure functions/classes with zero rendering dependencies — testable headless. Nodes call into them.
3. **One EventBus autoload** for cross-system signals (`unit_died`, `battle_won`, `support_rank_up`). No node reaches across the tree to find another system.
4. **Data-driven.** Adding a unit, weapon, or map means adding `.tres` files, not code.
5. **No premature abstraction.** Build for the slice. Refactor via explicit work orders.
6. **Every WO ends with:** run the game (or tests), confirm acceptance criteria, update §10 STATUS in this file, commit.

---

## 3. Core Combat Design (authoritative formulas)

These numbers are the genre. Implement exactly; tune later via data, not code changes.

### Stats
`HP, STR, MAG, SKL, SPD, LCK, DEF, RES, MOV`. Each unit has current values and per-stat **growth rates** (0–100%).

### Derived values
```
AttackSpeed (AS) = SPD − max(0, WeaponWeight − STR)   # burden only if weapon heavier than STR
Attack        = STR + WeaponMight (physical)  |  MAG + WeaponMight (magical)
HitRate       = WeaponHit + SKL*2 + LCK/2 + TriangleHitBonus
AvoidRate     = AS*2 + LCK + TerrainAvoid
CritRate      = WeaponCrit + SKL/2
CritAvoid     = LCK
DisplayedHit  = clamp(HitRate − AvoidRate, 0, 100)
DisplayedCrit = clamp(CritRate − CritAvoid, 0, 100)
Damage        = max(0, Attack + TriangleDmgBonus − (DEF + TerrainDef))   # RES for magic
CritDamage    = Damage * 3
```

### Weapon triangle
Sword > Axe > Lance > Sword. Advantage: `+15 hit, +1 damage`. Disadvantage: mirror. Magic (Anima/Light/Dark can wait — one "Tome" type for the slice) and Bows sit outside the triangle. Bows: range 2 only, cannot counter at range 1.

### Doubling (follow-up)
If `attacker.AS ≥ defender.AS + 4`, attacker strikes twice. Combat order: attacker → defender counter (if in range) → follow-up by whichever side qualifies.

### RNG
**2RN hit system** (GBA-style): roll two `randi() % 100`, average them, hit if `avg < DisplayedHit`. Crit uses 1RN. All RNG flows through a single seedable `CombatRNG` service so battles are replayable in tests.

### Terrain (slice set)
| Tile | Move cost | Def | Avoid |
|---|---|---|---|
| Plains | 1 | 0 | 0 |
| Forest | 2 | +1 | +20 |
| Mountain | 4 (impassable for armored/mounted) | +2 | +30 |
| Fort | 2 | +2 | +20, heal 10% HP/turn |
| Wall/Water | impassable | — | — |

### Level-ups
XP: ~10 for a hit, ~30+ for a kill, scaled by level difference (`+/−` clamp 1–100). At 100 XP → level up: each stat rolls `randi() % 100 < growth` for +1. Level cap 20; **promotion** at 10+ via item (slice: one promoted class to prove the system).

### Permadeath
Dead units are gone (flagged in save). A **Casual toggle** at new-game revives them post-chapter. Lord death = game over regardless.

---

## 4. Character, Story & Academy Systems

### The Academy & the three houses
The game is set at **Vael Academy** (placeholder — Neal renames), a military academy where noble and common students train in every discipline of war: blades, lances, bows, reason magic, and faith healing. Three houses, each a full identity:

| House | Colors | Banner animal | Personality | Combat leaning | Leader (slice) |
|---|---|---|---|---|---|
| **Emberwing** | Crimson / gold | Firebird | Bold, ambitious, heart-on-sleeve | Swords, cavalry, offense growths (STR/SPD) | **Ash** (the player's lord) |
| **Tidemark** | Deep blue / silver | Leviathan | Disciplined, chivalric, duty-bound | Lances, armor, faith; defense growths (DEF/HP) | **Serra** (rival, slice boss) |
| **Thornrook** | Forest green / bronze | Stag | Cunning, scholarly, pragmatic | Bows, reason magic; technique growths (SKL/RES) | **Corin** (rival, NPC in slice) |

**How houses touch the systems (all data-driven via a `HouseDef` resource):**
- **Identity & theming.** `HouseDef` carries primary/secondary colors, banner icon, and a UI theme tint. Menus, HP bars, turn banners, and unit team-tinting all pull from the active house. Switching houses later = swapping a resource, not reskinning code.
- **Roster & growths.** Each unit belongs to a house; house membership nudges class availability and growth flavor (encoded per-unit in `UnitDef`, so it's convention, not a hard rule — Three Houses style).
- **House Camaraderie passive.** `+5 hit and +5 avoid when within 2 tiles of a housemate.` Cheap to implement (same in-range check as supports), and it makes "fight together as a house" mechanically true from Chapter 1.
- **Supports live inside (and later across) houses.** Slice pair is intra-house; cross-house recruiting/supports are parked.
- **Slice scope:** the player *leads Emberwing* (fixed). All three houses exist in data, fiction, and UI; Tidemark takes the field as the Mock Battle opponent; Thornrook appears in dialogue. Choosing your house at new game is parked — the system is built so it's a data unlock, not a rewrite.

### The Academy Hub (between battles)
A **menu-driven base screen** — think FE's base camp / Three Houses' calendar with the walking-around stripped out (walkable hub is parked; see §11):
- **Common Hall:** view unlocked support conversations; short flavor dialogues with housemates that rotate per chapter.
- **Training Grounds:** each unit may do one training session per hub visit — small XP grant or +weapon familiarity flavor (slice: flat +10 XP, one unit per visit, to prove the loop).
- **Quartermaster:** roster, inventory, trading, promotion items.
- **Mission Board:** briefing dialogue → deploy to the next chapter.
The hub is a scene with its own house-themed backdrop and music hook, entered after every chapter and at campaign start.

### Support system (the heart of the "development through combat" pillar)
- Each pair of units with a defined support chain accrues **support points** when ending a turn adjacent or within 2 tiles of each other, and when one heals/rescues the other.
- Thresholds unlock ranks **C → B → A**. Each rank = one conversation (viewable from the pre-battle menu or base screen) + passive combat bonus when within 3 tiles: `C: +5 hit/avoid`, `B: +10 hit/avoid +1 dmg`, `A: +15 hit/avoid +1 dmg +5 crit`.
- Slice scope: **one pair, full C–B–A chain written.** System supports N pairs via data.

### Dialogue system
- VN-style: portraits left/right, name plate, text box, click/space to advance, choices optional (not in slice).
- Script format: JSON or a simple custom `.dlg` text format — **choose JSON** for the slice (trivially parseable, Fable can author it directly).
- Used for: chapter intro/outro, support conversations, mid-battle event triggers (e.g., boss quote).

### Slice cast (placeholder names — Neal rewrites freely)
**House Emberwing (playable):**
- **Lord:** Ash — sword, balanced, house leader, must survive.
- **Knight:** Brenna — lance, armored, slow/tanky (an Emberwing oddball; good character hook).
- **Myrmidon:** Kael — sword, fast, crit-leaning. *(Support pair: Ash–Kael)*
- **Healer:** Wren — staff, no combat, gains XP from healing.

**House Tidemark (Mock Battle opposition):**
- **Boss:** Serra — Tidemark's house leader, lance, holds the fort; yields when defeated (see WO-4.1).
- 5–6 Tidemark students: mixed lances/armor/one tome user, blue-tinted, using the same UnitDef system as playables — rival students are real units, not "monsters."

**House Thornrook:** Corin + house appear in intro/outro dialogue only (foreshadowing), zero combat content in slice.

---

## 5. Enemy AI (slice tiers)

Pure-logic `AIBrain` evaluating actions; no engine dependencies.

1. **Sentinel:** doesn't move until a player unit enters its threat range, then becomes Aggressor.
2. **Aggressor:** each enemy phase, pick reachable target maximizing `expected damage dealt − expected damage received` (use the same combat forecast the player sees — one source of truth). Prefer kills. Move toward nearest target if none reachable.
3. **Boss:** never moves off the fort; attacks anything in range.

Priority tiebreakers: kill > lowest counter-damage > lowest HP target. Deterministic given a seed.

---

## 6. Milestones & Work Orders

Each WO is one Fable session's worth of work. **Do not start a WO until all its dependencies are ✅ in §10.** Acceptance criteria are binding.

### M0 — Foundation
- **WO-0.1 Project skeleton.** Godot project, folder layout (§2), EventBus autoload, GUT installed, one passing dummy test, git init. *Accept: project opens, tests run green.*
- **WO-0.2 Grid & map.** `Grid` class (cell↔world math at 128px cells), logical terrain layer (data-only TileMap or 2D array in ChapterDef — **no visual tileset**; the visual layer is a single backdrop texture, flat placeholder color until AW-2), `TerrainDB` resource mapping terrain types → cost/def/avoid (§3 table). Subtle grid-line overlay + debug overlay showing terrain info under cursor. *Accept: 20×15 test map renders over a placeholder backdrop; hovering prints terrain stats.*
- **WO-0.3 Cursor & selection.** Keyboard/mouse cursor, select unit, deselect. *Accept: cursor moves cell-by-cell, selection state visible.*
- **WO-0.4 Units on the grid + movement.** `UnitDef` resource (stats, growths, class ref), `Unit` node, Dijkstra flood-fill for reachable tiles honoring terrain cost + occupancy, A* path, blue-tile highlight, animated move along path, red attack-range overlay. Tests for pathfinding on a fixture map. *Accept: select unit → see range → click tile → unit walks there; tests green.*

### M1 — Combat core
- **WO-1.1 Weapons & combat math.** `WeaponDef` resource; pure `CombatResolver` implementing §3 exactly (hit/crit/damage/AS/doubling/2RN, triangle, terrain) returning a full combat script (list of strikes with results). **Heavy test coverage — this is the most-tested code in the project.** *Accept: table-driven tests for every formula, seeded determinism test.*
- **WO-1.2 Combat forecast UI + execution.** Select target in range → forecast panel (dmg, hit, crit, doubling arrows both sides) → confirm → resolver runs → HP bars update, simple hit/miss/crit feedback, death removes unit, EventBus signals. *Accept: full player attack round with counter works on the test map.*
- **WO-1.3 Turn manager & enemy phase.** Player phase (each unit acts once: move+attack/wait), end turn, enemy phase running Aggressor AI (§5), back to player. Turn banner UI. *Accept: play 5 full rounds vs 3 enemies without errors.*
- **WO-1.4 Win/loss.** Rout and Seize objectives from `ChapterDef`; defeat on lord death; victory/defeat screens. *Accept: both outcomes reachable on the test map.*

### M2 — Depth
- **WO-2.1 XP & level-ups.** §3 XP rules, level-up screen with stat-gain animation, healer XP from staff use. *Accept: unit levels mid-battle; gains match growth rolls under a seed.*
- **WO-2.2 Inventory & weapon durability.** 5-slot inventory, equip, uses-per-weapon, trade between adjacent units, item use (vulnerary, promotion item). *Accept: weapon breaks at 0 uses; trade works.*
- **WO-2.3 Sentinel + Boss AI, threat display.** Remaining §5 behaviors; toggleable enemy-threat-range overlay. *Accept: sentinels wake correctly; boss holds fort.*
- **WO-2.4 Promotion.** One promoted class, promotion item flow, stat bonuses, cap reset. *Accept: Kael promotes and gains class bonuses.*
- **WO-2.5 Combat presentation layer ("juice").** Pure code, Darkest Dungeon philosophy — spectacle without frame animation: standee lunge/recoil tweens, **hit-stop** (60–120ms freeze on connect), screen shake scaled by damage, white hit-flash shader, damage number pop with easing, miss "whiff" slide, death dissolve, and the **clash splash system** — full-screen painted cut-in slammed in with speed-line shader on crits and kills (consumes AW-5 art; placeholder rectangle until then). All timings in one tunable `JuiceConfig` resource. *Accept: a crit visibly feels 3× more dramatic than a normal hit with placeholder art alone; timings tweakable without code edits.*

### M3 — Character systems
- **WO-3.1 Dialogue engine.** JSON-driven VN scene (§4): portraits, name plates, advance, event hooks (`start_battle`, `give_item`). *Accept: sample script plays start to finish.*
- **WO-3.2 Support system.** Point accrual rules, rank thresholds, in-range combat bonuses wired into CombatResolver inputs, rank-up notification, support menu listing unlocked conversations. *Accept: Ash+Kael reach C in a scripted test; bonus visibly changes forecast.*
- **WO-3.3 Save/load & permadeath.** JSON save (roster state, chapter progress, supports, hub state, casual flag, RNG seed), save slots, load from title. *Accept: save mid-campaign, quit, load, state identical.*
- **WO-3.4 House system.** `HouseDef` resource (colors, banner, theme tint, camaraderie values); all three houses authored as data; UI theming plumbed (menus, HP bars, turn banner, unit tinting pull from HouseDef); **House Camaraderie** passive (+5 hit/avoid within 2 tiles of a housemate) wired into CombatResolver inputs alongside supports. *Accept: swapping the player HouseDef re-themes the whole UI with zero code changes; camaraderie visibly changes the forecast; unit tests cover the passive.*
- **WO-3.5 Academy Hub.** Menu-driven hub scene per §4: Common Hall (supports + rotating flavor lines), Training Grounds (+10 XP, one unit per visit), Quartermaster (roster/inventory/promotion), Mission Board (briefing → deploy). House-themed backdrop. Campaign flow becomes hub → battle → hub. *Accept: full loop hub → Mock Battle → hub works; training XP persists through save/load.*

### M4 — The vertical slice
- **WO-4.1 Chapter 1: The Mock Battle.** Vael Academy's inter-house exercise — Emberwing vs Tidemark on a training field map (~20×15, hand-authored, forest/fort/mountain used meaningfully). **Non-lethal rules for this chapter only:** defeated units *yield* and retreat (flagged, not killed — permadeath system stays intact, this chapter just routes deaths to yields; a real Chapter 2 later restores stakes). Objective: Defeat Serra (fort boss) or rout. Intro (all three house leaders talk trash appropriately in-character) + outro + Serra battle quote + boss yield quote. Difficulty pass. *Accept: chapter is beatable and losable; a first-time player understands what to do; nobody can permanently die in it.*
- **WO-4.2 Support conversations.** Write Ash–Kael C/B/A. Tone brief: warm, character-forward, house-flavored (Emberwing's heart-on-sleeve culture should show), earns the A-rank payoff. *(Neal likely wants a heavy hand in this one — flag for co-writing.)*
- **WO-4.3 Title screen & game flow.** Title → New (Classic/Casual) / Load → hub intro → Mock Battle → results → hub → title. *Accept: full loop with no debug keys required.*
- **WO-4.4 Polish pass.** SFX hooks, screen shake on crit, better hit feedback, bugfix sweep from playtest notes. *Accept: Neal plays the chapter and files zero blockers.*

---

## 7. How Neal runs Fable against this plan

**Setup (one time):**
1. Create the repo; put this file at the root as `MASTER_PLAN.md`.
2. Create a short `CLAUDE.md` next to it containing: *"Read MASTER_PLAN.md first. Implement exactly one work order per session — the lowest-numbered WO whose dependencies are ✅ in §10, unless told otherwise. Obey §2 coding rules and §3 formulas as written. Finish by running tests, updating §10, and committing."*
3. Open the repo in **Claude Code** (this is the right harness — filesystem access, can run `godot --headless` for tests, persistent across the repo). Chat/Fable-in-browser is for design discussions and writing (e.g., WO-4.2); Claude Code is for implementation.

**Per session:** `"Do the next work order"` is a complete prompt. For content WOs, co-write. If a WO turns out too big, Fable splits it into `WO-x.ya/x.yb` in this file before coding.

**Godot headless test command** (Fable should verify the exact GUT invocation in WO-0.1):
`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

---

## 8. Art Track (parallel to code — never blocks it)

**Toolchain:** ComfyUI on Neal's R16 (production image generation) · Claude Code / Antigravity (pipeline scripting, ComfyUI API automation, Godot import) · Gemini image gen (fast concepting and character-consistent edit iterations only — production renders come from ComfyUI where seed/workflow are reproducible).

**Art direction (locked): full painted 2D. No pixel art anywhere.** Reference triangle: **Dark Deity** (painted dialogue busts) × **The Banner Saga** (painted map backdrops + unit standees, minimal motion) × **Darkest Dungeon** (combat spectacle from static art + juice, not frame animation). Every asset class below is something diffusion does *well*; frame-by-frame animation is deliberately absent from this game's art language.

**Standing rules:**
1. **Code never waits on art.** Every system WO ships with programmer art (colored tokens with class letters, red/blue team tint, initialed portrait frames). Art lands via swap-in WOs after the system it dresses is ✅. The §2 logic/presentation split makes swaps zero-logic.
2. **Maps are paintings, not tilesets.** Each battle map is **one painted backdrop image** (ComfyUI top-down/high-angle battlefield) with an *invisible logical grid* on top defining terrain per §3. Terrain readability comes from the painting itself plus data-driven overlays (subtle grid lines, terrain icon on cursor-hover, tint on highlight). This eliminates seamless-tile generation entirely.
3. **Units on the map are painted standees** — Banner Saga style. Per-class painted figure (~waist-up or full-body chip) in a house-colored base ring, generated in ComfyUI from the Style Bible. Motion is tweened in code: slide along path, idle bob, lunge on attack, flash on hit, dissolve on death. No sprite sheets.
4. **Combat spectacle is a code system + one static image per character.** The **clash splash** (AW-5): painted attack cut-in per named unit (weapon raised, speed lines, house-color energy), slammed in by the presentation layer (WO-2.5) on crits/kills. Generic per-class splash for unnamed units.
5. **Consistency law.** No production asset is generated until the Style Bible (AW-1) exists. Every character gets a locked reference sheet before variants. Style drift = regenerate, don't hand-fix.

**Asset specs (authoritative):**
| Asset | Spec |
|---|---|
| Portraits | 1024² generation → transparent PNG → displayed ~400px; naming `portrait_<unit>_<expression>.png`; expressions per unit: neutral, happy, angry, hurt (slice) |
| Map standees | ~512² generation → transparent PNG → displayed ~96–128px per cell; per-class + unique for lords/bosses; house-color base ring composited in pipeline |
| Map backdrops | ≥2560×1920 painted battlefield per map (20×15 grid at 128px/cell), landmarks aligned to grid in a touch-up pass |
| Clash splashes | 1920×1080 wide cut-in, transparent-edge vignette; per named unit + per class generic |
| Backgrounds | 1920×1080: hub (per-house tint variant), title |
| House art | Banner/crest per house, 256², transparent, matching HouseDef colors |

### Art work orders (AW — parallel track, own dependency chain)
- **AW-1 Style Bible.** One doc: the painterly look (Dark Deity-bust energy, Banner Saga battlefield palette discipline), master palette incl. the three house palettes, line weight, lighting rule, and the **base prompt templates** (portrait / standee / backdrop / splash) + negatives + fixed generation params (model, sampler, CFG, resolution). Includes 4–6 approved exemplar images per template generated in ComfyUI. *Accept: Neal signs off; each template reproduces its look on a fresh seed batch.*
- **AW-2 Map backdrop & terrain-authoring flow.** Generate the Mock Battle backdrop (painted training field with fort, forest patch, ridge — landmarks placed to serve the §3 terrain table), touch-up pass aligning features to the 128px grid, then author the invisible terrain grid over it. Includes a tiny in-editor terrain painter (code job for Fable: click cells, assign terrain type, saves to ChapterDef) so future maps take minutes. *Accept: test map plays on the painted backdrop; hover shows correct terrain everywhere; grid/terrain overlays readable.*
- **AW-3 Pipeline scripts (Claude Code/Antigravity job).** Python batch runner against the ComfyUI HTTP/JSON API on the R16 (`--listen 0.0.0.0`, reachable over the Tailscale mesh; **never exposed publicly**): takes a manifest (YAML: asset type, name, description tags, variants) → `POST /prompt` with API-format workflow JSON → poll `/history` → fetch via `/view` → rembg background strip → resize/crop to spec → convention-named PNGs → copies into `assets/` with Godot `.import` presets. **Control architecture:** the runner is deterministic daemon code, registered as a Hermes-callable tool — models author manifests, the daemon executes identically every run. Interactive mode: Claude Code drives the API directly during AW-1/AW-4 taste sessions, using its vision to inspect each output and adjust prompts/seeds in a closed loop. Batch QC: Qwen3-VL (A2000) does cheap first-pass consistency checks (same character / clean alpha / no artifacts); survivors escalate to Claude + Neal for style sign-off. *Accept: one command (or one Hermes job) regenerates any asset class from manifests.*
- **AW-4 Character reference sheets & standees.** Per slice-cast unit (§4): locked base portrait via AW-1 template, expression variants via inpainting/img2img from the base — **not** fresh generations; matching map standee derived from the same reference; per-class generic standees for Tidemark students. *Accept: all portraits and standees pass a side-by-side consistency review; standees read clearly at 96px on the backdrop.*
- **AW-5 Clash splashes, house & UI art.** Attack cut-ins for the four playables + Serra + one per-class generic; three house crests/banners; UI frame set; house-tinted hub backdrops; title art. *Accept: WO-2.5 consumes real splashes; WO-3.4 theming consumes real crests; hub uses real backdrop.*
- **AW-6 Integration passes.** Swap-ins gated on code WOs: portraits → after WO-3.1 (dialogue); backdrop/standees → after WO-0.4; splashes → after WO-2.5; house/UI art → after WO-3.4/3.5; title → after WO-4.3.

**Dependency note:** AW-1 → AW-2/3/4/5 → AW-6. None of it gates any code WO (the terrain painter inside AW-2 is the one code assist, and it's optional for the slice's single map).

## 9. Risks & standing decisions

- **Scope creep is the boss of this project.** New ideas go to §11 PARKING LOT, not into code.
- **Combat feel > feature count.** If forced to choose, WO-4.4 polish beats any parked feature.
- **Rescue/canto/skills/fog-of-war/trading-post/base camp:** all parked. The slice proves the loop first.
- Godot version pinned at whatever WO-0.1 installs; upgrades are their own WO.

## 10. STATUS (Fable updates this — never delete rows)

| WO | Status | Notes |
|---|---|---|
| 0.1 | ✅ done | Godot 4.7 project; §2 folder layout; EventBus autoload; GUT 9.7.0; 3 dummy tests green; git init. Test cmd: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` |
| 0.2 | ✅ done | `Grid` (128px cell↔world math), `Terrain`/`TerrainInfo`/`TerrainDB` (§3 table exact), `ChapterDef` (logical terrain array + backdrop). Battle scene: flat placeholder backdrop, per-terrain debug tints, subtle grid overlay, fitted camera, cursor terrain readout (prints stats). 20×15 `test_map.tres` with all 6 terrain types. 25 tests green. |
| 0.3 | ✅ done | `BattleCursor`: cell-by-cell keyboard move (arrows+WASD, held-key repeat), mouse follow, confirm/cancel selection with signals (`cell_changed`/`confirmed`/`cancelled`/`selection_changed`) for WO-0.4 unit hookup. Visible reticle + selected-cell highlight. Custom input actions in project.godot. Terrain readout now driven by cursor. 41 tests green. |
| 0.4 | ✅ done | `ClassDef`/`UnitDef` resources; `Unit` node (placeholder token: team-ring disc + class letter, animated path move). Pure `Pathfinder` (Dijkstra reachable + A*), `BattleMoveContext` (terrain cost, occupancy, armored/mounted rough-terrain block), `MovementRange` (standable/attack tiles). `RangeOverlay` blue-move/red-attack. battle_view: select→range→click→walk, occupancy-aware. 56 tests green (15 pathfinding on fixtures); interactive flow verified headless. |
| 1.1 | ✅ done | Pure combat core (src/combat): `CombatMath` (every §3 formula, int floor), `WeaponTriangle` (sword>axe>lance, +15hit/+1dmg), `WeaponDef` resource, `Combatant` snapshot, seedable `CombatRNG` (2RN hit / 1RN crit), `CombatForecast` (RNG-free UI math), `CombatResolver` → ordered combat script (`StrikeResult`/`CombatResult`) with counter/doubling/lethal-stop/crit. Slice weapons authored (iron sword/lance/axe/bow, fire tome, heal staff). 93 tests green incl. table-driven per-formula + seeded determinism. |
| 1.2 | ✅ done | Attack flow in battle_view: select→move→choose target in range→two-sided `CombatForecastPanel` (dmg/hit/crit/×2 doubling, "no counter")→confirm→`CombatResolver` runs→per-strike HP-bar updates + floating dmg/Miss/CRIT feedback + hit flash; death removes unit & emits `EventBus.unit_died`. UnitDef gains equipped `weapon`; Unit gains HP/HP-bar/combatant snapshot. 95 tests green incl. integration: full attack round with counter + lethal-removal/EventBus on the test map. |
| 1.3 | ✅ done | `TurnManager` (player/enemy phases, round count). Player phase: each unit acts once (move+attack/wait), `has_acted` greys unit; end turn via T/Tab or auto when all acted. Enemy phase: pure `AIBrain` Aggressor (§5) — deterministic, maximizes expected (dealt−received) via CombatForecast, prefers kills, advances toward nearest when unreachable; `AIDecision` output executed (move+attack) reusing the WO-1.2 combat path. `TurnBanner` UI. 108 tests green incl. AI scoring/decision + 5-round loop vs 3 enemies. |
| 1.4 | ✅ done | Pure `ObjectiveResolver` (ROUT / SEIZE, defeat-precedence: lord death = game over §3, or full player wipe). `ChapterDef` gains `objective`+`seize_cell`; `UnitDef` gains `is_lord`. battle_view checks after every combat/move/enemy-phase, gates input once over, shows `ResultScreen` (Victory/Defeat, dismiss→reload), emits `EventBus.battle_won`. Seize-tile marker drawn. 120 tests green incl. both outcomes reachable on the test map (seize-through-play, rout, lord-death defeat via enemy phase). Completes M1. |
| 2.1 | ⬜ | depends 1.3 |
| 2.2 | ⬜ | depends 1.2 |
| 2.3 | ⬜ | depends 1.3 |
| 2.4 | ⬜ | depends 2.1, 2.2 |
| 2.5 | ⬜ | juice layer — depends 1.2 |
| 3.1 | ⬜ | depends 0.1 |
| 3.2 | ⬜ | depends 1.2, 2.1 |
| 3.3 | ⬜ | depends 2.x complete |
| 3.4 | ⬜ | houses — depends 1.2 (resolver inputs), 0.1 |
| 3.5 | ⬜ | academy hub — depends 3.1, 3.2, 3.4, 2.2 |
| 4.1 | ⬜ | Mock Battle — depends M1–M3 complete incl. 3.4/3.5 |
| 4.2 | ⬜ | depends 3.1, 3.2 — co-write with Neal |
| 4.3 | ⬜ | depends 4.1, 3.3, 3.5 |
| 4.4 | ⬜ | depends 4.1–4.3 |
| AW-1 | ⬜ | style bible — no deps, start anytime |
| AW-2 | ⬜ | Mock Battle backdrop + terrain painter — depends AW-1 |
| AW-3 | ⬜ | pipeline scripts — depends AW-1 |
| AW-4 | ⬜ | reference sheets + standees — depends AW-1, AW-3 |
| AW-5 | ⬜ | splashes/house/UI art — depends AW-1 |
| AW-6 | ⬜ | integration — depends AW-2/4/5 + gating code WOs (§8) |

## 11. PARKING LOT (ideas land here, not in code)

- Rescue/carry, canto, class skills, fog of war, arena, shops, second support pair, difficulty modes, 3D remake question — revisit after the slice is fun.
- **Academy expansions (post-slice, in rough priority order):** house choice at new game (already data-ready via HouseDef); **walkable 2D hub** (top-down academy map with NPCs — the real Three Houses feel, but it's a whole content pipeline); calendar/timetable system; recruiting students from rival houses (cross-house supports); professor/instruction mechanics (directed stat training); motivation/gifts/tea-time analogues; house-vs-house tournament arc as the campaign spine.
