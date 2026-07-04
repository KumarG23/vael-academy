# PLAN_REWRITE_AUDIT.md — What We Keep, Adapt, and Replace

The pre-work for a large-portion `MASTER_PLAN.md` rewrite. Goal (Neal's framing): **keep the built work, reuse everything that fits the new direction, replace only what actively fights it — a big rewrite, not a restart.**

New direction, in one line: *walkable living castle (not a menu) · full house choice with three playable houses · romance · a bandit-raid prologue · a school-year calendar · Kai's magic as a slow reveal.*

Disposition legend:
- **KEEP** — untouched, works as-is.
- **ADAPT** — reused; extended or reflavored, architecture stands.
- **REPLACE** — *logic kept*, presentation layer swapped (the plan's own §2 logic/presentation split makes this cheap).
- **CUT** — removed. (Spoiler: nothing built is a pure CUT.)

---

## Part 1 — Built systems (the 245-test codebase)

| Built | Disposition | Why |
|---|---|---|
| MCP-Pro tooling | **KEEP** | Direction-agnostic. |
| 0.1 Skeleton, EventBus, GUT | **KEEP** | Foundation. |
| 0.2 Grid & map | **KEEP** | Every battle still stands on it. |
| 0.3 Cursor & selection | **KEEP** | Core. |
| 0.4 Units, pathfinding, movement | **KEEP** | Core. |
| 1.1 Combat math (`CombatResolver` etc.) | **KEEP** | The crown jewel. Untouched by any new feature. |
| 1.2 Forecast + execution | **KEEP** | Core. |
| 1.3 Turn manager & enemy phase | **KEEP** | Core. |
| 1.4 Win/loss objectives | **KEEP** | Core. |
| 2.1 XP & level-ups | **KEEP** | Core. |
| 2.2 Inventory & durability | **KEEP** | Core. |
| 2.3 Sentinel/Boss AI + threat overlay | **KEEP** | Core. |
| 2.4 Promotion | **KEEP** | Core. Kai's future magic-classes ride this system. |
| 2.5 Combat juice | **KEEP** | Core; only ever gains real art via AW-5. |
| 3.1 Dialogue engine | **ADAPT** | Reused *far more* now (castle scenes, romance). Needs **choices/branches** (currently "choices optional, not in slice") for romance and school events. Engine stands; we extend it. **Reuse win.** |
| 3.2 Support system | **ADAPT** | Already supports N pairs via data — so "not locked to Kael" is a *fiction* change, zero code. Add one **romance rank** past A (a threshold + a flag). Small extension, big payoff. |
| 3.3 Save/load & permadeath | **ADAPT** | Architecture stands; **payload schema grows** (house choice, calendar/date, castle state, romance flags, mini-game/exam progress). Extend, don't rebuild. |
| 3.4 House system (`HouseDef`) | **ADAPT** | Built for exactly this. Theming already data-driven. Change: "player house = fixed Emberwing" → **runtime choice**. Always designed as a data unlock. |
| **3.5 Academy Hub (menu)** | **REPLACE** | **The one real casualty — and only its front-end.** The *systems* survive intact: `Campaign` autoload (between-battle state + save/load), `Roster` builder, and the four functions (Common Hall / Training +10XP / Quartermaster / Mission Board). The **menu UI** is what the walkable castle replaces. Same logic, new presentation — the plan's §2 rule in action. |
| 4.1 Mock Battle (Chapter 1) | **ADAPT** | Map, non-lethal yield system, in-battle dialogue overlay, fort heal, DEFEAT_BOSS objective — all reused. Reframed as the **year's opening inter-house battle**. **Ash → Kai** is a reflavor of a slot that already exists (Ash was always the lord). No structural rebuild. |

**Bottom line: of everything built, exactly one presentation layer gets replaced. Nothing else is discarded.** The menu hub wasn't wasted work — it was the logic layer, built first on purpose, now dressed.

---

## Part 2 — Design sections (`MASTER_PLAN.md` §1–§11)

| Section | Disposition | Change |
|---|---|---|
| §1 Vision | **ADAPT** | Add the living-castle pillar, house choice, romance. Rewrite the "menu hub" line. Redefine the north-star (see Part 4). |
| §2 Tech stack & conventions | **KEEP** (+minor) | Add castle/exploration scene conventions; note dialogue-branch format for romance. |
| §3 Combat design & formulas | **KEEP** | Untouched. Kai's "learn any school" is a *future additive* WO, not a formula change. |
| §4 Character/Story/Academy | **REWRITE** | The big one. The menu-hub description, fixed-Emberwing, "one support pair," "house choice parked" all flip. Now points to the six bible docs. |
| §5 Enemy AI | **KEEP** | — |
| §6 Milestones & WOs | **ADAPT (major)** | Finish M4 (4.2/4.3/4.4 + reframed 4.1), then **new milestones**: house choice, castle shell, mini-games (one at a time), romance, prologue, calendar, Tidemark/Thornrook playable build-outs. |
| §7 How Neal runs Fable | **KEEP** (+minor) | Small updates. |
| §8 Art track | **ADAPT** | Add **castle-room backdrops** (same pipeline) + **full-cast portraits** (~18 characters vs. the slice's handful — a real art-scaling note). Reference triangle unchanged. |
| §9 Risks & standing decisions | **ADAPT** | New headline risk: school-life content sprawl. New standing rule: **build mini-games one at a time.** "Combat feel > feature count" still holds. |
| §10 STATUS | **KEEP** + append | Never delete rows; add new WO rows. |
| §11 Parking lot | **ADAPT** | Un-park: walkable hub, house choice, calendar, romance, (maybe) cross-house recruiting. The `battle_view.gd` fat-controller refactor stays parked but is now **more urgent**. Genuinely-parked items remain. |

---

## Part 3 — Genuinely new work (no existing system to reuse)

This is the actual remaining build, honestly named:
- **Castle exploration shell** — move through rooms, room transitions, walk up to an NPC and talk, trigger an activity. The one-time foundation everything else bolts onto.
- **House choice new-game flow** — mostly new UI over existing `HouseDef` data.
- **Prologue chapter** — new content, reuses all existing battle systems.
- **Romance** — small extension of the support system + branched dialogue.
- **Calendar / school-year system** — new; drives events, exams, holidays.
- **Mini-games** — fishing, cooking, quizzes, exams; **each its own small project, added one at a time.**
- **Tidemark & Thornrook as playable rosters** — new `.tres` cast + any house-specific kit; reuses all unit/class/combat systems. (See decision D2.)
- **Kai's magic progression** — future combat extension riding the promotion/class system. (See decision D4.)

---

## Part 4 — Decisions I need before rewriting

These change the *shape* of the rewritten plan. My recommendation on each — react / redirect:

**D1 — Menu hub: fully replace, or keep as a fallback?**
*Rec:* replace the menu presentation entirely with the castle; keep the underlying systems. (If you want a menu-style fast-travel *inside* the castle later, that's a cheap add — but the castle is the face.)

**D2 — When do Tidemark & Thornrook become playable?** House choice needs all three eventually. Two paths:
- (a) Build all three playable as part of un-parking house choice — most faithful to "pick any house," biggest single chunk.
- (b) Ship house choice with **Emberwing fully playable first**, other two coming online in later milestones — proves the fork, defers the bulk.
*Rec:* **(b).** Prove the choice mechanism and the castle loop with one complete house, then build the other two as their own milestones. Lower risk, same destination. (Story side — the bibles — is house-agnostic and done regardless.)

**D3 — New north-star ("the next slice").** The combat slice is essentially proven. I'd set the next target as the **"school slice"**: prologue → house choice → walkable castle with **one** working activity → opening inter-house battle → back to castle. Prove the *living-school* loop the way M0–M4 proved the *combat* loop.
*Rec:* adopt that as the milestone north-star; add mini-games past that one.

**D4 — Kai's magic progression: in the plan now, or parked?**
*Rec:* keep it a **named future WO** (so it's on the record and the class system stays aware of it), but sequence it *after* the school slice — it's a payoff feature, not a foundation.

---

## Part 5 — Preview: the rewritten milestone shape (react before I write it)

- **M4 (finish current):** 4.2 supports writing · 4.3 title/flow · 4.4 polish · 4.1 reframed as opening battle.
- **M5 — House choice + prologue:** new-game house-choice flow · bandit-raid prologue chapter · romance tier on the support system.
- **M6 — The living castle (shell):** exploration/movement · room scenes over the existing hub systems · NPC conversation placement · one flagship activity (**fishing**).
- **M7 — School life:** calendar/year system · additional activities (cooking, quizzes, exams) one at a time · holidays & parties · the two-battle year bracket.
- **M8 — Full house parity:** Tidemark & Thornrook playable rosters + kits + their support/romance webs.
- **M9+ — Beyond year one:** Kai's magic unlock arc · the mystery's escalation · Chapter 2 with real stakes.
- **Art track:** grows to cover castle-room backdrops + full-cast portraits; same pipeline, same dependency chain.

Numbers/letters are illustrative — the point is the *ordering*: finish combat → prove the school loop → scale to all three houses → escalate the story.

---

*Once you've reacted to D1–D4 and the Part 5 shape, I'll do the actual `MASTER_PLAN.md` rewrite against these calls.*
