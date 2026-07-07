# HANDOFF.md — agent handoff & project state

For any coding agent picking this project up (Codex, a fresh Claude session, or a human).
Updated at the end of every work order (MASTER_PLAN §2 rule 8). **Last updated: 2026-07-06, playtest-3 batch 2 (52×40 campus, solid buildings, furnished interiors, room ceiling fix, heal cut-in, 14-cast battle-kit rollout running).**

## What this is

A Fire Emblem–style 2D tactics RPG ("Emberline Tactics", working title) in **Godot 4.7 / typed GDScript**, built one work order at a time against `MASTER_PLAN.md` — the single source of truth for scope, formulas, and status (§10 is the live status table). Narrative canon lives in the story bibles: `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`, `CHARACTER_BIBLE_*.md`. `PLAN_REWRITE_AUDIT.md` records the 2026-07 direction change (menu hub → walkable castle, house choice, romance, calendar). Read the plan first, then the bible relevant to the work.

## Current state (keep this section fresh)

- **⚠️ NARRATIVE DIRECTION — STORY SPINE v2 (NW-1, 2026-07-07).** The **wardstone-centered plot is DEPRECATED/demoted.** New canon: **ancient royal magic (the "First Crown"), Kai's secret lost royal bloodline, a relic sword (= his green blade, found with him as a foundling), Vael Academy built over a First Crown sanctum, and the king's presumed-dead brother as the faced antagonist.** Wardstones survive only as lesser, later imitations — NOT a failing-wards plot. Read `WORLD_BIBLE.md` §3–3b, `VILLAIN_BIBLE.md`, and the NW-1 row in MASTER_PLAN §10 before any story/content work. The shipped "fourth line" library lore (`lore_houses`/`castle_lore`/`beat_first_spark`/`lore_wardstones`) already seeds this — treat those as First Crown seeds, don't rewrite them. Prologue is now: awakening (forest→cave→sanctum→wake→parent reveal, **VN cutscene, not a built map**) → the existing road-raid tutorial battle → arrival → house choice. Draft prologue/pitch dialogues live in `data/dialogue/prologue_*.json` + `house_pitch_*.json` (parse-tested).

- **Where we are (2026-07-06): EVERY numbered engine WO in §10 is ✅ (M0–M8), and the game is in Neal-playtest iteration.** M9 "Modernization & Depth" arc (added from playtest 1): 9.1 ✅ castle v2, 9.2 ✅ 8-dir avatar, 9.3 partial (campus music slice), 9.4–9.10 open. M10 = the Town of Vael, **explicitly back-burnered until the campus is right**. **386/386 GUT tests green.** Remaining co-writes with Neal: 5.1b (supports), 5.3b (prologue → house-choice flow; now more relevant since the house lock landed), 4.2 (prologue script).
- **The castle is v2: top-down walkable Chrono-Trigger-style spaces.** `src/castle/castle_scene.gd` (CastleScene) + `CastleRoomDef/CastleDoor/CastlePoint` (`src/castle/`), rooms in `data/castle_v2/*.tres` — 10 rooms: **52×40 campus (rebuilt bigger playtest-3)** — Great Hall, Classroom Hall, Library Tower, Dormitory line the north with a broad central plaza (fountain, founder's statue, benches, lamps, hedges, flower beds, oaks, well, banners, Mission Board, Warden Maren, wandering students) and a south gate for the future town road; entrance (Oath Wall), common hall (Kael, cooking, feast set-pieces), war room (deploy + save), library (24×18 grand: colonnaded aisle, shelf wings, reading commons, 3 lore shelves + Alaric + sealed RESTRICTED STACKS behind an inner wall, `lore_restricted.json`), quartermaster, dorm hall, training (Brenna), waterside (Liora, fishing), classroom (Callan). All interiors furnished along the walls + floor. Free 8-dir movement w/ axis-separated collision, camera lerp-clamp, walk-in doors with an edge-guard (doors re-arm only after stepping OFF a door cell), floating door labels, timed toast UI, campus music loop.
- **WALKABLE-BUILDINGS + CEILING (playtest-3).** Campus buildings are big MapDecor; each building's FULL bounding box is now marked `SITE` (impassable), auto-computed from `texture_size × 4` (the decor scale, `cs/TILE` = 128/32) — you path around buildings, never onto roofs. INTERIOR ROOMS: props render bottom-anchored at 4× (a bookshelf is 2 cells tall, a statue 2.25), so anything on the top row overhung the map top and was clipped by the camera's top clamp. Fix: FLOOR-base rooms get a `_ceiling` band (1.6 cells) the camera reveals, drawn as a masonry back wall in `castle_scene._draw` (see `_camera_clamp` using `-_ceiling` as the top extent). Systemic — no per-room data edits. To furnish a room, place props on OPEN cells where terrain ∈ {PLAINS 0, FLOOR 7, CARPET 9} (interiors store floor as PLAINS, base_terrain=FLOOR is just the render fill — `get_terrain` returns 0 on open floor, NOT 7); never place SITE on a door's spawn_cell.
- **Battle screen + camera:** `src/ui/battle_view.gd` plays zoomed with a lerp camera that follows the CURSOR'S CELL (playtest-3 fix: the cursor node never moves — it draws at its cell; following `_cursor.position` pinned the camera to the NW corner) and **opens framed on the player's team** (`_focus_player_start`). Regression tests: `tests/test_battle_camera.gd`. The battle popup is v7 GBA-style: per-terrain painted backgrounds (defender's tile), team chrome, seam-synced two-part choreography (`*_wind`/`*_strike` chained at the impact frame), hit-stop/flash/knockback/shake, ghost trails, crit arc, death dissolve, battler auto-scale + ground planting.
- **Campaign singleton** (`src/core/campaign.gd`): `house_id` + **`house_locked` (FE3H rule — the Oath Wall binds a playthrough; set_house refuses while locked; reset on new game; persists in saves)**, week/calendar/current_event/advance_week, `flags` (e.g. `school_ember`, `cooking_unlocked`, `festival_seen`), `fish_log`. `ChapterRegistry` maps chapter ids → scenes, house-routed.
- **Battle cut-in gate = `has_kit` (NO fallback — Neal's call).** Every combat unit gets its OWN authored PixelLab kit; the popup only fires when both sides have one. A map-sprite fallback was built and then removed per Neal: unique battle animations for everyone. `BattlePopup.KIT_ALIASES` maps generic enemy ids to a shared design (tm_*→soldier/knight/mage, bandit_*→bandit, serra_prologue→serra).
- **BATTLE-KIT ROLLOUT (running detached, `assets/source/pixellab/tools/cast_rollout2.py`).** Generates unique pro-mode 128px kits + chained wind/strike choreography for the 14 named cast that lacked one: perrin/dain/liora (Emberwing) ✅ done first, then osric/elowen/isolde/fenn/bertram (Tidemark) + corin/thessaly/corvin/marlow/vesper/rurik (Thornrook). Designs read off the approved portraits; choreography is class-flavored (bow archetype is new for fenn/thessaly). Resumable state machine → `cast_rollout2_state.json`, ids → `cast2_kits_ids.json`, log → `rollout2.log`, review GIFs → `assets/art_review/combat_kits/<id>_battle_pro.gif`. If the process dies: `cd assets/source/pixellab/tools && nohup python3 cast_rollout2.py > rollout2.log 2>&1 &` — resumes, nothing regenerates. **~150 gens/kit; started at 3001, budget check the balance and STOP if < 800.**
- **Art pipeline (proven, PixelLab-first):** all 22 portraits live (`assets/portraits/portrait_<id>.png`; Kai = approved final). Map walks: `assets/sprites/units/<id>/walk_f*.png` (+ `walk_n_f*`/`walk_s_f*`). Battle kits: `assets/art/pixellab/<id>/{idle,attack[_wind|_strike],crit[_wind|_strike],hit,ko}_east/`. Props (~35): `assets/art/pixellab/props/`. Terrain: Wang atlases + `TerrainTiles`; **indoor walls have NO tileset — castle scenes draw walls (and the ceiling) in `_draw`**.
- **FE-style heal cut-in (playtest-3):** `BattlePopup.play_heal(healer, ally, hp_before, shot)` — healer raises the staff, a green blessing (rings + rising motes, on the `_bursts`/`_draw_fx` pipeline, kind `"heal"`) crosses to the ally as their HP bar fills. `execute_heal` calls it when both are kitted; falls back to floating +N otherwise. Battler staging shared via `_stage_battlers`.
- **Playtest cadence:** Neal plays, reports a list, we fix everything + tests, he replays. Playtest-3 batch 2 (this session): room ceiling/north-cutoff ✅, walkable buildings ✅, bigger campus ✅, furnished interiors ✅, heal cut-in ✅, kit rollout launched. All renders go to `assets/art_review/` (+ Artifact galleries).
- **Editor `ResourceSaver.save` is UNRELIABLE for data .tres this session** (silently no-ops, esp. dimensions) — prefer headless `godot --headless -s <builder>.gd` (retry through the transient "Identifier not found: Campaign" wedge; `--import` first helps) or a Python text-patch, and always VERIFY the file after (mtime/content).

## PixelLab gotchas (hard-won; keep)

1. `animate_character` **silently no-ops on duplicate animation_name** — redos need fresh names. 2. frame_count caps by canvas (128px → 8 frames/gen); chain segments via `custom_start_frame_base64`+`keep_first_frame`; the wind-up's last frame IS the strike's first. 3. Map objects: 32px minimum canvas, `/download` not `/image`, auto-delete ~8h. 4. Enum quirks: characters take "high detail", tilesets "highly detailed". 5. Verify a queued anim exists in the downloaded zip before chaining (registration lag). 6. Apostrophes slug to `_s` — match folders alphanumeric-only. 7. Long orchestrations run **detached** (`nohup … & disown` from `assets/source/pixellab/tools/`) with resumable state json — the harness reaps tracked background tasks. 8. Atlas fetch: curl the 302 Location WITHOUT auth. 9. Hair-recolor states unreliable; bake into fresh gens. 10. v3 mode can't do quadrupeds; standard-mode horse+rider mangles — mounted units need pro mode.

## Commands

```sh
# Run the full test suite (GUT) — the per-WO gate:
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Refresh Godot's import + global class cache (run after adding class_name scripts
# or resources, BEFORE headless test runs / game launches):
godot --headless --import

# Run the game:
godot            # main scene = title → castle
godot res://scenes/castle/castle.tscn        # straight to the campus
godot res://scenes/battle/mock_battle.tscn   # straight into the mock battle
```

## Conventions that are actually enforced

- **Typed GDScript everywhere**; logic/presentation split (pure classes in `src/core|combat|ai|progression|save`, nodes call into them); data as `.tres` resources; one `EventBus` autoload for cross-system signals. Full rules: MASTER_PLAN §2.
- **Combat formulas are law** (MASTER_PLAN §3) — implement exactly, tune via data. All combat RNG flows through the seedable `CombatRNG` (2RN hit / 1RN crit) so tests are deterministic.
- **One WO per session**, lowest-numbered with ✅ dependencies. Update §10 + this file, commit with the WO ID as the message. Content WOs (conversations, story) are co-written with Neal — draft, don't finalize.
- **Enum values in `Terrain.Type` and `ChapterDef.Objective` are persisted** — append, never renumber. Current tail: PATH=6, FLOOR=7, PILLAR=8, CARPET=9, SPRING=10 (heals 15%), FLOWERS=11, SITE=12 (invisible blocker under props).

## Tooling notes for non-Claude agents

- Claude sessions drive the Godot editor via **Godot MCP Pro** (`.mcp.json` + `addons/godot_mcp`) for screenshots/playtesting/simulated input. **None of that is required**: everything is achievable with the CLI commands above plus direct file edits. The MCP autoloads (`MCPScreenshot`, `MCPInputService`, `MCPGameInspector`) in `project.godot` are harmless — leave them registered.
- **Authoring `.tres` resources:** don't hand-write complex ones. Write a one-shot `extends SceneTree` builder script and run `godot --headless -s <script>.gd` (ASCII-map room authoring pattern: see the castle-v2 builders referenced in git history). For room tweaks, editing the `PackedInt32Array` terrain in the `.tres` with a small Python script is fine — verify the file mtime after ANY editor-driven save (silent failures happen).
- **`project.godot` is editor-owned** for autoloads/input/settings. If you must change those without the editor, edit carefully and run `godot --headless --import` after.

## Gotchas (each of these has already bitten once)

1. **Stale editor class cache.** A long-running Godot editor rewrites `.godot/global_script_class_cache.cfg` from its in-memory view on rescan; if it predates your new `class_name` scripts, every game it launches breaks. Fix: `godot --headless --import`, and restart the editor after WOs that add classes.
2. **Keyboard input on full-rect Control overlays** never arrives via `_gui_input` without focus — use `_unhandled_key_input` (see `ResultScreen`, `DialogueScene`).
3. **Awaiting a dialogue that finished synchronously hangs.** Check `is_finished()` before `await scene.finished` (see `battle_view._play_dialogue`).
4. **Shared `.tres` immutability:** `UnitDef`/`ClassDef` resources are cached by `load()` — never mutate at runtime; spawn paths `duplicate()` defensively.
5. **`Engine.time_scale`** is used for combat hit-stop — battle `_ready` and `JuiceController._exit_tree` reset it defensively.
6. **`unit.gd`'s Campaign reference wedges standalone `-s` tool scripts** with a compile error ("Identifier not found: Campaign"). Usually transient; when it persists, run the logic through the editor (`execute_editor_script`) or patch the `.tres` text directly — and always verify the save landed (mtime/content), editor saves can silently no-op.
7. **Control.position set at runtime is ABSOLUTE** (parent top-left); at `_ready` (parent size 0) it floats with anchors. Controls under Node2D have no parent rect — size them explicitly. Child Node2D draws above a parent's `_draw` — use `show_behind_parent` on the child (TerrainTiles does).
8. **The battle cursor node never moves** — it draws brackets at `cell * cell_size` while `position` stays (0,0). Anything tracking the cursor must use `cell` (see `battle_view._process`). `tests/test_battle_camera.gd` guards this.
9. **Walk-in doors are edge-guarded** (`_door_armed` in castle_scene) — doors only fire after the player steps OFF a door cell, so exit spawns may sit beside doors safely. Spawning ON a door does not bounce back (regression test in `tests/test_castle.gd`).

## Git / remote

- `origin` = private Forgejo on Neal's Tailnet (`http://100.120.211.122:3000/neal/vael-academy.git`). Push after every WO.
- Auth: username `neal` + token in the gitignored `.env` (`FORGEJO_TOKEN`). Push via a temporary `GIT_ASKPASS` helper that echoes the username/token — **never** put the token in the remote URL, git config, or any committed file.
- Commit style: `WO-<id>: <summary>` with a short bullet body.

## Where things live (quick map)

| Area | Files |
|---|---|
| Combat math/resolution (pure) | `src/combat/` — `combat_math.gd`, `combat_resolver.gd`, `combat_forecast.gd`, `combatant.gd`, `combat_rng.gd` |
| Grid/pathfinding/objectives (pure) | `src/core/` — `grid.gd`, `pathfinder.gd`, `movement_range.gd`, `objective_resolver.gd` |
| Battle orchestration | `src/ui/battle_view.gd` (+ `battle_popup.gd` v7 battle screen, `battle_cursor.gd`) |
| Walkable castle | `src/castle/castle_scene.gd` + `castle_room_def/door/point.gd`; rooms in `data/castle_v2/*.tres`; scene `scenes/castle/castle.tscn` |
| Between-battle state | `src/core/campaign.gd` (autoload `Campaign`; house lock, calendar, flags), `src/core/roster.gd`, `src/core/chapter_registry.gd`, `src/save/save_system.gd` |
| Dialogue engine | `src/ui/dialogue_script.gd`, `dialogue_step.gd`, `dialogue_scene.gd`; scripts in `data/dialogue/*.json` (lore shelves: `lore_*.json`) |
| Supports / skills / romance | `src/progression/`; data in `data/supports/`, `data/skills/` |
| AI | `src/ai/ai_brain.gd` (Aggressor/Sentinel/Boss) |
| Chapter data | `data/chapters/*.tres` (`ChapterDef`: terrain grid, objective, spawns, decor, visits) |
| Cast | `data/units/*.tres`, `data/classes/*.tres`, `data/houses/*.tres` |
| Map sprites | `assets/sprites/units/<id>/walk_f*.png` (+ `walk_n_f*`/`walk_s_f*`), scanned by `unit.gd` |
| Battle kits / props / tiles | `assets/art/pixellab/<id>/…_east/`, `assets/art/pixellab/props/`, `assets/art/pixellab/tilesets/` (+ `wang_maps.json`), battle bgs in `assets/art/pixellab/battle_bgs/` |
| Portraits | `assets/portraits/portrait_<id>.png` (all 22 live) |
| Review output for Neal | `assets/art_review/` (galleries also published as Artifacts) |
| PixelLab tooling | `assets/source/pixellab/tools/` (stdlib MCP client, orchestrators + state jsons, logs) |
