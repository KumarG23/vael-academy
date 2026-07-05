# HANDOFF.md — agent handoff & project state

For any coding agent picking this project up (Codex, a fresh Claude session, or a human).
Updated at the end of every work order (MASTER_PLAN §2 rule 8). **Last updated: 2026-07-04, after the PixelLab pipeline test (PixelLab is now the primary sprite generator).**

## What this is

A Fire Emblem–style 2D tactics RPG ("Emberline Tactics", working title) in **Godot 4.7 / typed GDScript**, built one work order at a time against `MASTER_PLAN.md` — the single source of truth for scope, formulas, and status (§10 is the live status table). Narrative canon lives in the story bibles: `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`, `CHARACTER_BIBLE_*.md`. `PLAN_REWRITE_AUDIT.md` records the 2026-07 direction change (menu hub → walkable castle, house choice, romance, calendar). Read the plan first, then the bible relevant to the work.

## Current state (keep this section fresh)

- **Last completed WO:** 4.7 — multi-direction + variable-frame unit sprites (`Unit.scan_walk_frames` / `idle_frame_indices`, walk_n/walk_s support, per-segment direction switch; Kai runs his full 9-frame PixelLab walk; 275 tests). New WOs 4.8 (outfit/variant hook) and 4.9 (battle pop-up scene) added to §10 per Neal; 4.5 (battle_view refactor) reserved for a dedicated session. **AW-2/P3 blocked on Neal's tilesets-vs-painted-maps decision (flagged in §10).** Portrait tier: Animagine standard + acceptance bar locked (STYLE_BIBLE v6.4). Prior: 4.4 — polish pass from Neal's playtest (**M4 complete**). FE cancel semantics (cancel undoes the move), `UnitStatsPanel` (Stats command + select-to-inspect enemies), supports view-once in battle (`SupportState.viewed`), Serra/armor/guard tuned down, menu/hub text clipping fixed. Kai–Kael conversation drafts (WO-4.2) still pending Neal's edit; SFX hooks deferred until audio assets exist.
- **Next WO:** 4.5 (battle_view refactor: extract UnitSpawner / action-menu controller / combat executor, zero behavior change). Then 4.6 dialogue branches → M5.
- **AW-8 PHASE 1 (2026-07-04, in progress): slice cast via PixelLab.** Artisan tier subscribed (5,000 gens/mo; **max 10 concurrent jobs** — creations spawn 2 jobs each, stagger batches). Seven cast characters generating: Kael, Brenna, Wren, Serra (named — designs are DRAFT PROPOSALS, bibles define personality/palette only; Serra anchored to her AW-1 portrait) + tm_soldier/tm_knight/tm_mage (cover the five tm_* units: guard/scout/soldier→soldier, armor→knight, adept→mage). Character ids in `assets/source/pixellab/*/character_info.txt`; orchestration tooling in `assets/source/pixellab/tools/` (`cast_orchestrator.py` pattern: queue-with-retry → poll → animate walk east → authenticated zip download). World-build plan of attack (P1 cast → P2 combat kits w/ Tier-2 skeleton animation → P3 Wang terrain tilesets → P4 campus/hub buildings for M6 → P5 UI/font): MASTER_PLAN §10 AW-8 row.
- **PIXELLAB (2026-07-04, Neal's new direction — primary sprite generator):** Neal found PixelLab, tested it himself (`sample/kai-pixellab.aseprite`, a full 73-frame asset kit), and Hermes added the MCP + workflow skill (`.claude/skills/`, CLAUDE.md pointer). **Full pipeline proven on Kai:** prompt → v3 character (8 dirs, 2 gens) → walk + sword-slash animations (1 gen/dir; template walk went off-model — delete + retry `mode="v3"`) → shared-window 32×32 crops → in-engine validated → FE-style **combat pop-up mock** built from the attack frames (`assets/art/pixellab/kai/combat_popup_mock.gif`). Raw output: `assets/source/pixellab/kai_map_v1/` (character id `471c7fb8-…` persists server-side for more animations/states); engine-ready: `assets/art/pixellab/kai/`; source: `sources/kai_pixellab_v1.aseprite` (26f, tagged); tools (HTTP MCP client, frame processor, combat mock): `assets/source/pixellab/tools/`. **Budget: trial acct, 12/40 generations left** — full Kai kit needs ~10–15; subscription decision before rolling the cast. PixelLab Kai NOT yet live in engine paths (committed frames restored after test; one-copy promote on Neal's word). Pipeline details: STYLE_BIBLE v6.3 header. Hermes also has an uncommitted v4 hand-pipeline pass in the tree (`aw8_kai_v4/`, `kai_*_v4.py`) — not mine, left untouched.
- **Art track (AW-7 v3 delivered 2026-07-04, awaiting Neal's pass):** three-tier hybrid — painted busts/splashes/environments (Corin-704 register, vivid rooms), **pixel sprites for everything that moves**, code juice. Neal's v2 review: **walk cycle passed**; hand-built battle sprite failed on anatomy; chibi hair read as two heads; and he **cleared `sample/` for direct reuse** ("steal pieces" — the sprites were Reddit-shared for others to use; supersedes reference-only). **v3: battle-tier Kai 57×49 derived from the sample sword-lord base** — descale to true res → HSV material classification (+ positional rules) → despeckle → luminance→6-stop ramps → mirror → face/temple-mark/crimson-headband identity redraw. Chibi head unified via the **headband device**; walk timing untouched. **Outfit variants as data** (`OUTFITS` in `kai_map.py`): battle live at `assets/sprites/units/kai/walk_f1-4.png`, school + gatherer at `assets/sprites/units/kai/variants/<outfit>_f1-4.png` (no engine hook yet — hub/castle will need one). **Review: `assets/art_review/aw8_kai_v3/`** (8×, scales, derivation card, variant strips/GIFs, in-engine zoom) + gallery artifact. Sources: generators in `assets/sprites/sources/generators/` (`kai_battle_v3.py` = derivation pipeline, `kai_map.py` = chibi + variants) **plus `.aseprite` exports** (`sources/kai_battle_v3.aseprite`, `kai_map_walk_v3.aseprite`). Aseprite MCP works after Neal accepted access — if "not connected", `launchctl kickstart -k gui/$(id -u)/com.neal.aseprite-mcp-pro` and avoid `app.open` (spawns extra instances; use `Image{fromFile=...}` + `Sprite()` instead). In-engine driving notes in STYLE_BIBLE v6.1/6.2 headers. **Neal's named art backlog: house uniforms, terrain tiles, buildings, rest of cast — Kai stays priority until passed ("he is the main character it has to be perfect").** Painted tier unchanged (R16 ComfyUI, recipes in bible §4–6). AW-1 still ⏳; AW-8 unblocks on the AW-7 pass.
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
| Unit sprites | `assets/sprites/units/<unit_id>/walk_f1-4.png` → runtime `SpriteFrames` in `src/units/unit.gd` (**Kai's live frames = PixelLab walk, frames 1/3/5/7 of 9**); PixelLab raw in `assets/source/pixellab/<name>_v1/`, engine-ready in `assets/art/pixellab/<name>/`; `.aseprite` exports in `assets/sprites/sources/` (2026-07-04 cleanup: all pre-PixelLab art removed — bake-off/v2/v3/v4 review folders, generators, old .aseprite, standee art, hand variants; standee hook in `unit.gd` remains as inert dev fallback) |
