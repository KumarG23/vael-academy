# AGENTS.md

Current delivery workflow: read `docs/TEAM_WORKFLOW.md`. GitHub issues → branches → PRs → checks → lead review → merge replaces the former Forgejo/Studio task orchestration. Ordinary development uses full native tools and self-repair; no exact-file permission cages or arbitrary turn caps. A lead-assigned issue takes precedence over automatically choosing the lowest-numbered work order, but never silently overrides game scope or canon.

Start with `HANDOFF.md` (project state, commands, tooling notes, gotchas), then `MASTER_PLAN.md` — the single source of truth; its §10 STATUS table says what's done and what's next.

Work contract (same as CLAUDE.md, which Claude-family agents use):

- Implement **exactly one work order per session** — the lowest-numbered WO in §10 whose dependencies are ✅, unless told otherwise.
- Obey MASTER_PLAN §2 coding rules and §3 combat formulas as written.
- **Reference the owning document for whatever you're working on:** story/character content → `WORLD_BIBLE.md` / `ACADEMY_BIBLE.md` / `CAMPAIGN_STRUCTURE.md` / `CHARACTER_BIBLE_*.md`; direction rationale → `PLAN_REWRITE_AUDIT.md`; tooling/state → `HANDOFF.md`.
- Content WOs (conversations, story) are **co-written with Neal** — produce drafts for his edit, don't finalize alone.
- Finish by running the test suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), confirming the WO's acceptance criteria, updating §10 STATUS and `HANDOFF.md`, and committing with the WO ID as the message.

Note: Claude sessions use Godot MCP Pro for editor automation; it is optional. Everything needed is achievable via the CLI commands in `HANDOFF.md`.

## Working alongside other agents (Claude ↔ Codex ↔ others)

Two agents, two modes — pick one per session:

1. **Implementer / Reviewer (preferred).** One agent implements WOs; the other
   audits a NAMED GREEN COMMIT and files findings in `AUDITS.md` (format is in
   that file). The implementer triages findings into WOs. Roles can swap
   between sessions (e.g., when one model's usage resets).
2. **Parallel work.** Only in separate `git worktree`s on separate branches,
   synced through the GitHub remote. Never two agents editing one checkout —
   a mid-WO tree doesn't even parse, and an audit of it reports phantoms.

Hard rules either way:
- **One writer per MCP.** Aseprite MCP (see below), and equally the Godot
  editor MCP bridge — one agent connected at a time.
- **Base off the last green commit** (suite passing, §10/HANDOFF updated).
  Commit-per-WO is the handoff unit; don't hand over a red tree.
- `MASTER_PLAN.md` §10 + `HANDOFF.md` are the shared product brain. GitHub PR
  comments carry current review findings; `AUDITS.md` preserves durable findings.
  Update the documents affected by the actual work, not all three by ritual.
- Story/design calls are Neal's. An audit may PROPOSE (in AUDITS.md); it never
  rewrites bibles or canon.

## Aseprite MCP / Sprite Art

For Vael Academy sprite work, use the project skill `.claude/skills/vael-academy-aseprite-pixel-art.md`. Aseprite MCP Pro is configured as `aseprite-mcp-pro` at `http://127.0.0.1:8003/mcp`; Godot MCP Pro remains configured for in-engine validation. Read `HANDOFF.md`, `STYLE_BIBLE.md`, and `MASTER_PLAN.md` §8/§10 before art work. Current sprite pipeline is generator-first (`assets/sprites/sources/generators/`) with `.aseprite` files as exports/cleanup artifacts unless Neal explicitly promotes one to source-of-truth.

Aseprite MCP single-writer rule: do not run Claude, Codex, and Antigravity against Aseprite MCP at the same time. Aseprite MCP Pro has one editor WebSocket on `127.0.0.1:6515`; multiple Aseprite instances or simultaneous art agents cause connect/disconnect loops. Use exactly one art agent at a time, keep one Aseprite process open, and do not launch `/Applications/Aseprite.app/Contents/MacOS/aseprite <file>` from agents unless old instances are closed first.
