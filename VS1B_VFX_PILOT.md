# VS-1B — PixelLab connection and road fire

Neal explicitly expanded this work order during review: repair PixelLab VFX MCP
access and put pixel effects on the road battlefield. This supersedes the
package's “future experiment only” boundary for **one existing burning cottage**.
No broad VFX rollout, new magic ability or combat rule is included.

## Connection repair

The old client unconditionally read missing `~/.claude.json`. It now reads
`PIXELLAB_API_KEY` / `PIXELLAB_TOKEN` from environment or gitignored project `.env`,
with the legacy Claude configuration retained as fallback. Gemini's key is never
used for PixelLab. Neal supplied the separate PixelLab key locally.

`tools/pixellab_mcp_stdio.py` adapts the existing authenticated HTTP MCP client to
stdio. Tool schemas/results come from PixelLab, not invented REST endpoints.
Project `.mcp.json` and local Codex MCP registration point at this adapter; no
credential in tracked config or command arguments. The active session used the
project client; newly opened sessions can attach the registered native server.
Read-only stdio handshake and live `tools/list` verified both VFX tools. Six
synthetic Python credential/transport regressions use no live account or spend.
Registration follows [official Codex MCP documentation](https://developers.openai.com/codex/mcp/).

## Delivered pilot

- Job: `2985bcb7-2b88-4e0a-a348-797a48273304`.
- Saved effect: `290ff01a-7ee3-4c12-a63e-1b9da4d9a9b0`,
  [PixelLab effect editor](https://pixellab.ai/create-vfx?effect=290ff01a-7ee3-4c12-a63e-1b9da4d9a9b0).
- `create_vfx`, **pro**, `game_pack=true`, using the actual existing
  `house_burning.png` as sprite reference. **Quoted and charged 8 generations.**
- 12 frames / 10fps / 1.2s loop. Transparent whole-effect and separate
  fire/smoke/ember sheets; original building remains the preview subject.
- Pack canvas96×112, feet anchor(48,96). Effect-only whole frames40×59,
  native offset(-20,-86); source cottage64×80. Exact anchoring retained.
- Production uses the **effect-only** `whole.png`, never the baked sprite preview.
  `data/vfx/road_cottage_fire.tres` keeps frame timing/regions. `MapDecor` has
  optional effect frames/offset; `TerrainTiles` animates only maps that use them.
  Existing house at(11,7) is unchanged, nearest filtering and integer map scale.

Sources, live schema, prompt/reference hash, original downloads, manifest,
receipts and connection proof: `assets/source/pixellab/vs1b_fire/`.
`tools/build_road_fire.gd` reproduces the SpriteFrames export.

## Boundary and next uses

The visual clock is cosmetic, never saved and never consumes combat RNG; it
restarts on a scene load. No units, terrain, objective, HP, uses, calendar or
campaign flags change. Ordinary maps without an effect retain event-driven
redraw. Effects draw with the building behind map units/cursor/threat UI.
Native footage checks roof alignment, loop motion and threat readability;
regressions check manifest regions/timing/anchors and unchanged campaign/terrain.

This proves one reusable pixel-world asset path. Future magic, impact, seal,
weather or broader burning-district effects need separate art/design review.
The proposed anatomical-left-brow flicker still needs a native-scale proof and
must never suggest early controlled Crownspark. Painted VN and illustrated
battle art remain their existing pipelines.

[Official PixelLab MCP documentation](https://api.pixellab.ai/mcp/docs) records
creation/retrieval, sprite references, revisions and game-pack exports. The live
schema was also retrieved and saved; quoted cost takes precedence over guesses.
