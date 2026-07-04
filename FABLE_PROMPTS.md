# FABLE_PROMPTS.md — kickoff prompts for Claude Code

Two prompts. Use **Prompt 1 first** (Fable reviews the rewritten plan against the actual codebase and suggests changes — no building). Once you've reconciled its feedback and the plan is final in the repo, **Prompt 2** is the normal per-session driver.

---

## Prompt 1 — Plan review (first session, plan mode, NO code)

> We've done a large-portion rewrite of `MASTER_PLAN.md` plus eight companion story bibles (`WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`, and five `CHARACTER_BIBLE_*.md`). Before any building, I want your review.
>
> Stay in **plan mode — do not write or modify any code, resources, or tests this session.**
>
> 1. Read `MASTER_PLAN.md` in full, then the eight bibles.
> 2. Cross-check the plan against the **actual current codebase and the §10 STATUS table.** Verify the "keep / adapt / replace" claims in `PLAN_REWRITE_AUDIT.md` are accurate — especially: that the WO-3.5 hub systems (`Campaign` autoload, `Roster` builder, the four hub functions) really are reusable as the castle backend, and that nothing in the new milestones (M5–M8) contradicts what's actually built.
> 3. Flag anything that's **mis-scoped, out of dependency order, or technically wrong** — for example: is the M5 house-roster work correctly ordered after 5.2? Does the dialogue engine (WO-3.1) actually need new work to support the branches M5.7/M6 assume? Is the `battle_view.gd` refactor (§11) a true blocker for the castle work in M6, and if so should it be its own numbered WO *before* M6?
> 4. Note any WO you think is too big for one session and should be split, and propose the split.
> 5. Give me a short written review with concrete suggested edits to the plan. **Do not implement anything.**
>
> Goal: make sure the plan is technically sound and the reuse assumptions hold before we start executing it.

---

## Prompt 2 — Normal per-session build (after the plan is final)

> Read `MASTER_PLAN.md` first, then any bible relevant to this work order. Implement exactly one work order — the lowest-numbered WO whose dependencies are ✅ in §10, unless I tell you otherwise. Obey the §2 coding rules and §3 formulas as written. For content WOs (supports, romance, prologue, house pitches), read the relevant `CHARACTER_BIBLE_*.md` / `CAMPAIGN_STRUCTURE.md` first and co-write with me rather than inventing. Finish by running the tests, confirming acceptance criteria, updating §10 STATUS, and committing with the WO ID as the message. Stop after one work order.

---

### Note on the first few work orders
The lowest-numbered open WOs are **4.2 (support conversations)**, **4.3 (title/flow)**, **4.4 (polish)** — the finish of the combat slice. Those are the natural next builds. **4.2 and the prologue (5.1) are co-write WOs** — bring them into chat with me rather than letting Fable one-shot them. The house-roster WOs (5.3–5.5) are content-heavy but mechanical; good candidates for Fable to draft and us to review.
