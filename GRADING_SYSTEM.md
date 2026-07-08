# GRADING_SYSTEM.md — the Academy Report Card

*Design doc (Neal + Fable, 2026-07-08). The academy year is graded. Kai carries a
running **grade** you can check any time in the Journal, see exactly what's
dragging it down, and act to raise it. It's low-stakes and feel-good — a reason
to do the school things — but real enough that a great year is earned.*

Owning systems: `Campaign` (the score state, saved), the **Journal → Grades tab**
(display), and the activities that feed it (classes/quizzes, battles, the Arena).

---

## 1. The shape of it

- The school year has **two semesters** (the calendar's two halves, bracketed by
  the Opening Rite and the Closing Rite). Each semester ends in a **Report Card**:
  a locked letter grade + a short written remark.
- Between report cards you always have a **running grade** — the grade you'd get
  if the semester ended today. The Journal shows it live.
- Grades are a **rank**, house-flavored so it feels like Vael, not a US report:

  | Rank | Name | Rough % | Feel |
  |------|------|---------|------|
  | **S** | Ascendant | 90–100 | top of the year, honors |
  | **A** | Distinguished | 78–89 | excellent |
  | **B** | Accomplished | 64–77 | solid |
  | **C** | Passing | 50–63 | scraping by |
  | **D** | Faltering | <50 | on notice |

---

## 2. What the grade is made of (weighted score 0–100)

The running grade is a weighted blend of four **marks**, each itself 0–100. Weights
are tunable data; a first-pass proposal:

| Mark | Weight | Fed by | Notes |
|------|-------:|--------|-------|
| **Coursework** | 35% | class **quizzes** & exams | the academic core (needs the classroom/quiz activity) |
| **Battlefield** | 35% | inter-house battles + **story chapters** | a per-chapter **battle score** (below) |
| **The Arena** | 20% | best **wave depth** reached this semester | the weekly Arena; also just levels Kai up |
| **Conduct** | 10% | participation — events attended, supports advanced, activities tried | the feel-good glue; hard to fail, easy to top up |

**Missing marks don't crater you.** A mark with no data yet counts as a neutral
**60** (a "C") rather than 0, so early in a semester you're not staring at an F.
Once you've done a quiz / a battle / an Arena run, that mark reflects real play.

### Battle score (per graded battle)
A 0–100 score the resolver already has the ingredients for:
- **+** objective met, turns under par, enemies routed, **no unit lost**
- **+** crits/kills, tough terrain used well (bonus, not required)
- **−** over-par turns, units downed (non-lethal yields still cost score), fleeing
The semester's Battlefield mark = the **average** of graded battles so far.

### Coursework score
Each quiz/exam returns a percentage; the mark = the **average** of quizzes taken
this semester. Exams (mid/finals) weigh double a pop quiz.

### Arena score
= the **deepest wave** cleared this semester mapped to 0–100 (e.g., wave 10 ≈ 100).
Only your *best* run counts, so grinding isn't required — one great run carries it.

### Conduct score
Starts at 60, ticks up with participation (each festival/party attended, each
support rank gained, each activity tried), soft-caps at 100. Basically "did you
show up and be part of the school."

---

## 3. In the Journal — the Grades tab

A new tab beside Roster/Calendar/Items/System:

```
  ACADEMY STANDING            Semester 1 · Week 3

  Running grade      B  (71) ▁▂▃▅▆   "Accomplished — a strong start."

  Coursework   35%   ██████░░  74     ↑ Ace the Week-4 exam (+ up to 8)
  Battlefield  35%   █████░░░  68     ↑ Win the next chapter without a loss
  The Arena    20%   ███░░░░░  55     ↑ Reach wave 6+ (best so far: 4)
  Conduct      10%   ████████  90     ↑ Already excellent

  → Next report card: end of Semester 1 (Week 6)
```

- The **"↑" hint per mark is the whole point** — it tells you the single most
  effective thing you can do right now to raise that mark, computed from your
  current numbers (the lowest / most-improvable mark gets the strongest nudge).
- The header bar sparkline is the running grade's trend across the weeks.

---

## 4. What a grade *does* (rewards, kept light)

- **End-of-semester Report Card** cutscene: your rank + a remark in-character
  (Warden Maren / the professors), house pride, a small reward chest scaled to
  rank (gold, a stat tonic, a rare item at S).
- **Standing perks** (optional, tunable): an **S** might grant a bonus deploy
  slot or a discount at the Quartermaster that semester; a **D** triggers a
  gentle "remedial" nudge (a free tutoring quiz) — never a hard fail / game over.
- **Story acknowledgment**: a few lines of dialogue react to how you're doing —
  flavor, not gates.
- **The Arena's extra credit** flows straight into the Arena mark *and* levels
  Kai, so it pulls double duty (Neal's note).

---

## 5. Data model (implementation sketch — not built yet)

`Campaign` grows a small, saved grade block:

```gdscript
var semester := 1
var grade_marks := {           # 0..100 each; -1 = no data yet → treated as 60
    "coursework": -1, "battlefield": -1, "arena": -1, "conduct": 60,
}
var grade_samples := {         # running inputs so averages recompute cleanly
    "quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0,
}
var report_cards := []         # [{semester, rank, score, remark}] — locked history
```

- `Campaign.record_quiz(pct)` / `record_battle_score(0..100)` /
  `record_arena_run(wave)` / `add_conduct(n)` update the samples and recompute the
  affected mark.
- `Campaign.running_grade() -> {score, rank, marks, hints}` — pure, testable; the
  Journal draws it.
- At a semester boundary (calendar), `Campaign.close_semester()` snapshots the
  Report Card, fires the cutscene, resets the samples, `semester += 1`.

**Weights, thresholds, and the neutral-60 default are all data** — balance after a
playtest, don't hardcode in formulas (MASTER_PLAN §2).

---

## 6. Build order (depends on other WOs)

1. **Grade data model + `running_grade()` + the Journal Grades tab** — can land now
   with battle scores + conduct feeding it; coursework/arena read as neutral until
   their sources exist.
2. **Battle score** hook in the combat resolver/result (feeds Battlefield).
3. **Arena** (its own WO) → feeds the Arena mark + levels Kai.
4. **Classes / quizzes** (the academic activity) → feeds Coursework.
5. **Report Card** cutscene + semester rollover + standing perks.

Nothing here is a blocker for the others; the grade just gets more complete as its
feeder systems land.
