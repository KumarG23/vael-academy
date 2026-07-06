# Vael Academy — Aseprite MCP Pixel Art Workflow

Use this skill whenever the task mentions Aseprite, pixel art, sprites, sprite sheets, animation frames, Kai/unit art, AW-7/AW-8, terrain tiles, house uniforms, buildings, campus avatars, or Godot sprite export.

## Project Context

Vael Academy is a Fire Emblem / Dark Deity style Godot tactics RPG. The current art plan is a three-tier hybrid:

1. Painted art for portraits, splashes, rooms, backdrops, and title art.
2. Animated pixel sprites for anything that moves: battle-map units, campus avatars, NPCs, attacks, hit/KO frames.
3. Code juice for combat presentation and UI polish.

For sprite work, read these before touching art:

- `HANDOFF.md` — current state, art-track gotchas, live asset paths.
- `STYLE_BIBLE.md` — sprite tier rules, palette rules, review history.
- `MASTER_PLAN.md` §8 and §10 — art work orders and status.

Do not work from memory. The bibles win.

## Current Sprite Pipeline

Current approved direction from `STYLE_BIBLE` / `HANDOFF`:

- GBA Fire Emblem fidelity/register.
- Small map sprites: readable chibi/unit scale, roughly 32px language.
- Battle/showcase sprites: 48–64px-ish, anatomy derived from sample bases when possible.
- Use `sample/` sprites as reusable/reference bases when appropriate; Neal cleared that reuse for this project.
- Coordinate-paint Python generators in `assets/sprites/sources/generators/` are the primary repeatable source pipeline.
- `.aseprite` files in `assets/sprites/sources/` are exports / cleanup artifacts unless the user explicitly says to make Aseprite the source of truth for that asset.
- Live unit frames currently consume `assets/sprites/units/<unit_id>/walk_f1-4.png` via `src/units/unit.gd`.
- Kai is priority until Neal passes him. Do not volume-produce the cast before Kai is approved.

## Single-Instance Rule

Aseprite MCP Pro supports one active Aseprite editor WebSocket at a time on `127.0.0.1:6515`. Multiple Aseprite app instances will fight each other and produce a connect/disconnect loop with `Replaced by new connection`. Before sprite work, check:

```bash
pgrep -fl '/Applications/Aseprite.app/Contents/MacOS/aseprite( |$)'
lsof -nP -iTCP:6515 -iTCP:8003
```

Keep one Aseprite process open. Do not launch files by repeatedly spawning `/Applications/Aseprite.app/Contents/MacOS/aseprite <file>` unless you have first closed the old instance. Prefer working through the existing connected editor/MCP session. If the loop appears, close duplicate Aseprite processes and restart the bridge:

```bash
launchctl kickstart -k gui/$(id -u)/com.neal.aseprite-mcp-pro
```

## Aseprite MCP Rules

You have access to Aseprite MCP Pro as `aseprite-mcp-pro`.

Use MCP tools for editor-side sprite work:

- Setup/inspection: `get_sprite_info`, `get_layers`, `get_frames`, `get_palette`, `get_sprite_screenshot`.
- Drawing: prefer `execute_script` for programmatic pixel work; use `put_pixels` for batches; avoid thousands of individual `put_pixel` calls.
- Palette: use `set_lospec_palette`, `set_palette`, `generate_color_ramp`, `set_fg_color`, `set_bg_color` where available.
- Animation: `add_frame`, `duplicate_frame`, `set_frame_duration`, `create_tag` / tag tools, validation tools.
- Export: `save_sprite`, `export_png`, `export_sprite_sheet`, `export_for_godot` when resource generation is actually desired.
- Analysis: use color stats, frame comparison, unused color detection, and animation validation before claiming done.

If MCP reports disconnected:

```bash
launchctl kickstart -k gui/$(id -u)/com.neal.aseprite-mcp-pro
```

Then re-check with:

```bash
claude-jarvis mcp list
```

Avoid `app.open` inside Aseprite Lua for existing files; it can spawn extra Aseprite instances. Prefer `Image{fromFile=...}` plus `Sprite()` / explicit image import patterns.

## Golden Rules for Vael Sprites

- Silhouette first. If it does not read at 1x/2x, details are decorative lies.
- Palette-lock per sprite; reuse the ramp dictionaries in existing generators when working on Kai.
- Derive anatomy/poses from approved/sample bases when possible; do not invent fragile anatomy freehand.
- Use house palette swaps for cape/jacket/gold/ring accents, not full random recolors.
- Keep transparent backgrounds for game frames.
- Generate 8x/16x review previews next to native frames when submitting art for Neal review.
- Test in-engine if the asset is meant to ship in Godot; sprites that look good in a zoomed PNG can fail the actual camera.
- Never overwrite existing approved/source assets without first creating a variant or backup filename.

## Recommended Work Loop

1. Read `HANDOFF.md`, `STYLE_BIBLE.md`, and relevant `MASTER_PLAN.md` AW status.
2. Inspect current sprite/generator paths with `git status` and `find assets/sprites assets/art_review`.
3. If editing existing generated art, update the Python generator first when practical, then export PNG/Aseprite outputs.
4. Use Aseprite MCP for pixel cleanup, palette validation, frame/tag setup, screenshots, and Godot-ready export.
5. Produce review artifacts:
   - native PNG frames
   - 8x/16x zoom sheets
   - animated GIF if motion changed
   - in-engine screenshot when feasible
6. Run Godot tests unless the task is strictly art-only and no imported resources/scripts changed:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

7. Report what changed, what was exported, where review images live, and any remaining subjective art calls for Neal.

## Do Not

- Do not start a normal coding work order just because you are doing art setup.
- Do not commit/push unless the active task explicitly asks for it or follows the WO completion contract.
- Do not treat `.aseprite` exports as canonical over the generator pipeline unless explicitly instructed.
- Do not use AI image generation outputs directly as sprites without cleanup, palette locking, and in-engine validation.
- Do not claim animation quality from files existing alone; inspect/capture frames.


## Multi-Agent Contention

Do not run multiple AI agents against Aseprite MCP simultaneously. Claude, Codex, and Antigravity may all be useful on Vael, but Aseprite MCP itself is a single-writer/single-editor resource. Pick one art driver. Other agents may review files or give critique, but must not call Aseprite MCP tools or launch Aseprite while the art driver is active.

Agents must not launch `/Applications/Aseprite.app/Contents/MacOS/aseprite <file>` repeatedly. That spawns extra editor instances and causes the 6515 WebSocket churn.
