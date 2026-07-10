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
