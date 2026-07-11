Read MASTER_PLAN.md first — it is the single source of truth for *how this is built*.

**Reference the owning document for whatever you're working on; don't work from memory of it.** Story/character/world content → the bibles (WORLD_BIBLE, ACADEMY_BIBLE, CAMPAIGN_STRUCTURE, CHARACTER_BIBLE_*). Direction rationale / what was kept vs. replaced → PLAN_REWRITE_AUDIT.md. Project state, tooling, and gotchas → HANDOFF.md. System details → the relevant §10 STATUS notes and the code itself.

Implement exactly one work order per session — the lowest-numbered WO whose dependencies are ✅ in §10, unless told otherwise. Obey §2 coding rules and §3 formulas as written. For content WOs (supports, romance, prologue, house pitches), co-write with Neal rather than inventing; drafts are for him to tear apart.

Finish every WO by: running the tests, confirming acceptance criteria, updating §10 STATUS, **updating HANDOFF.md** (current state + anything a non-Claude agent would need to continue), and committing with the WO ID as the message.

## Aseprite MCP / Sprite Art

For Vael Academy sprite work, use the project skill `.claude/skills/vael-academy-aseprite-pixel-art.md`. Aseprite MCP Pro is configured as `aseprite-mcp-pro` at `http://127.0.0.1:8003/mcp`; Godot MCP Pro remains configured for in-engine validation. Read `HANDOFF.md`, `STYLE_BIBLE.md`, and `MASTER_PLAN.md` §8/§10 before art work. Current sprite pipeline is generator-first (`assets/sprites/sources/generators/`) with `.aseprite` files as exports/cleanup artifacts unless Neal explicitly promotes one to source-of-truth.

Aseprite MCP single-writer rule: do not run Claude, Codex, and Antigravity against Aseprite MCP at the same time. Aseprite MCP Pro has one editor WebSocket on `127.0.0.1:6515`; multiple Aseprite instances or simultaneous art agents cause connect/disconnect loops. Use exactly one art agent at a time, keep one Aseprite process open, and do not launch `/Applications/Aseprite.app/Contents/MacOS/aseprite <file>` from agents unless old instances are closed first.

## Chatterbox Narration

For narrator and voice-asset generation, use the project skill `.claude/skills/chatterbox-narration.md` and `python3 tools/chatterbox_narrate.py`. Chatterbox runs on ai-box over the private tailnet. Generate WAV files as build-time assets under `assets/audio/narration/`; never make the shipped game depend on the live service. Use the `default` voice for distributable prototypes unless Neal explicitly approves another voice and its rights.

## Kokoro Narration

For fast narrator generation and engine comparisons, use `.claude/skills/kokoro-narration.md` and `python3 tools/kokoro_narrate.py`. Kokoro runs CPU-only on big-ai over the private tailnet. Keep Kokoro tests under `assets/audio/narration/kokoro/`, preserve engine/voice names in comparison assets, and never silently replace an approved clip.
