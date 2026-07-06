# AGENTS.md

Start with `HANDOFF.md` (project state, commands, tooling notes, gotchas), then `MASTER_PLAN.md` — the single source of truth; its §10 STATUS table says what's done and what's next.

Work contract (same as CLAUDE.md, which Claude-family agents use):

- Implement **exactly one work order per session** — the lowest-numbered WO in §10 whose dependencies are ✅, unless told otherwise.
- Obey MASTER_PLAN §2 coding rules and §3 combat formulas as written.
- **Reference the owning document for whatever you're working on:** story/character content → `WORLD_BIBLE.md` / `ACADEMY_BIBLE.md` / `CAMPAIGN_STRUCTURE.md` / `CHARACTER_BIBLE_*.md`; direction rationale → `PLAN_REWRITE_AUDIT.md`; tooling/state → `HANDOFF.md`.
- Content WOs (conversations, story) are **co-written with Neal** — produce drafts for his edit, don't finalize alone.
- Finish by running the test suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), confirming the WO's acceptance criteria, updating §10 STATUS and `HANDOFF.md`, and committing with the WO ID as the message.

Note: Claude sessions use Godot MCP Pro for editor automation; it is optional. Everything needed is achievable via the CLI commands in `HANDOFF.md`.

## Aseprite MCP / Sprite Art

For Vael Academy sprite work, use the project skill `.claude/skills/vael-academy-aseprite-pixel-art.md`. Aseprite MCP Pro is configured as `aseprite-mcp-pro` at `http://127.0.0.1:8003/mcp`; Godot MCP Pro remains configured for in-engine validation. Read `HANDOFF.md`, `STYLE_BIBLE.md`, and `MASTER_PLAN.md` §8/§10 before art work. Current sprite pipeline is generator-first (`assets/sprites/sources/generators/`) with `.aseprite` files as exports/cleanup artifacts unless Neal explicitly promotes one to source-of-truth.

Aseprite MCP single-writer rule: do not run Claude, Codex, and Antigravity against Aseprite MCP at the same time. Aseprite MCP Pro has one editor WebSocket on `127.0.0.1:6515`; multiple Aseprite instances or simultaneous art agents cause connect/disconnect loops. Use exactly one art agent at a time, keep one Aseprite process open, and do not launch `/Applications/Aseprite.app/Contents/MacOS/aseprite <file>` from agents unless old instances are closed first.
