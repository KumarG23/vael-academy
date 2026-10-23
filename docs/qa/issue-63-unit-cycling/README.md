# Battle unit cycling — GH-63 / WO-9.5

Scope: MASTER_PLAN §§1–3, §6 WO-9.5 and §10 partial 9.4–9.10; ACADEMY_BIBLE §4's ordinary tactical competition between three independent houses. No canon contradiction was found within this slice. Calendar authoring and the distinct final hostile interruption remain separate work.

PageDown finds the next living, unacted team-0 unit; PageUp finds the previous one. Order is top to bottom, then left to right. From any cell that is not eligible (empty, acted, dead or rival), use its strict board-position successor/predecessor, wrapping at the map ends. One candidate stays on that candidate; none leaves the cursor in place. The normal cursor hover, terrain information and camera follow paths run; selection and movement ranges require normal selection input.

The shortcuts are consumed before arbitrary-key overlay dismissal and operate only during idle player field control. Preparations, selection, targeting/forecast, menus, stats, dialogue, enemy phase, busy/combat camera animations, results and staged resume transitions block cycling. Releases and key echo do nothing. Existing T/Tab end-turn and H danger controls remain.

## Automated evidence

`tests/test_battle_unit_cycle.gd` uses actual routed production battles and cursor nodes in a live SubViewport, dispatching keys and pointer input through `push_input`. It covers board order/wrap, every empty board cell's strict successor/predecessor, one/none, acted/dead/queued/freed and two rival factions, field-control gates, real selection/action/save/end-turn menus, victory/defeat overlays, real dialogue line/choice, real menu-driven Wait, three house routes and snapshot restoration, pan/zoom camera convergence and pointer/keyboard continuation. Whole battle snapshots verify campaign, unit, HP/XP/uses, support, objective/turn and combat RNG invariance. Hint layout is checked at 1280×720 and 640×360.

Accepted base: `9782c1b2` (includes #58). Godot 4.7.2 clean import exited 0 with no script-load errors. Focused cycling checks: **13/13 tests, 855 assertions**, exit 0 (5.212 s). Full GUT: **853/853 tests, 13,158 assertions across 107 scripts**, exit 0 (230.261 s), including existing mouse/cursor/camera, end-turn, save and three-house boundaries. Import and full GUT held the common Git-directory `vael-godot-heavy.lock`; all runs used disposable player data. Full GUT reported 22 existing deprecations and no script-load errors or exit-time ObjectDB/resource diagnostics; the focused run reported two ObjectDB instances and one resource-in-use exit diagnostic. No helper source changed, so local helper tests were not repeated. Exact-head CI is recorded in the PR.


Normal accepted-main integration: #56 merge `5663ec2c` adds report-card delivery/receipt behavior and its tests. Only HANDOFF/STATUS insertion conflicts required resolution; both issues and the accepted GH-58 row are retained. Cycling code/tests are unchanged from `de92ee44`. Combined cycling, report-card delivery, grading, campaign load validation, battle-save, mouse and camera tests pass **77/77, 4,077 assertions / 7 scripts**, exit 0 (17.569 s), shared heavy lock/disposable data. This run reports three deprecations and two ObjectDB instances / one resource-in-use exit diagnostic. The earlier full-suite result is pre-integration; final exact-head CI validates the combined tree.

## Graphical dependency

No game, desktop input or capture job has been started for this issue. Issue #62 owns the shared GUI until its explicit release. Real-window repeated forward/backward cycling, acting then skipping, camera/hover after pan/zoom, keyboard/pointer continuation and inspected captures are outstanding. Automated viewport input is not graphical acceptance or Neal's visual approval.
