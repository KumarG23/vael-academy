# HANDOFF.md — agent handoff & project state

For any coding agent picking this project up (Codex, a fresh Claude session, or a human).
Updated at the end of every work order (MASTER_PLAN §2 rule 8). **Last updated: 2026-07-04, after AW-7 v2 (GBA-FE sprite iteration).**

## What this is

A Fire Emblem–style 2D tactics RPG ("Emberline Tactics", working title) in **Godot 4.7 / typed GDScript**, built one work order at a time against `MASTER_PLAN.md` — the single source of truth for scope, formulas, and status (§10 is the live status table). Narrative canon lives in the story bibles: `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`, `CHARACTER_BIBLE_*.md`. `PLAN_REWRITE_AUDIT.md` records the 2026-07 direction change (menu hub → walkable castle, house choice, romance, calendar). Read the plan first, then the bible relevant to the work.

## Current state (keep this section fresh)

- **Last completed WO:** 4.4 — polish pass from Neal's playtest (**M4 complete**). FE cancel semantics (cancel undoes the move), `UnitStatsPanel` (Stats command + select-to-inspect enemies), supports view-once in battle (`SupportState.viewed`), Serra/armor/guard tuned down, menu/hub text clipping fixed. Kai–Kael conversation drafts (WO-4.2) still pending Neal's edit; SFX hooks deferred until audio assets exist.
- **Next WO:** 4.5 (battle_view refactor: extract UnitSpawner / action-menu controller / combat executor, zero behavior change). Then 4.6 dialogue branches → M5.
- **Art track (AW-7 v2 delivered 2026-07-04, awaiting Neal's pass):** three-tier hybrid — painted busts/splashes/environments (Corin-704 register, vivid rooms), **pixel sprites for everything that moves**, code juice. After Neal's bake-off verdict (pixel direction right, "more detail and flare", GBA-FE `sample/` refs are the bar — reference only, do not copy), **v2 rebuilt Kai at GBA-FE fidelity in both tiers**: battle-tier 48×64 (¾ sword-over-shoulder pose, flared crimson cape, material ramps, gold trim, temple mark, readable face) and map chibi 32×32 with a real 4-frame side walk (contact/passing alternation, cape sway, idle-bob pair f2/f4). Live frames: `assets/sprites/units/kai/walk_f1-4.png` (engine hook unchanged: `Unit` builds `SpriteFrames` at runtime, NEAREST, faces right / flip_h). **Review package for Neal: `assets/art_review/aw8_kai_v2/`** (8× renders, multi-scale card, sample-vs-ours comparison, walk strip + GIFs, in-engine zooms) + Artifact gallery. **Sprite source of truth = the coordinate-paint generators** in `assets/sprites/sources/generators/` (`python3 kai_battle.py` / `kai_map.py` re-render everything; palette dict in `kai_battle.py` is the base cast palette). `.aseprite` exports pending — the Aseprite MCP wedged on `app.open` (60s timeouts even after `launchctl kickstart -k gui/$(id -u)/com.neal.aseprite-mcp-pro`; likely needs the app foregrounded/restarted manually). Full v2 findings + in-engine driving notes (polled input needs `Input.action_press`, not injected key events; walk GIFs via injected `save_png` node): `STYLE_BIBLE.md` v6.1 header. Painted tier unchanged: R16 ComfyUI (`http://100.70.146.106:8188`, Tailnet), DreamShaperXL Turbo + Animagine XL 3.1, rembg alpha matting; recipes/traps in the bible §4–6. AW-1 still ⏳ awaiting final yes/no; AW-8 (full two-tier set) unblocks on Neal's AW-7 pass.
- **Tests:** 268/268 green, 44 scripts. The combat core (`src/combat/`) is the most-tested code; keep it that way. Tests must never write the real `user://saves` — inject `Campaign.save_system_override` (see test_hub) or pass an explicit `SaveSystem` with a test dir.
- **Protagonist:** Kai (id `kai`) — renamed from Ash in WO-4.1b. The lord flag lives on `data/units/kai.tres`; lord death = game over.
- **Campaign flow today:** title (`scenes/title/title.tscn`, the main scene) → New/Load → hub (`scenes/hub/hub.tscn`) → deploy → `scenes/battle/mock_battle.tscn` (Chapter 1) → victory back to hub / defeat back to title → hub "Return to Title" closes the loop. The menu hub gets replaced by a walkable castle in M6; its systems (`Campaign` autoload, `Roster`) are the keepers.
- **Dev saves:** JSON under `user://saves/` (macOS: `~/Library/Application Support/Godot/app_userdata/Vael Academy/saves/`). Considered disposable until the save payload stabilizes (M5–M7 grow it).

## Commands

```sh
# Run the full test suite (GUT) — the per-WO gate:
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Refresh Godot's import + global class cache (run after adding class_name scripts
# or resources, BEFORE headless test runs / game launches):
godot --headless --import

# Run the game:
godot            # main scene = the hub
godot res://scenes/battle/mock_battle.tscn   # straight into Chapter 1
```

## Conventions that are actually enforced

- **Typed GDScript everywhere**; logic/presentation split (pure classes in `src/core|combat|ai|progression|save`, nodes call into them); data as `.tres` resources; one `EventBus` autoload for cross-system signals. Full rules: MASTER_PLAN §2.
- **Combat formulas are law** (MASTER_PLAN §3) — implement exactly, tune via data. All combat RNG flows through the seedable `CombatRNG` (2RN hit / 1RN crit) so tests are deterministic.
- **One WO per session**, lowest-numbered with ✅ dependencies. Update §10 + this file, commit with the WO ID as the message. Content WOs (conversations, story) are co-written with Neal — draft, don't finalize.
- **Enum values in `Terrain.Type` and `ChapterDef.Objective` are persisted** — append, never renumber.

## Tooling notes for non-Claude agents

- Claude sessions drive the Godot editor via **Godot MCP Pro** (`.mcp.json` + `addons/godot_mcp`) for screenshots/playtesting/simulated input. **None of that is required**: everything is achievable with the CLI commands above plus direct file edits. The MCP autoloads (`MCPScreenshot`, `MCPInputService`, `MCPGameInspector`) in `project.godot` are harmless — leave them registered.
- **Authoring `.tres` resources:** don't hand-write complex ones (typed arrays/dictionaries have finicky serialization). Write a one-shot `extends SceneTree` script that builds the resources and `ResourceSaver.save()`s them, run it with `godot --headless -s res://<script>.gd`, then delete the script (see WO-4.1's data commit for the pattern).
- **`project.godot` is editor-owned** for autoloads/input/settings. If you must change those without the editor, edit carefully and run `godot --headless --import` after.

## Gotchas (each of these has already bitten once)

1. **Stale editor class cache.** A long-running Godot editor rewrites `.godot/global_script_class_cache.cfg` from its in-memory view on rescan; if it predates your new `class_name` scripts, every game it launches breaks. Fix: `godot --headless --import`, and restart the editor after WOs that add classes.
2. **Keyboard input on full-rect Control overlays** never arrives via `_gui_input` without focus — use `_unhandled_key_input` (see `ResultScreen`, `DialogueScene`).
3. **Awaiting a dialogue that finished synchronously hangs.** `DialogueScene.play()` on an empty/all-event script emits `finished` inside `play()`; check `is_finished()` before `await scene.finished` (see `battle_view._play_dialogue`).
4. **Shared `.tres` immutability:** `UnitDef`/`ClassDef` resources are cached by `load()` — never mutate them at runtime. Per-instance state (level-ups, promotion, inventory) lives on the `Unit` node; spawn paths `duplicate()` defs defensively.
5. **`Engine.time_scale`** is used for combat hit-stop — if a test/session dies mid-freeze it stays 0; battle `_ready` and `JuiceController._exit_tree` reset it defensively.

## Git / remote

- `origin` = private Forgejo on Neal's Tailnet (`http://100.120.211.122:3000/neal/vael-academy.git`). Push after every WO.
- Auth: username `neal` + token in the gitignored `.env` (`FORGEJO_TOKEN`). Push via a temporary `GIT_ASKPASS` helper that echoes the username/token — **never** put the token in the remote URL, git config, or any committed file.
- Commit style: `WO-<id>: <summary>` with a short bullet body.

## Where things live (quick map)

| Area | Files |
|---|---|
| Combat math/resolution (pure) | `src/combat/` — `combat_math.gd`, `combat_resolver.gd`, `combat_forecast.gd`, `combatant.gd`, `combat_rng.gd` |
| Grid/pathfinding/objectives (pure) | `src/core/` — `grid.gd`, `pathfinder.gd`, `movement_range.gd`, `objective_resolver.gd` |
| Battle orchestration (fat, refactor = WO-4.5) | `src/ui/battle_view.gd` |
| Between-battle state | `src/core/campaign.gd` (autoload `Campaign`), `src/core/roster.gd`, `src/save/save_system.gd` |
| Hub (menu — replaced by castle in M6) | `src/ui/hub_scene.gd`, `scenes/hub/hub.tscn` |
| Dialogue engine (linear; branches = WO-4.6) | `src/ui/dialogue_script.gd`, `dialogue_step.gd`, `dialogue_scene.gd` |
| Supports | `src/progression/support_state.gd`, `support_chain_def.gd`, `support_registry.gd`; data in `data/supports/` |
| AI | `src/ai/ai_brain.gd` (Aggressor/Sentinel/Boss) |
| Chapter data | `data/chapters/*.tres` (`ChapterDef`: terrain grid, objective, spawns, deploy cells, dialogue paths) |
| Cast | `data/units/*.tres`, `data/classes/*.tres`, `data/houses/*.tres` |
| Unit sprites (AW-7+) | `assets/sprites/units/<unit_id>/walk_f1-4.png` → runtime `SpriteFrames` in `src/units/unit.gd`; **sources = Python generators in `assets/sprites/sources/generators/`** (`python3 kai_map.py` re-renders the frames); review packages in `assets/art_review/aw8_kai_v2/` (current) and `aw7_bakeoff/` (superseded); `.aseprite` in `assets/sprites/sources/` are exports only |
