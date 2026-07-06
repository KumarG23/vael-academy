# Aseprite MCP readiness check for Vael Academy

Run this before any Vael Academy sprite/art session:

1. Read `HANDOFF.md`, `STYLE_BIBLE.md`, and `MASTER_PLAN.md` §8/§10 art status.
2. Check `git status --short --branch`; do not stomp existing art review changes.
3. Confirm MCP servers:
   - `claude-jarvis mcp list`
   - `aseprite-mcp-pro` must be connected at `http://127.0.0.1:8003/mcp`.
   - `godot-mcp-pro` should be connected for in-engine validation.
4. If Aseprite MCP is down, run:
   - `launchctl kickstart -k gui/$(id -u)/com.neal.aseprite-mcp-pro`
5. Use the `Vael Academy — Aseprite MCP Pixel Art Workflow` skill.
6. For sprite work, prefer generator-first edits under `assets/sprites/sources/generators/`, then Aseprite MCP cleanup/export/review artifacts.
7. End by listing exact output paths and whether the asset was tested in-engine.
8. Confirm there is exactly one active Aseprite process. Multiple instances cause the 6515 websocket to churn with `Replaced by new connection`. Use:
   - `pgrep -fl '/Applications/Aseprite.app/Contents/MacOS/aseprite( |$)'`
   - `lsof -nP -iTCP:6515 -iTCP:8003`
