# Issue #54 — closing-battle grade attribution

This is a bounded repair of newly completed battles. Basis: GRADING_SYSTEM §§1–2, 4–5; MASTER_PLAN §§1–2, §6 WO-4.4/7.1/7.4 and §10 AW-54/64/76; ACADEMY_BIBLE §4. The six-entry calendar and its 3→4 / 6→7 boundaries remain implementation scaffolding, not an authored school year. #30 owns the authored map and remaining ceremony/reward delivery and idempotence work.

## Production change

`BattleView._end_battle()` records an eligible non-arena battle score before `Campaign.capture()` can advance the week and lock/reset the semester. The existing `_battle_over` guard still protects completion. Scoring remains after Casual defeat-bookkeeping cleanup, using the same living/fielded counts and rounds. Campaign activity/arena eligibility, pre-oath behavior, capture of roster/supports, result presentation, progression, RNG and save representation are unchanged. Locked legacy cards are preserved; no regrading or migration.

## Controlled headless runtime coverage

`tests/test_battle_grade_attribution.gd` uses actual registry-routed scenes and production objective/end/capture code. Fixture wins route the existing forces; they do not claim earned graphical playthroughs. Dialogues are disabled only in these automated fixtures.

| Boundary | Assertions |
| --- | --- |
| Emberwing, Tidemark, Thornrook closing encounters; post-oath Week 6, semester 2; neutral inputs; clean win within par | Existing semester-1 card remains unchanged in value; semester 2 locks 74 / B / Accomplished; Week 7, semester 3 under unchanged scaffold arithmetic; all new samples empty; roster/support capture preserved; completion consumes no RNG. |
| First scaffold close, Week 3 semester 1 | 74/B locks in semester 1, next samples empty, one advancement. |
| Week 2 non-boundary victory with prior battle score 60 | Samples [60,100], running score 67, no card, one week advance. |
| Boundary defeat in Classic and Casual with prior score 90 | Samples [90,30], no close or advancement; defeat result retained. Existing lord-loss routing/lifetime tests remain in the focused run. |
| Downed ally, round 12, both modes | Existing loss and over-par math gives 80; Casual defeat bookkeeping cleanup remains distinct from living-unit score counting. |
| Pre-oath prologue victory | Score 100 retained, Week 1 / semester 1 unchanged. |
| Arena / inactive standalone | No non-arena campaign battle sample. |
| Live JSON slot → `Resume.stage()` → exact routed scene → victory | Prior samples, round and HP restored; one closing card, empty next samples. |
| Completed payload through normal routing and defensive direct result restoration | No live battle staged; saved campaign restores locked history; duplicate completion/objective/result restoration does not score, close or advance again. |
| Child-process real result input twice → deferred castle/title return | Correct destination and identical captured campaign/grades after victory and defeat; second dismissal inert. A declared `feast_seen` fixture flag isolates this boundary from unrelated year-end dialogue. |

Regression-first on unchanged main `11e08763`: **4/8 pass, 4/8 fail (118/131 assertions)**, including all three closing routes, first boundary, resumed/completed history and actual victory return. With score-before-capture: **8/8 pass, 131 assertions**, exit 0. No script errors. The isolated GUT run retains exit-time ObjectDB/resource diagnostics; it does not substitute for the full-suite check.

Focused grading/calendar/campaign/three-house/lord-lifetime/resume/load-validation checks: **94/94, 4,769 assertions, nine scripts**, exit 0, no script errors or exit-time resource diagnostics. Clean first import and final editor import: exit 0, no script-load errors (Godot 4.7.2).

Full GUT: **837/837, 12,237 assertions, 106 scripts**, exit 0 (226.451 s), 22 inherited deprecation notices, no script-load errors or exit-time ObjectDB/resource diagnostics.

All runs use disposable player data. Clean import/full GUT serialize under the shared Git-common-directory heavy lock. Existing tests are preserved.

## Graphical boundary still pending

No desktop input, graphical launch or capture is performed by #54 while #39 owns the desktop; #42 is next. The remaining observation is a bounded real-window Journal → Grades check on this repair's exact source after both explicit releases. Use an explicitly declared active post-oath Week 6 / semester 2 fixture with neutral samples; freshly finish a closing contest, return normally, observe the locked semester-2 card and empty next-term Battlefield samples, and verify save/load preserves that history. A clean ≤10-round/no-downs win yields 74/B; otherwise declare actual rounds/downed units and calculate the expected score using unchanged Grading. Do not call this a fresh full-year playthrough or Neal visual approval.

#39 may continue qualifying accepted #29 forces/objectives on its declared source. Its historical source predates this grading-order repair; later integration evidence must identify the changed grade boundary separately. No full ceremony/reward delivery, authored calendar/break/sabotage, old-card correction or creative approval is claimed.
