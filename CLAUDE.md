Read MASTER_PLAN.md first — it is the single source of truth for *how this is built*.

**Reference the owning document for whatever you're working on; don't work from memory of it.** Story/character/world content → the bibles (WORLD_BIBLE, ACADEMY_BIBLE, CAMPAIGN_STRUCTURE, CHARACTER_BIBLE_*). Direction rationale / what was kept vs. replaced → PLAN_REWRITE_AUDIT.md. Project state, tooling, and gotchas → HANDOFF.md. System details → the relevant §10 STATUS notes and the code itself.

Implement exactly one work order per session — the lowest-numbered WO whose dependencies are ✅ in §10, unless told otherwise. Obey §2 coding rules and §3 formulas as written. For content WOs (supports, romance, prologue, house pitches), co-write with Neal rather than inventing; drafts are for him to tear apart.

Finish every WO by: running the tests, confirming acceptance criteria, updating §10 STATUS, **updating HANDOFF.md** (current state + anything a non-Claude agent would need to continue), and committing with the WO ID as the message.
