# Battle hover/header refresh — GH-72 / WO-4.4 + WO-9.5

Plan basis: MASTER_PLAN §1 (read-the-map tactical combat), §2 coding rule 2 (logic/presentation split), §3 (combat formulas unchanged), §6 WO-4.4 polish and WO-9.5 battle QoL, and §10's partial 9.4–9.10 status; ACADEMY_BIBLE §4 (normal tactical combat and lord-defeat handling in the Clash). This is presentation repair only. No story, canon, formula, RNG, save-schema or reward change was needed, and no contradiction was found in those sections.

## Defect and repair

`BattleView._update_hover_info()` and `_update_debug()` only ran from `_cursor.cell_changed`. A heal, an attack, a yield/removal or phase-start terrain healing changes HP/occupancy at the hovered cell without moving the cursor, so both readouts stayed on the pre-action value until the player moved the cursor.

`_refresh_cursor_info()` now re-reads `_cursor.cell` at the existing boundaries where ordinary control can return:

- after `_finish_action()` (successful heal/attack, including a yielded occupant);
- at `_begin_player_phase()` after terrain healing/hazards (including the post-skip/ordinary turn boundary);
- at enemy-phase terrain application, so a phase-start change is visible immediately;
- after a save rebuild (`_restore_post_load_ui()`).

The refresh only updates the header and hover box. It does not issue an action, move the cursor, spend an item/use, touch combat RNG or change unit/objective/save state. `unit_at()` now ignores queued/freed nodes so a departed occupant cannot be re-read, and the hover draw guards invalid/dead references.

## Automated evidence

New production-path suite `tests/test_battle_hover_refresh.gd` uses a live `BattleView` in a `SubViewport` and the ordinary selection/move/menu/targeting/confirm paths. It covers:

- stationary-cursor successful heal: hover repaint plus `<Perrin 24/24>` header against the pre-heal value;
- stationary-cursor nonlethal attack: post-combat HP in both readouts;
- stationary-cursor lethal attack/yield: `unit_at()` null, hover hidden, header without the departed unit;
- phase-start SPRING terrain healing under a stationary cursor;
- real PageDown continuation after a heal with an unchanged battle snapshot;
- direct refresh state invariance (save payload, cursor, selection, phase, RNG, busy);
- queued-for-deletion occupancy guard.

Regression-first result against the unchanged `11f98c79` production source: **1/7 tests passed (47/60 assertions)**. The original failures were the stale header, the missing hover repaint, the retained departed occupant and the queued-occupant lookup. After the repair the same suite is **7/7 (66 assertions)**.

On the fix commit's source, the related battle/input/hover/combat/heal/phase/terrain/save group was **181/181 tests, 2,747 assertions / 25 scripts**, exit 0; the terrain, resume, lord-lifetime and grading group was **33/33 tests, 365 assertions / 4 scripts**, exit 0; clean Godot 4.7.2 editor import exited 0 with no script-load errors; and full GUT was **890/890 tests, 14,474 assertions / 111 scripts**, exit 0 (246.376 s), with helpers **104 discovered / 102 passed / two unchanged opt-in skips**.

Accepted main `353b8621` (merged #65 exchange skip and #68 fishing log) was then integrated by ordinary merge, preserving both siblings' records. No production conflict occurred: #65 paces presentation only, and its post-skip path still returns through the same `_finish_action()`/`_begin_player_phase()` boundaries where the refresh runs. On the merged source: clean import exit 0/no script-load errors; the battle group including `test_battle_exchange_skip.gd` is **192/192 tests, 3,681 assertions / 26 scripts**, exit 0; the new suite is **7/7 (66 assertions)**; full GUT is **905/905 tests, 15,433 assertions / 112 scripts**, exit 0 (317.62 s); helpers **104 discovered / 102 passed / two unchanged opt-in skips**. Import and full GUT held the shared Git-common-directory `vael-godot-heavy.lock` with disposable `XDG_DATA_HOME`. The full run reports 32 inherited deprecations; no script-load errors.

Exact-head CI is recorded on the GitHub PR for `team/issue-72` after the final status/documentation commit.

## Real-input graphical acceptance — 2026-10-23

Tested source **`7d88bf1a65e6f17c05f6cbd774b99d5e31693e13`**, original Godot 4.7.2 **Vulkan 1.4.318 Forward+**, llvmpipe (LLVM 20.1.2, 256 bits), existing 1280×720 X11 desktop. [Structured results and exact action sequence](results.json).

Fixture: a byte-for-byte copy of [`emberwing-opening.json`](../issue-39-three-house-contests/saves/emberwing-opening.json), SHA-256 `c156c62b43e6d6f48002d50f787751e708ec03cdef3378ceadddcd806e99a4d3`, in physical slot 0 of a fresh disposable installation profile. Entry: ordinary Title → Load Game → Slot 0. No save value, position, unit stat or story flag was edited. All gameplay used real X11 keyboard/pointer input; no action/result/turn/combat handler was called directly.

- **Attack, lethal removal:** Kael moved from (3,12) to (8,12) and targeted Marlow at (9,12). Before confirmation the cursor was stationary on Marlow with header `<Marlow 9/20>` and hover **HP 9/20** ([capture](images/01-pre-attack-marlow-9-20.png)). After the ordinary attack Marlow had yielded; the cursor was still on (9,12), the header showed only the empty terrain cell and the hover box was cleared — no stale `<Marlow 9/20>` ([capture](images/02-post-attack-removed.png)).
- **Heal, stationary target:** Wren moved to (3,11) and targeted Perrin at (3,10). Before confirmation: header `<Perrin 10/24>`, hover **HP 10/24** ([capture](images/03-pre-heal-perrin-10-24.png)). After the ordinary heal the cursor was still on Perrin, with both readouts showing **24/24** ([capture](images/04-post-heal-perrin-24-24.png)). This is the original #65 reproduction.
- **Continuation:** real PageDown moved to Liora at (2,11) with `<Liora 18/18>` ([keyboard capture](images/05-keyboard-continuation.png)); a real pointer move returned to Perrin with `<Perrin 24/24>` ([pointer capture](images/06-pointer-continuation.png)).

Limits: one bounded checkpoint and one attack/heal scenario, not a full-school replay; the graphical run proves the visible readouts and ordinary continuation, while the automated suite proves action/resource/RNG/save-state invariance. The real-input run used the fix commit `7d88bf1a`, before the ordinary merge of accepted #65/#68; the merged source differs there only by those accepted changes and was verified by the focused/battle/full suites rather than a second graphical pass. No post-action save was written or inspected for this display check. This is functional acceptance, not Neal's visual/taste approval.

## Desktop release

Before starting, a process check found no graphical Godot/input/capture job on the shared desktop and no game window; #68's named release and the lead's handoff are recorded in the issue. The game was started only for these ordinary inputs, exited normally after the pointer continuation, and all game/input/capture processes were ended. The desktop was explicitly released on issue #72 ([release receipt](https://github.com/KumarG23/vael-academy/issues/72#issuecomment-6367992108)).
