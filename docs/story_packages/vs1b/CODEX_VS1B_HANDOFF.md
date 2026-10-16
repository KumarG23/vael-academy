# Codex handoff — Vael Academy VS-1B, approved story direction / draft v1

The user has approved the core intent of these scene drafts, but line-by-line dialogue and all generated art remain subject to in-engine review. This is *not* a license for wholesale canon rewrite.

Read `AGENTS.md`, `HANDOFF.md`, `MASTER_PLAN.md`, story bibles and the adjacent `STORY_AND_ART_PACKAGE.md` first. Current known baseline after VS-1A: commit `f0c43294`. Verify the active branch and uncommitted edits. Follow the repository's one-WO-per-session / one writer per MCP rule.

## Work order VS-1B: implement the co-written opening beats, not the full academy oath redesign

1. Open `dialogue_drafts/prologue_home_morning.json`, `prologue_road_waystation.json`, `road_bandit_intro.json`, and `road_bandit_outro.json`. These are first-pass text drafts. Preserve the approved kitchen lines and ensure first-time strangers remain strangers. Do not silently introduce an all-heirs traveling party, archers, or extra combat troops.
2. Check the latest JSON parser, `PrologueVN` playlist, `ChapterDef` and `BattleView` intro/outro functions. Integrate home first, handoff after Hesta's goodbye, intro before the playable existing bandit fight, aftermath before oath. `data/chapters/prologue.tres` already points at road intro/outro. The road outro file was not found on GitHub during drafting: verify and create it.
3. Use Gemini or the established Vael painted-art generation pipeline **for production-quality story stills**, not placeholder stock graphics. Read the art briefs below. Prioritize character likeness, emotion, hand interactions, and in-engine legibility; work iteratively until the panels look right. The user explicitly values quality and story feel above minimizing number of art generations. Do not assume a particular external account/model entitlement; use available configured generator. Save prompts, source refs, versions and approved assets. Do not silently alter approved pixel-world versus illustrated-battle style.
4. Give the quiet bread scene its own painted image with Kai handing bread to the survivor in the *background*, portraits overlaid for dialogue. If the existing overlay obscures the emotional gesture or creates awkward duplicates, make the smallest isolated presentation refinement and test it. Do not reimplement the VN engine.
5. Ensure the boy's mark appears only **after** the cave and can flicker involuntarily in this chapter. Player-usable Crownspark is a known progression defect; treat it as a **separately scoped follow-up** if not safely addressable without violating one-WO scope or save compatibility. Do not conflate mark with controlled magic.
6. Verify the actual prologue has four allied units and five axe bandits, child evacuated before map control, hero/escort continuity and no promised unattached escort NPC. Preserve original map layout and existing combat math, RNG, objectives, rewards, savestate, all three house routes.
7. Do not implement the gate/house pitches from VS-1C drafts yet. They are references for a later co-write pass. Avoid over-explaining Morvane or the First Crown; keep Hesta's true reasons implicit.
8. Capture native-size screenshots / short playback of every story tableau, especially before/after line transitions and portraits; run focused opening tests plus full GUT; test full New Game through road battle and aftermath to house-choice entry, plus save/resume and house variations. Report any inability to obtain an actual graphic capture.
9. Update `MASTER_PLAN.md`, `HANDOFF.md`, and audit record; finish with one committed and pushed WO only after tests pass. Summarize source costs and any missing assets or unresolved story decisions clearly.

## Independent creative gate

Before changing code, present a short implementation plan mapping each scene to the existing runtime paths and showing all planned painted stills. The design text is a draft, not finalized canon. If you discover a hard contradiction with a locked July 10 ruling, stop *that creative decision*, flag it and continue with unaffected approved work; do not invent a lore patch.

## Later and optional (DO NOT combine with VS-1B)

- VS-1C: Academy gate/roll-call scene, all three invitations heard before the binding decision, house-neutral humane reception, and route-aware Opening Rite intros.
- Separate Crownspark timing/migration repair, as established in the character bible.
- PixelLab MCP VFX Creator pilot for one tasteful map-level mark flicker or ember effect, not a blanket adoption in painted VN or illustrated battle.

Review result should answer: Did Kai feel like a real boy from an ordinary home? Did all three heirs earn a first impression independently? Does the bread shot carry the emotional payoff? Does the moment make the player want to reach Vael?
