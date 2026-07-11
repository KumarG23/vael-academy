# AUDITS.md — cross-agent findings inbox

Any agent (Claude, Codex, or other) that audits the project files its findings
HERE, against a named commit. The implementing agent triages each finding into
a WO, marks the outcome, and leaves the row — this file is append-and-annotate,
never rewrite history. Rules of engagement live in `AGENTS.md`.

**How to file:** one row per finding, with the commit audited, the file:line,
and a one-line failure scenario. **How to close:** the fixer adds the WO id and
outcome. Design/content findings go to the *Deferred* table with an owner
(usually "co-write" — Neal decides story/design).

---

## Audit: Codex 5.6 sol — 2026-07-09, audited at AW-72 (496/496 green)

### Mechanical findings → fixed in AW-76 (all six CONFIRMED)

| # | Finding | Site | Outcome |
|---|---|---|---|
| 1 | Prologue victory advanced Week 1→2 via `Campaign.capture()` before Kai reaches Vael | `src/core/campaign.gd` capture() | ✅ AW-76 — victory only advances the calendar when `house_locked` (the year is underway) |
| 2 | "Rest until next week" skipped required battles unconditionally | `castle_scene.gd _rest_week` | ✅ AW-76 — resting on a BATTLE week refuses with a toast until the mission is answered |
| 3 | Journal saves wrote raw `Campaign.to_dict()`; loader requires `{"campaign": ...}` — slots looked occupied but couldn't load | `academy_journal.gd _do_save` | ✅ AW-76 — saves route through `Campaign.save_to_slot` (+ round-trip test) |
| 4 | Journal tests wrote/deleted the player's REAL slot 2 (`user://saves`) | `tests/test_academy_journal.gd` | ✅ AW-76 — tests use a per-run temp save dir |
| 5 | Battlefield grades never counted casualties (the dead leave `_units` before the headcount) | `battle_view.gd _end_battle` | ✅ AW-76 — `_fielded_at_start` snapshot at deployment, carried through save payloads |
| 6 | Semester 2 never closed — no year-end report card/ceremony | `campaign.gd advance_week` | ✅ AW-76 — both semesters close (`semester <= 2`) |

### Story/design findings → co-write agenda (Neal decides)

| Finding | Where it goes |
|---|---|
| Canon conflict: Kai carries the sword into the cave, but his parents later unwrap and gift the same sword (`CHARACTER_BIBLE_KAI.md:29` holds both) | COWRITE_PLAN §H |
| Canon conflict: plan says sword-only Kai with involuntary magic in the opening slice, but he starts with usable Crownspark | COWRITE_PLAN §H |
| Thematic risk: "belonging is built, not inherited" vs. Kai secretly having the most important bloodline — story must confront it (proposed resolution: blood opens the door; what he protects determines whether the power answers) | COWRITE_PLAN §A note / STORY_CRAFT rules |
| Route parity is mechanical: all three houses share Emberwing's `mock_battle_intro/outro.json` | COWRITE_PLAN §G (route-aware dialogue) |
| Closing Rite reuses the opening map/structure — harder, not different; no climax | Backlog (post-co-write map WO) + COWRITE_PLAN §B (W6 beat) |

### Engineering findings → backlog (real, not urgent)

| Finding | Status |
|---|---|
| Nilu roster parity: Thornrook fields an extra unit when player-chosen; rival Thornrook omits her; free-deploy/Rina-retreat rules unimplemented | Backlog — pair with the house-aware enemy spawning follow-on (AW-30 known limit) |
| Only 2 support chains vs 32 units — breadth without authored depth | Co-write §F produces the pair matrix; drafting follows |
| Kai's spell pace: weekly 4-question quizzes shouldn't ladder every school; reserve spellbooks for exams/bosses/story | Design dial — co-write §G/H |
| Enemy AI: no healer/support behavior, weapon selection, formations, chapter goals | Backlog (M8-adjacent) |
| M9 presentation debt: title identity, pixel font, settings persistence, music breadth, transitions, Dev Jump gating | Tracked in MASTER_PLAN M9 |
| `battle_view.gd` (~1,650 lines) and `castle_scene.gd` (~1,200) regrown past comfortable size | Backlog — second extraction pass before big content scale-up |
| One end-to-end integration test: Title → prologue → oath → Opening Rite → semester → Closing Rite → report card | Backlog — good candidate for the next hardening WO |
| Asset provenance review before any public release (sample-derived sprite work) | Neal's call pre-release; sources documented in HANDOFF/§10 AW-7 |

### Audit notes

- Codex audited mid-session while AW-73/74 were uncommitted in the same
  worktree and saw transient parse failures — that's the hazard the
  single-worktree rule in AGENTS.md exists to prevent. Audit against a tagged
  green commit, or use a separate `git worktree`.

---

## Audit: Codex co-write plan review — 2026-07-09, audited at AW-76 (`45a048ca`)

Baseline independently verified: **519/519 tests green**. The suite still emits
13 `wait_frames` deprecation notices plus Godot's exit-time report of two leaked
objects / one live resource; both are cleanup debt, not observed game failures.

### Session-shape finding (co-write — Neal decides)

The unlocked agenda totals **175 minutes before discussion, breaks, or wrap-up**
and asks the room to lock the year spine and villain, then draft five prologue
scenes, three pitches, 2–3 supports, and a lore batch. That is likely to reward
fast prose at the expense of the macro decisions `STORY_CRAFT.md` says must come
first.

Recommended definition of done for Friday:

| Time | Outcome |
|---|---|
| 0:00–0:10 | Rule on the sword, Crownspark, and blood/theme conflicts from §H |
| 0:10–0:50 | Lock W4–W6, the player/Kai knowledge state, and the three-clue ledger |
| 0:50–1:10 | Set only the villain dials that materially affect year one |
| 1:10–1:20 | Break |
| 1:20–2:10 | Prologue pass, prioritizing the parent reveal and transitions into/out of it |
| 2:10–2:25 | Lock each house pitch's worldview, callback, and promise; prose can follow |
| 2:25–2:45 | Lock support-pair arcs and year-one romance scope; prose can follow |
| 2:45–3:00 | Read back decisions, assign drafts, and record unresolved questions |

**Subtract from the live session:** the §G lore-copy batch and the goal of writing
2–3 complete C-ranks. Both become safer and faster once the answers and support
arcs are locked. If the room is moving unusually fast, pull one C-rank back in.

### High-value additions (co-write — Neal decides)

| # | Proposal | Why it improves the spine |
|---|---|---|
| CW-1 | Add a four-column knowledge matrix for each major beat: **player / Kai / Alaric / prince**. Lock exactly what each knows after P1, P2, W4, W5, W6, and the epilogue. | Prevents accidental spoilers, arbitrary Alaric withholding, and a villain who knows things without an acquisition beat. |
| CW-2 | Add a clue ledger for the **too-fine token / fourth-line note / palace lamps**: literal answer, plausible first reading, reveal beat, and payoff. | Enforces “no clue without an answer” and makes each promise auditable before prose multiplies it. |
| CW-3 | Make W5's agent escape the consequence of **protecting people instead of pursuing them**, not an invincible boss or post-defeat cutscene escape. The agent gets confirmation because Kai exposes Crown-light while saving someone. | Turns the theme into play, gives the prince a fair information source, and makes the escape feel earned rather than protected by plot. |
| CW-4 | Let W6 pay off the opening rite by changing its verb: the three houses begin as rivals, then must protect one another when the rite destabilizes or is sabotaged. Move the employer glimpse to the epilogue if W6 becomes crowded. | “Harder mock battle” is escalation, not culmination. Cooperation makes chosen belonging the year's mechanical and emotional answer. |
| CW-5 | Give W4–W6 one route-lens sentence per house: how Emberwing, Tidemark, and Thornrook interpret the same event, and which route character carries the key emotional beat. | Keeps the common spine while preventing Emberwing from becoming the unspoken canon route. |
| CW-6 | For every support pair, lock **C = surface misread, B = exposed wound, A = protective choice/proof, S = optional confession** before drafting any rank. Also distinguish “eventually romanceable” from “authored in year one.” | Preserves arc shape across many pairs and reconciles `CHARACTER_BIBLE_KAI.md` (“every student”) with a deliberately smaller first-year writing scope. |

### Proposed rulings on the two canon conflicts (co-write — Neal decides)

1. **Sword:** Kai has carried and used the plain blade for years, so it can open
   the cave. His parents do not give him the blade after the awakening; they
   reveal that it was found beside him and give him the **wrapping, scabbard, or
   crest** they hid with that truth. The scene keeps a physical reveal without
   teleporting the sword out of his possession.
2. **Crownspark:** separate **manifestation** from **agency**. Crown-light erupts
   involuntarily in the prologue and can appear once as a scripted rescue beat;
   the player-controlled Magic command unlocks only after an Academy teaching
   beat. This keeps the shipped spell identity while honoring the slow reveal.
3. **Blood/theme refinement:** “Blood grants access, not authority; protection
   earns trust.” The prince's blood should open some of the same doors, or Kai's
   victory still reads as superior inheritance. What the two men choose to
   protect is what separates them and what determines who can wield the whole.

### Optional trims / cautions (co-write — Neal decides)

- Do not make “Gray Prince” common gossip too early unless year one intends the
  dead-prince answer to be nearly solved; a non-royal field title preserves more
  room for the royal reveal.
- Keep W4's vision concrete enough to pay off, but avoid a generic prophecy that
  only says “green fire and a crown.” Give it one identifiable place, object, or
  human action that can later be re-read.
- Let the W6 character climax finish before the year-two villain hook. One scene
  doing rite payoff, route payoff, mystery reveal, and royal teaser will flatten
  whichever beat arrives first.
