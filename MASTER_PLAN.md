# MASTER_PLAN.md — Emberline Tactics (working title)

**A Fire Emblem–style tactics RPG in Godot 4.x, built by Fable (Claude) working milestone by milestone.**

This document is the single source of truth. Every work session starts by reading this file. Fable implements one work order at a time, verifies acceptance criteria, updates the STATUS section, and stops. Nothing outside the current work order gets built "while we're in there."

**Companion story bibles (canonical narrative source of truth — read alongside this plan for any content WO):** `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`, `CHARACTER_BIBLE_KAI.md`, `CHARACTER_BIBLE_HEADS.md`, `CHARACTER_BIBLE_EMBERWING.md`, `CHARACTER_BIBLE_TIDEMARK.md`, `CHARACTER_BIBLE_THORNROOK.md`. This plan owns *how it's built*; the bibles own *what it is*. (`PLAN_REWRITE_AUDIT.md` is the decision record for this revision; `FABLE_PROMPTS.md` holds the session prompts.)

> **Direction note (this revision):** The combat vertical slice (M0–M4) is essentially proven — the read-map/weigh-terrain/exploit-triangle loop works, 245 tests green. This revision extends the plan to the **full game**: a walkable, living castle-school (not a menu); real **house choice** with all three houses playable from the start; **romance**; a bandit-raid **prologue**; a **school-year calendar**; and Kai's magic as a slow, unique reveal. The rewrite is *additive and reflavoring* — see `PLAN_REWRITE_AUDIT.md`. Of everything built, exactly one presentation layer (the menu hub, WO-3.5) is replaced; its systems survive. **No timeline pressure: build this as large as it can be without going overboard, one work order at a time.**
>
> *Reviewed against the codebase 2026-07-04 (Fable): reuse claims verified; M5 reordered (rosters before choice-flow acceptance); WO-4.1b/4.5/4.6 added; hidden technical gaps folded into WO scopes below.*

---

## 1. Vision

A 2D grid-based tactics RPG in the spirit of GBA-era Fire Emblem, Three Houses, and Dark Deity:

- **Great story, great characters.** A cast whose personalities emerge through support conversations and a living school, not just cutscenes.
- **Character development through combat AND story.** Units grow mechanically (levels, promotions, skills) and narratively (support bonds, romance, house identity). The two systems feed each other. The protagonist, **Kai**, is this pillar with a face on it (see §4).
- **Incredible turn-based combat.** The classic loop: read the map, weigh terrain, exploit the weapon triangle, decide who risks the crit. Deterministic, inspectable math. No physics, no real time.
- **A living academy at the heart of it.** **Vael Academy is a walkable castle-school, not a menu** — the game's main attraction and the bulk of its art. Three houses with distinct colors, banners, personalities, and combat leanings (swords, lances, bows, reason, faith). Between battles the player *explores* the castle: talk to housemates, train, fish, cook, study, attend holidays and parties, take the next mission. **The player chooses one of the three houses**, and that choice reshapes roster, tactics, conversations, romances, and who they face across the field — the spine of replayability.

**Non-goals (still true):** 3D, multiplayer, procedural maps, voice acting, controller support, mobile. Do not build these. Do not scaffold for them. (The walkable castle is **2D** — it is now in scope; 3D remains out.)

**North stars, in order:**
1. **Combat slice (M0–M4) — essentially done.** The tactical loop is proven and fun.
2. **School slice (next target).** Prove the *living-school* loop the way M0–M4 proved combat: prologue → house choice → walkable castle with one working activity → opening inter-house battle → back to the castle, changed. Concretely, the school-slice checkpoint is **5.1 + 5.2 + 5.3 + 6.1 + 6.2 + 6.4** plus the opening battle (4.1, done) — full three-house parity (5.4–5.6) and romance (5.7) do *not* gate it. When that loop exists and is fun, scale it out.
3. **Full game.** All three houses fully playable, the school year, romance, Kai's magic arc, and the kingdom's escalating mystery.

---

## 2. Tech Stack & Conventions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.x (latest stable) | Text-based scenes/resources, ideal for AI-driven diffs |
| Language | GDScript, typed (`var x: int`) | Best model fluency, fastest iteration |
| Scenes | `.tscn` text format | Reviewable diffs |
| Data | Custom `Resource` classes saved as `.tres` | Units/classes/weapons/maps/houses/cast as data, not code |
| Version control | Git, one branch per work order optional | Small commits, message = work order ID |
| Tests | GUT (Godot Unit Test) for pure logic | Combat math, pathfinding, progression MUST have tests |
| Editor automation | Godot MCP Pro 1.15.0 (`.mcp.json` + `addons/godot_mcp`) | Inspect/edit scenes and project settings through the Godot editor API; playtest with screenshots and simulated input |

### Project layout (extend, don't reorganize without a work order)

```
res://
  src/
    core/         # Grid, pathfinding, turn manager, event bus
    combat/       # Combat resolver, damage formulas, forecast
    units/        # Unit node, unit state, stats
    ai/           # Enemy AI behaviors
    ui/           # Cursor, menus, forecast panel, dialogue box
    progression/  # Level-up, promotion, supports, skills
    save/         # Save/load
    hub/          # Castle exploration, rooms, NPC interaction, activities  (NEW — M6)
    calendar/     # School-year system, events, exams, holidays            (NEW — M7)
  data/
    classes/      # ClassDef .tres
    units/        # UnitDef .tres (full cast — all three houses)
    weapons/      # WeaponDef .tres
    chapters/     # ChapterDef .tres
    supports/     # Support + romance conversation data
    houses/       # HouseDef .tres (all three)
    skills/       # SkillDef .tres                                         (NEW — M8)
    rooms/        # Castle RoomDef .tres                                   (NEW — M6)
    calendar/     # Calendar/event data                                   (NEW — M7)
  scenes/
    battle/       # Battle scene, map scenes
    dialogue/     # VN-style dialogue scene (supports branches/choices)
    hub/          # Castle rooms & exploration                            (NEW — M6)
    title/
  tests/          # GUT tests mirroring src/
  assets/         # Painted art (see §8)
```

### Coding rules for Fable

1. **Typed GDScript everywhere.** Signals typed where possible.
2. **Logic/presentation split.** Combat resolution, pathfinding, AI, progression, calendar logic are pure functions/classes with zero rendering dependencies — testable headless. Nodes call into them. *(This rule is exactly why the menu→castle swap is cheap.)*
3. **One EventBus autoload** for cross-system signals. No node reaches across the tree to find another system.
4. **Data-driven.** Adding a unit, weapon, map, house, room, skill, or calendar event means adding `.tres` files, not code.
5. **No premature abstraction.** Build for the current milestone. Refactor via explicit work orders.
6. **Use Godot MCP Pro for editor-scoped work.** Start scene/project work with `get_project_info`, `get_filesystem_tree`, `get_scene_tree`. Use MCP editor tools for scene nodes, inspector properties, project settings, autoloads, playtest screenshots, and simulated input. Direct file edits are fine for pure GDScript, resources, tests, and plan updates.
7. **Never hand-edit `project.godot` for editor-managed settings.** Use MCP tools (`set_project_setting`, `set_input_action`, `add_autoload`) so Godot owns serialization.
8. **Every WO ends with:** run the game (or tests), confirm acceptance criteria, update §10 STATUS **and `HANDOFF.md`**, commit.
9. **Reference the owning document, not memory of it.** Bibles for content, `PLAN_REWRITE_AUDIT.md` for direction rationale, `HANDOFF.md` for tooling/state, §10 notes + code for system details.

---

## 3. Core Combat Design (authoritative formulas)

These numbers are the genre. Implement exactly; tune later via data, not code changes. **Unchanged this revision.**

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
Sword > Axe > Lance > Sword. Advantage: `+15 hit, +1 damage`. Disadvantage: mirror. Magic (one "Tome" type for now; Anima/Light/Dark can wait) and Bows sit outside the triangle. Bows: range 2 only, cannot counter at range 1.

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
XP: ~10 for a hit, ~30+ for a kill, scaled by level difference (clamp 1–100). At 100 XP → level up: each stat rolls `randi() % 100 < growth` for +1. Level cap 20; **promotion** at 10+ via item.

### Permadeath
Dead units are gone (flagged in save). A **Casual toggle** at new-game revives them post-chapter. Lord (Kai) death = game over regardless.

---

## 4. Character, Story & Academy Systems

*Content lives in the bibles; this section is the build-facing summary of the systems that serve it.*

### Kai, the protagonist
A commoner — the first and only common-born student in Vael's history — whose latent magic is violently awakened by an ancient hidden stone (`CHARACTER_BIBLE_KAI.md`). For the slice he is sword-only with **involuntary magic tells** (no caster kit yet); his defining trait is that he cannot stand by while an innocent is harmed. His unique mechanical destiny (§ M8): unlike every other student — locked to one house's Warder specialty — Kai can eventually learn *any* school of magic, unlocked progressively through story, becoming the flexible, do-anything unit by the campaign's back half. Earned, not handed over. **Under house choice, Kai is house-agnostic: mechanically a protagonist slot appended to whichever house roster the player picks, not a member of any house's own roster** (extraction lands in WO-5.2).

### The three houses & house choice (all three playable from the start)
Three Great Houses, each a founding Warder line and a ruling region (`WORLD_BIBLE.md`): **Emberwing** (crimson/gold, firebird, swords/cavalry/offense), **Tidemark** (blue/silver, leviathan, lances/armor/faith), **Thornrook** (green/bronze, stag, bows/reason/technique). `HouseDef` carries colors, banner, UI tint, and the **House Camaraderie** passive (+5 hit/avoid within 2 tiles of a housemate) — all built (WO-3.4).

**The player picks a house at new game, and all three are fully playable** (decision: build from the start). The choice forks roster, tactics, supports, romances, and which two houses become the rival forces at the inter-house battles. Every student is noble (great houses down to minor/landless/new-money lines); Kai's commoner status is his alone. Each house: **an heir + five students + a teacher**, full functional coverage (anchor / DPS / mobility / at-least-one-healer / personality outlier), drawn from that house's weapon identity so no two houses blur. Cast and kits: the five character bibles.

### The living castle (replaces the menu hub — WO-3.5 systems survive, presentation swapped)
Vael is a **walkable castle-school**, explored room to room between battles — the game's main attraction and art centerpiece (`ACADEMY_BIBLE.md` §3). Painted-backdrop rooms (same pipeline as maps, §8), NPCs standing where they belong, walk-up-and-talk conversations, and activities triggered in place. The four existing menu functions become rooms wired to their **already-built systems**: Common Hall (supports/flavor/meals), Training Grounds (+XP), Quartermaster (roster/inventory/promotion), War Room (mission deploy) — plus Library (lore/study/quizzes) and the grounds/waterside (fishing). The `Campaign` autoload and `Roster` builder (WO-3.5) are the backend; only the menu UI is discarded.

### The school year (calendar)
The campaign is one academic year, bracketed by two inter-house battles (opening = the reframed Mock Battle, WO-4.1; closing = the year's climax). Between them: exploration, conversations, exams, homework, holidays, parties, and meals with friends — the feel-good rhythm that makes the battles matter, with the kingdom's mystery escalating quietly underneath (`ACADEMY_BIBLE.md` §4).

### Supports & romance
Built support system (WO-3.2) — proximity points, C→B→A ranks, combat bonuses, any pair via data. **Not locked to any one pair** (a fiction change; the system already supports N pairs — note the two current chain-loading sites hard-code the single authored chain; a chain registry lands with WO-4.2). **Romance** adds one rank past A on a flagged basis: **all students are romanceable, heirs included — a pool of 18 —** regardless of gender; among the three heirs the marquee arcs are two female (Serra, Corin) + one male (Perrin). Genre-level only (crushes, confessions); cast is 15–18.

### Dialogue
JSON-driven VN engine (WO-3.1), extended with **choices/branches** for romance and school events (the engine is strictly linear today — the extension is its own WO, 4.6). Portraits, name plates, event hooks (`start_battle`, `give_item`, etc.). Used for chapter intro/outro, supports, romance, castle conversations, and calendar set-pieces.

### Skills (universal progression — M8)
All units unlock **skills** via level/class (un-parks class skills). Kai's cross-school magic is his unique flavor of this same system — everyone progresses; his progression is broader.

---

## 5. Enemy AI (slice tiers) — unchanged

Pure-logic `AIBrain` evaluating actions; no engine dependencies.

1. **Sentinel:** doesn't move until a player unit enters its threat range, then becomes Aggressor.
2. **Aggressor:** each enemy phase, pick reachable target maximizing `expected damage dealt − expected damage received` (same combat forecast the player sees). Prefer kills. Move toward nearest target if none reachable.
3. **Boss:** never moves off the fort; attacks anything in range.

Priority tiebreakers: kill > lowest counter-damage > lowest HP target. Deterministic given a seed.

---

## 6. Milestones & Work Orders

Each WO is one Fable session's worth of work. **Do not start a WO until all its dependencies are ✅ in §10.** Acceptance criteria are binding. If a WO is too big, Fable splits it into `WO-x.ya/x.yb` in this file before coding. *(Splits pre-authorized below where review flagged size risk.)*

### M0 — Foundation ✅ · M1 — Combat core ✅ · M2 — Depth ✅ · M3 — Character systems ✅
*(All done — see §10. WO-0.1 through 3.5. Combat, XP, inventory, promotion, juice, dialogue engine, supports, save/load, houses, and the hub systems all shipped and tested.)*

### M4 — Finish the combat/story slice (+ the two enablers M5 needs)
- **WO-4.1 Chapter 1: The Mock Battle.** ✅ done. *Reframed this revision as the school year's **opening inter-house battle** — fiction only, no rebuild.*
- **WO-4.1b Kai identity migration.** Rename the protagonist unit id `ash`→`kai` (and display name) across resources (unit `.tres`, `Roster` ids, support chain, chapter deploy keys), dialogue speakers, code references, and tests — **now, while saves are disposable**; after M5–M7 grow the save payload this becomes a migration project. Chapter-dialogue *voice* rewrite to match Kai's bible is content work and stays with the content passes. *Accept: no `ash`/`Ash` reference remains outside git history; tests green.*
- **WO-4.2 Support conversations.** Write the first full C/B/A chain (Kai–Kael as the natural first bond, per the bibles — not a mandated one). Warm, character-forward, house-flavored. **Scope includes the wiring the acceptance implies:** out-of-battle conversation playback (the Common Hall lists conversations but nothing plays them yet) and a support-chain registry replacing the two hard-coded single-chain loading sites. *(Co-write with Neal.)* *Accept: chain plays start to finish from the hub and is viewable in battle; bonus visibly changes forecast.*
- **WO-4.3 Title screen & game flow.** Title → New (Classic/Casual) / Load → into the campaign flow → results → loop. *Accept: full loop, no debug keys.*
- **WO-4.4 Polish pass.** SFX hooks, crit feedback, bugfix sweep from playtest. *Accept: Neal plays the chapter, files zero blockers.*
- **WO-4.5 battle_view refactor** *(promoted from §11 — precedes M5's battle-heavy WOs, not M6; the castle never touches battle_view).* Extract from the 1,400-line controller: a `UnitSpawner` (spawn/deploy/save-rebuild), an action-menu controller (command menu + item/trade/equip flows), and a combat executor (attack/heal execution, XP, weapon spend). battle_view keeps input + phase orchestration. Zero behavior change; the 245-test suite is the safety net. *Accept: behavior identical, all tests green, battle_view reduced to an orchestrator.*
- **WO-4.6 Dialogue choices/branches.** Choice steps + label/jump resolution in `DialogueScript`, choice UI in `DialogueScene`, tests. Needed by 5.7 (romance) and M7 (school events); optional spice for 5.1's heir talks. M6 needs none of it (walk-up talk and support entry are linear); 5.3's house pitches only need the existing `ChoiceMenu`. *Accept: a branched sample script plays both paths; linear scripts unaffected; tests cover parse + playback.*

### M5 — House choice, three playable houses & the prologue *(the core-of-the-game milestone; big by design)*
*(Reordered this revision: rosters before the choice flow — the flow's acceptance needs rosters to exist. **Ordering note:** after 5.3, the M6 castle WOs may interleave ahead of 5.4–5.7; see the §1 school-slice checkpoint.)*

- **WO-5.1 Prologue chapter — the bandit raid.** Tutorial battle: Kai + the three heirs as strangers caught in a roadside raid (`CAMPAIGN_STRUCTURE.md`). Kai's mark/magic flickers; per-heir conversations; teaches movement/attack/terrain. **Known technical gap, in scope:** `ChapterDef` has enemy spawns only — the player side is hard-wired to `Roster.player_units()`; the prologue needs chapter-driven player/guest spawns, plus heir guest `UnitDef`s (Serra exists only as an enemy boss def; Perrin and Corin don't exist at all). **Pre-authorized split:** 5.1a playable prologue battle (guest-spawn support, heir defs, map, objective) / 5.1b tutorial beats + heir/Kai conversations *(co-write)*. *Accept: playable prologue, all three heirs introduced, first-time player learns the controls.*
- **WO-5.2 Emberwing playable roster.** Author all Emberwing units as `.tres` per bible (Perrin + Dain + Liora new; confirm built Kai/Kael/Brenna/Wren), kits and growths matching house identity. **Includes extracting Kai from the Emberwing roster into a house-agnostic protagonist slot** appended to the chosen roster (§4). *Accept: full Emberwing roster deployable; Kai rides along as protagonist, not roster member; kits match §3 + bible.*
- **WO-5.3 House-choice new-game flow.** After the prologue: arrival, each house's in-character pitch (linear dialogue + `ChoiceMenu` — no branch dependency), player chooses → `HouseDef` selected at runtime, roster + theming set, choice persisted in save. **Flip points, enumerated:** `Roster` house-parameterization, `Campaign` gains the house field (+ save payload), battle_view's two `@export` house ids read from Campaign, hub/castle theming source. *Accept (mechanism-scoped): choosing any house sets roster/theming/rivals from data and survives save/load; Emberwing roster is final, Tidemark/Thornrook selectable with provisional rosters until 5.4/5.5; the opening battle plays the Emberwing-route variant until 5.6.* **Pre-authorized split:** 5.3a mechanism / 5.3b arrival + pitch content *(co-write)*.
- **WO-5.4 Tidemark playable roster.** Serra (playable version of the existing boss) + Osric/Elowen/Isolde/Fenn/Bertram, kits per bible. *Accept: full Tidemark roster deployable and plays distinctly from Emberwing.*
- **WO-5.5 Thornrook playable roster.** Corin + Thessaly/Corvin/Marlow/Vesper/Rurik, kits per bible. *Accept: full Thornrook roster deployable and plays distinctly.*
- **WO-5.6 Rival-force generation.** The two unpicked houses become the opposition at inter-house battles. **Bigger than "swap UnitDefs":** the opening battle's chapter data is currently Serra/Tidemark-specific (authored spawns, `boss_unit_id`, her quote/yield dialogue paths) — this WO adds per-rival-house chapter variants (spawns + boss + dialogue set), data-driven from the same UnitDefs. **Inherits the full-parity acceptance:** *whichever house is picked, the player fields the correct roster AND faces correct rival forces at the opening battle.*
- **WO-5.7 Romance tier.** Extend supports with one romance rank past A + romance flags (all students eligible, §4); branched confession scenes ride WO-4.6. *Accept: a flagged pair reaches romance rank in a scripted test; branch plays; non-romance pairs cap at A.*

### M6 — The living castle (shell + first activity) *(the "school slice" payoff — may start once 5.3 is ✅, ahead of 5.4–5.7)*
- **WO-6.1 Castle exploration shell.** Player avatar moves through room scenes; room-to-room transitions; interaction prompts. Backed by the existing `Campaign`/`Roster` systems. *Accept: walk the castle, move between ≥2 rooms, approach and trigger an interaction.*
- **WO-6.2a Core room conversions.** Common Hall, Training Grounds, War Room as painted-backdrop rooms wired to their existing systems; **menu hub retired** (including retargeting battle's result-dismissed flow and the main-scene/title entry to the castle). *Accept: those three functions work from their rooms; no menu remains; battle returns to the castle.*
- **WO-6.2b Remaining rooms.** Quartermaster, Library, grounds/waterside. Library ships **browse-only** (lore flavor) — quizzes/study/exams are WO-7.2. *Accept: every former menu function works from its room; Library and waterside exist as walkable places.*
- **WO-6.3 NPC conversations.** Housemates/NPCs placed in rooms; walk-up-and-talk; rotating per chapter; support/romance scene entry points. *Accept: talk to ≥3 NPCs in place; a support scene launches from the castle.*
- **WO-6.4 Fishing (flagship mini-game).** The first activity, self-contained, at the waterside. *Accept: fishing is playable and fun on its own; results persist through save/load.*

### M7 — The school year
- **WO-7.1 Calendar/year system.** Dates, terms, scheduled events, the two-battle bracket (opening = 4.1; closing = 7.4). **Scope includes the chapter registry/sequencing** (the campaign currently knows exactly one hard-coded battle scene) and date state in the save payload. *Accept: the year advances; events fire on schedule; state persists.*
- **WO-7.2 Story-unlocked activities.** Cooking, quizzes, exams — **each unlocked via an interaction/story moment, added one at a time** (per standing decision, §9). *Accept: each activity unlocks diegetically and plays; unlock persists.*
- **WO-7.3 Holidays & parties.** Authored calendar set-pieces; pure feel-good, character-forward. *Accept: at least one holiday and one party play as scheduled events.*
- **WO-7.4 Closing inter-house battle.** The year's climax chapter. *Accept: beatable/losable; raises stakes over the opening battle.*

### M8 — Progression depth
- **WO-8.1 Skill system.** All units unlock skills via level/class (`SkillDef` data-driven). **Scoped to passive/stat-modifier skills** riding the proven `Combatant` bonus path (the supports/camaraderie pattern). Combat-order-altering skills (vantage/astra-likes) mean resolver changes — explicitly out; their own future WO if wanted. *Accept: units gain skills on schedule; skills affect combat via the same forecast/resolver path; tests cover it.*
- **WO-8.2 Kai's cross-school magic.** His unique progressive unlock — schools of magic opening via story beats, riding the class/promotion/skill systems but broader than any house lane. *Accept: Kai gains a new school at a scripted story beat; forecast/resolver reflect it; balance holds.*

### M9+ — Beyond year one *(deliberately loose; extend when the school slice is fun)*
- Chapter 2 with real permadeath stakes; the wardstone mystery becomes visible; the escalation past the academy. Design when we get there.

---

## 7. How Neal runs Fable against this plan

**Setup (one time):** repo at root; this file + the eight bibles present; `CLAUDE.md` routing every session here; Godot MCP Pro enabled (`.mcp.json`, `addons/godot_mcp`, autoloads registered). Smoke-check before editor work: `get_project_info` → `Vael Academy`, `get_filesystem_tree` sees `res://src`. **Restart the Godot editor after any WO that adds new `class_name` scripts** (a stale editor rewrites the class cache from its old view and breaks launched games).

**Per session:** `"Do the next work order"` is a complete prompt — the lowest-numbered WO whose dependencies are ✅. For content WOs (supports, romance, prologue, house pitches), **co-write**, and read the relevant bible first. Design discussion and writing happen in chat/Fable-in-browser; implementation happens in Claude Code with MCP.

**Agent handoff:** `HANDOFF.md` (repo root, paired with `AGENTS.md` for Codex-family agents) carries the current project state, tooling notes, and gotchas so a non-Claude agent can pick the project up cold. It is updated at the end of every WO (§2 rule 8).

**Godot headless test command:** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

## 8. Art Track (parallel to code — never blocks it)

**Toolchain:** ComfyUI on the R16 (production) · Claude Code/Antigravity (pipeline scripting, ComfyUI API automation, Godot import) · Gemini (fast concepting/edit iterations only). **Art direction (locked): full painted 2D, no pixel art.** Reference triangle: **Dark Deity** (painted busts) × **The Banner Saga** (painted backdrops + standees, minimal motion) × **Darkest Dungeon** (spectacle from static art + juice).

**Standing rules:** code never waits on art (programmer art ships first, real art swaps in); maps are single painted backdrops with an invisible logical grid; **castle rooms are painted backdrops too** (same pipeline, new asset class this revision); units are painted standees, motion tweened in code; combat spectacle is a code system + one static clash-splash per character; no production asset before the Style Bible (AW-1); consistency law — locked reference sheet per character before variants.

**Scaling note (this revision):** the cast is now **~22 named characters** (Kai + 3 heirs + 15 students + 3 teachers) vs. the slice's handful — a real portrait-volume step-up. Plus **castle-room backdrops** (per room, house-tint variants where relevant). Same pipeline, larger manifest.

**Asset specs (authoritative):**
| Asset | Spec |
|---|---|
| Portraits | 1024² → transparent PNG → ~400px; `portrait_<unit>_<expression>.png`; expressions: neutral, happy, angry, hurt (slice) |
| Map standees | ~512² → transparent PNG → ~96–128px/cell; per-class + unique lords/bosses; house-color base ring |
| Map backdrops | ≥2560×1920 painted battlefield per map (20×15 @ 128px/cell) |
| **Castle-room backdrops** | painted room per location, house-tint variants where relevant; NPC standees composited in |
| Clash splashes | 1920×1080 cut-in, transparent-edge vignette; per named unit + per class generic |
| Backgrounds | 1920×1080: title; castle exteriors |
| House art | Banner/crest per house, 256², transparent, matching HouseDef colors |

### Art work orders (AW — parallel track, own dependency chain)
- **AW-1 Style Bible.** Painterly look, master + three house palettes, base prompt templates (portrait/standee/backdrop/**room**/splash) + negatives + fixed params, 4–6 exemplars per template. *Accept: Neal signs off; each template reproduces on a fresh seed batch.*
- **AW-2 Map backdrop & terrain-authoring flow.** Mock Battle backdrop + touch-up + invisible terrain grid + tiny in-editor terrain painter. *Accept: map plays on the painted backdrop; hover shows correct terrain.*
- **AW-3 Pipeline scripts.** Deterministic ComfyUI batch runner from YAML manifests (`/prompt`→poll→`/view`→rembg→resize→named PNGs→Godot import), Hermes-callable; interactive taste mode via Claude Code vision; Qwen3-VL first-pass QC. *Accept: one command regenerates any asset class from manifests.*
- **AW-4 Character reference sheets & standees.** Locked base portrait per cast member, expression variants via inpaint/img2img, matching standees. *Accept: consistency review passes; standees read at 96px.*
- **AW-5 Clash splashes, house & UI art.** Cut-ins per playable + bosses + per-class generic; three crests/banners; UI frame set; title art. *Accept: WO-2.5 consumes real splashes; WO-3.4 theming consumes real crests.*
- **AW-6 Integration passes.** Swap-ins gated on code WOs: portraits→after 3.1; backdrop/standees→after 0.4; splashes→after 2.5; house/UI→after 3.4/3.5; **castle-room art→after 6.2**; title→after 4.3.

**Dependency note:** AW-1 → AW-2/3/4/5 → AW-6. None gates any code WO.

## 9. Risks & standing decisions

- **Scope is the boss of this project.** The new direction (walkable castle + three playable houses + romance + school year) is a large, deliberate bet. New ideas go to §11 PARKING LOT, not into code.
- **No timeline; big but not overboard.** There is no deadline. Prefer depth done right over breadth done fast. But "big" is not "unbounded" — every addition is a scoped WO with acceptance criteria, and the north-star ordering (§1) holds: prove each loop before scaling it.
- **Build mini-games one at a time.** Fishing first and fun, *then* the next activity, each its own WO — never a batch. Additional activities unlock diegetically (via story/interaction), which also paces the build.
- **Combat feel > feature count.** If forced to choose, polish beats any parked feature.
- **All three houses is the expensive commitment (M5).** Accepted deliberately (the review audit recommended shipping one house first; overridden with eyes open). If it ever threatens momentum, the fallback is to ship the chosen-house path first and bring the other two online incrementally — but the plan of record is all three from the start. The M5/M6 interleave note (§6) keeps the school-slice proof from waiting on full parity.
- **Rescue/canto/fog-of-war/trading-post:** still parked. Godot version pinned at WO-0.1's install; upgrades are their own WO. MCP Pro is an accelerator, not a scope expander.

## 10. STATUS (Fable updates this — never delete rows)

| WO | Status | Notes |
|---|---|---|
| MCP-Pro | ✅ enabled | Godot MCP Pro 1.15.0 under `addons/godot_mcp`; `.mcp.json` → local server build; editor plugin + MCP autoloads enabled. Verified 2026-07-03: stdio server exposed 175 tools (build reports 1.14.1), WebSocket bridge connected, `get_project_info` returned `Vael Academy`. Suite green: 194/194 at time of check (245/245 as of 2026-07-04). |
| 0.1 | ✅ done | Godot 4.7 project; §2 folder layout; EventBus autoload; GUT 9.7.0; 3 dummy tests green; git init. Test cmd: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` |
| 0.2 | ✅ done | `Grid` (128px cell↔world), `Terrain`/`TerrainInfo`/`TerrainDB` (§3 exact), `ChapterDef` (logical terrain + backdrop). Battle scene: flat backdrop, per-terrain debug tints, grid overlay, fitted camera, cursor terrain readout. 20×15 `test_map.tres`. 25 tests green. |
| 0.3 | ✅ done | `BattleCursor`: cell-by-cell keyboard (arrows+WASD, repeat), mouse follow, confirm/cancel with signals for WO-0.4. Reticle + selected-cell highlight. Input actions in project.godot. 41 tests green. |
| 0.4 | ✅ done | `ClassDef`/`UnitDef`; `Unit` node (placeholder token, animated move). Pure `Pathfinder` (Dijkstra + A*), `BattleMoveContext`, `MovementRange`; `RangeOverlay`. select→range→click→walk, occupancy-aware. 56 tests green (15 pathfinding). |
| 1.1 | ✅ done | Pure combat core: `CombatMath` (every §3 formula), `WeaponTriangle`, `WeaponDef`, `Combatant`, seedable `CombatRNG` (2RN/1RN), `CombatForecast`, `CombatResolver` → ordered script with counter/doubling/lethal-stop/crit. Slice weapons authored. 93 tests green incl. per-formula + determinism. |
| 1.2 | ✅ done | Attack flow: select→move→target→two-sided `CombatForecastPanel`→confirm→resolver→HP-bar updates + floating feedback + hit flash; death removes unit & emits `EventBus.unit_died`. UnitDef gains `weapon`; Unit gains HP/snapshot. 95 tests green incl. counter integration. |
| 1.3 | ✅ done | `TurnManager` (player/enemy phases, rounds). Player: each unit acts once, greys when acted; end via T/Tab or auto. Enemy: pure `AIBrain` Aggressor (§5), deterministic, executed via WO-1.2 path. `TurnBanner`. 108 tests green incl. 5-round loop vs 3 enemies. |
| 1.4 | ✅ done | Pure `ObjectiveResolver` (ROUT/SEIZE, lord-death precedence). `ChapterDef` gains `objective`+`seize_cell`; `UnitDef` gains `is_lord`. Post-action checks, `ResultScreen`, `EventBus.battle_won`. 120 tests green incl. both outcomes. Completes M1. |
| 2.1 | ✅ done | Pure `CombatXP` (§3) + `LevelUp` (seedable growth rolls). `Unit` per-instance level/xp + gains (base UnitDef immutable). `LevelUpScreen`. Staff heal → healer XP; Wren + heal staff added; `combat_seed`. 140 tests green incl. level + healer-XP integration. |
| 2.2 | ✅ done | Pure `Inventory`(5)/`InventoryItem`/`ItemDef`. Per-instance uses; **breaks at 0** → backup auto-equips. Command menu (Attack/Heal/Item/Trade/Equip/Wait). Vulnerary; multi-give trade; equip reorder; promotion item held. 155 tests green incl. durability/trade. |
| 2.3 | ✅ done | §5 AI tiers: {AGGRESSOR, SENTINEL, BOSS}. Boss never leaves tile; Sentinel sleeps until enemy in threat then permanently Aggressor; `threat_tiles` + toggleable `ThreatOverlay` ('H'). 164 tests green incl. sleep-then-wake. |
| 2.4 | ✅ done | `ClassDef` gains `promoted_class` + bonuses. Pure `Promotion.is_eligible` (lvl ≥10 + path). `Unit.promote()` (per-instance override, stat+move bonuses, level→1, cap 20). Master Seal from Item menu. Myrmidon→Swordmaster; Kael carries a Seal. 173 tests green. |
| 2.5 | ✅ done | Combat juice (pure code): `JuiceController` lunge/recoil, hit-stop, damage-scaled shake, hit-flash, damage pops, whiff-slide, death dissolve, `ClashSplash` cut-in (placeholder until AW-5). All in `JuiceConfig`. 182 tests green. **Completes M2.** |
| 3.1 | ✅ done | JSON dialogue engine: pure `DialogueScript`/`DialogueStep` parser; `DialogueScene` VN player (placeholder tinted portraits, typewriter, advance, `event_triggered`+`finished`). Sample plays start→finish. 194 tests green. *(WO-4.6 extends with choices/branches — engine is strictly linear today.)* |
| 3.2 | ✅ done | `SupportChainDef` + pure `SupportState` (C/B/A @ 20/60/120; +10 within 2 tiles, +15 heal). Chain authored; rank-up emits `EventBus.support_rank_up`. Support bonuses on `Combatant` → one support-aware math path (forecast/resolver/AI). 200 tests green. *(5.7 adds romance rank; 4.2 adds the chain registry.)* |
| 3.3 | ✅ done | `SaveSystem` JSON slot IO + battle snapshot/restore (roster/chapter/turn/objective/supports/casual/defeated/permadead/RNG state as strings). Classic deaths flagged permadead & absent after load. 203 tests green. *(payload grows in M5–M7.)* |
| 3.4 | ✅ done | `HouseDef` (colors/banner/tint/camaraderie); all three houses authored. UI theming pulls from active house (rings/HP bars/banner/menus). Pure `Camaraderie` (+5 hit/avoid within 2 tiles) folds into the Combatant bonus path. 213 tests green. *(5.3 makes house runtime-chosen.)* |
| 3.5 | ✅ done | Menu-driven `HubScene`: Common Hall/Training(+10XP)/Quartermaster/Mission Board. Shared `Roster` builder; `Campaign` autoload (between-battle state, save/load). Flow hub↔battle works. 228 tests green. **⚠ Presentation replaced by the castle in M6; systems (`Campaign`/`Roster`) are kept — the menu functions themselves are UI and retire with the menu.** |
| 4.1 | ✅ done | Chapter 1 `mock_battle.tres` (20×15, forts/forest/ridge/wall/pond), full roster .tres, 6 Tidemark + Serra boss, DEFEAT_BOSS objective, non-lethal "Yields!" flag, intro/quotes/outro via in-battle dialogue, fort heal. 245 tests green. Verified in-game via MCP. **Reframed as the year's opening inter-house battle (fiction only).** |
| 4.1b | ✅ done | Full `ash`→`kai` id migration while saves were disposable: `data/units/kai.tres` + `data/supports/kai_kael.tres` (renamed, ids/names/conversation paths updated), `Roster.PLAYER_IDS`/deploy keys, mock_battle deploy cell key, both chain-loading sites, dialogue speakers/portraits (intro/outro/sample), hub flavor line reworded (player *is* Kai now), all test references. Zero `ash` references remain outside git history; stale ash-keyed dev saves wiped. Verified live: Kai deploys as lord, intro speaks as Kai. 245 tests green. Chapter-dialogue *voice* pass (Kai's guarded/dry register per bible) deferred to the 4.2/5.1b content passes as planned. |
| 4.2 | ✅ done | `SupportRegistry` loads every chain from `data/supports/` (both hard-coded loading sites replaced; new pairs are now data-only). Common Hall plays unlocked conversations as VN overlays (menu-gated, returns to the hall); in-battle Supports menu plays them too (non-action-consuming, falls back to the old pop if unwritten). Kai–Kael **C/B/A authored** (`kai_kael_{c,b,a}.json`) from the bibles — Kael's chosen-warmth depth beat at B, the bible's payoff line at A — **drafts pending Neal's edit (co-write)**. Kai voice pass on chapter intro/outro (rally moved to Kael; Kai dry/guarded per bible) — also for Neal's review. 252 tests green (7 new: registry, per-rank parse/voice checks, hub + battle playback, placeholder row inert, action not consumed). Verified live: C plays from the Common Hall and releases cleanly. Forecast-bonus acceptance was already covered by WO-3.2 tests. |
| 4.3 | ✅ done | `TitleScreen` (`scenes/title/title.tscn`, now the main scene via MCP `set_project_setting`): New Game (Classic/Casual) / Load Game (slot list from `SaveSystem.list_slots`, placeholder when empty) / Quit; placeholder title art with three equal house stripes. Hub gains **Return to Title**; campaign defeat now exits to the title (game over) instead of the hub; standalone battle scenes still reload. Fixes shipped with it: loading no longer hands back a free training session (`Campaign._skip_next_hub_reset`); `list_slots` reads both save schemas (battle `current_chapter_id` vs campaign `chapter_id`); **tests no longer pollute the player's real `user://saves`** (`Campaign.save_system_override`, injected by test_hub — this bug clobbered a real save during verification). 260 tests green (8 new). Verified live, keyboard-only: title → New Classic → hub → train+save → battle → victory → hub → Return to Title → Load → hub with XP restored and the loaded visit resuming its spent training. No debug keys anywhere in the loop. |
| 4.4 | ✅ done | Bugfix sweep from Neal's playtest (he played the chapter; all filed issues fixed): **FE cancel semantics** — cancel on the command menu undoes the move and frees the unit (was: counted as the turn); targeting/off-target cancel returns to the menu; trade-give cancel returns to the menu. **`UnitStatsPanel`** — "Stats" always on the command menu, plus select-to-inspect for enemies/exhausted units: class/Lv/XP, all stats, MOV, weapon numbers + range, carried weapons, plain-language role hints ("Healer — cannot attack", "Armored — mountains impassable", bow can't counter adjacent). **Supports view-once in battle** (`SupportState.viewed`, persisted through saves + campaign; Common Hall keeps the full archive with ✓ marks, replayable). **Difficulty tune-down**: Serra 28HP/8DEF (eff. 10 on fort), armor 24/9, guard 7STR/5DEF. **Text clipping fixed**: ChoiceMenu width fits its labels (title/slots/training rows), hub info wraps instead of truncating. SFX hooks deferred — no audio assets yet; JuiceController is the single attach point when they exist (no premature scaffolding, §2 rule 5). 268 tests green (8 new). Cancel-undo + stats panel verified live. |
| 4.5 | ⬜ | battle_view refactor (UnitSpawner / action-menu controller / combat executor; zero behavior change) — depends 4.4 |
| 4.6 | ⬜ | Dialogue choices/branches — depends 3.1 |
| 5.1 | ⬜ | Prologue: bandit raid + 3 heirs (guest-spawn support + heir defs in scope; split 5.1a/5.1b pre-authorized) — depends 4.5 |
| 5.2 | ⬜ | Emberwing playable roster + Kai protagonist-slot extraction — depends 5.1 |
| 5.3 | ⬜ | House-choice new-game flow (mechanism-scoped; split 5.3a/5.3b pre-authorized) — depends 3.4, 5.2 |
| 5.4 | ⬜ | Tidemark playable roster — depends 5.3 |
| 5.5 | ⬜ | Thornrook playable roster — depends 5.3 |
| 5.6 | ⬜ | Rival-force generation + per-rival chapter variants; full-parity acceptance — depends 5.4, 5.5 |
| 5.7 | ⬜ | Romance tier — depends 4.6, 3.2 |
| 6.1 | ⬜ | Castle exploration shell — depends 3.5 systems (may start once 5.3 ✅, ahead of 5.4–5.7) |
| 6.2a | ⬜ | Core room conversions (Common Hall/Training/War Room; retire menu; retarget battle→castle flow) — depends 6.1 |
| 6.2b | ⬜ | Remaining rooms (Quartermaster/Library browse-only/waterside) — depends 6.2a |
| 6.3 | ⬜ | NPC conversations in rooms — depends 6.1, 3.1 |
| 6.4 | ⬜ | Fishing (flagship mini-game) — depends 6.1 |
| 7.1 | ⬜ | Calendar/year system (incl. chapter registry/sequencing) — depends 6.2a |
| 7.2 | ⬜ | Story-unlocked activities (one at a time) — depends 7.1 |
| 7.3 | ⬜ | Holidays & parties — depends 7.1 |
| 7.4 | ⬜ | Closing inter-house battle — depends 5.6, 7.1 |
| 8.1 | ⬜ | Skill system (passive/stat-modifier scope) — depends 2.1, 2.4 |
| 8.2 | ⬜ | Kai's cross-school magic — depends 8.1 |
| AW-1 | ⏳ awaiting sign-off | `STYLE_BIBLE.md` drafted + 22 exemplars generated on the R16 in a closed-loop taste session (DreamShaperXL Turbo, euler/sgm_uniform/6 steps/cfg 2.0; all seeds recorded, reproducible). Six templates: portrait (7), standee (4), map backdrop (3), castle room (3), clash splash (3), vista (2) — all three house palettes exercised. Review copies in `assets/art_review/aw1_style_bible/`; sign-off gallery published (claude.ai artifact `5e694502`). Model failure modes documented in the bible (photo-drift on landscapes, "standee"→figurine, "map"→VTT, period drift → a pickup truck, fake painter signatures, age skew). **Blocked on Neal's approve/redirect per template (§8 acceptance); fresh-seed reproduction check runs at sign-off.** |
| AW-2 | ⬜ | Mock Battle backdrop + terrain painter — depends AW-1 |
| AW-3 | ⬜ | pipeline scripts — depends AW-1 |
| AW-4 | ⬜ | reference sheets + standees (full cast) — depends AW-1, AW-3 |
| AW-5 | ⬜ | splashes/house/UI art — depends AW-1 |
| AW-6 | ⬜ | integration (incl. castle-room art) — depends AW-2/4/5 + gating code WOs |

## 11. PARKING LOT (ideas land here, not in code)

- **Un-parked this revision (now real milestones):** walkable castle (M6), house choice (M5), calendar/year (M7), romance (M5), class skills (M8). **The `battle_view.gd` refactor is promoted to WO-4.5.**
- **Still parked:** rescue/carry, canto, fog of war, arena, shops, difficulty modes beyond Classic/Casual, cross-house recruiting (the unpicked heirs joining Kai's house later), professor/instruction directed-training mechanics, house-vs-house tournament arc, combat-order-altering skills (vantage/astra-likes — see 8.1 scope), 3D remake question. Revisit after the school slice is fun.
- **Full bidirectional trade screen:** current trade is one-directional multi-give; a proper take-items-too screen is later polish.
- **Title revisit:** "Emberline Tactics" leans Emberwing-specific now that all three houses are equal and player-chosen — worth revisiting once the game has an identity.

## 12. Open decisions (Neal's call — none block current WOs)

- **Roster count symmetry:** ✅ resolved — standardized to **heir + 5 students (6 playable) per house**. Emberwing's sixth (Liora, battle-mage, the house's only ranged attacker) added to the bible.
- **Kingdom name** (Aldreth placeholder), **teacher deployability** (mentors as occasional guest units?), **exact romance-scene depth**, **Kai's magic-unlock schedule** (which school, which chapter) — all flagged in the bibles, decide when the relevant WO comes up.
