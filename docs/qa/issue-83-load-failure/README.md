# Issue #83 — rejected occupied-slot loads report usable failure

Basis: MASTER_PLAN §§1–2, §6 WO-4.3/4.4 (save/load) and WO-9.6 (settings/saves), §10 AW-74–76; ACADEMY_BIBLE §3 existing school/Journal continuation. Existing save schema, manual slot set, #11 atomic validation, deferred scene changes, load semantics and #75/#76/#81 behavior are retained. No canon, art, economy or save-policy decision is made here.

## Defect

`SaveSystem.list_slots()` deliberately lists every occupied file, including malformed and unreadable ones, so a rejected slot stays visible and selectable. Both existing entry points then failed silently:

- `TitleScreen._choose_slot()` called `prepare_load()` and did nothing visible when it returned `false`.
- `AcademyJournal._do_load()` reported an absent slot but had no branch for an occupied slot that failed `Campaign.load_from_slot()`.

An occupied file holding `{broken`, `{}`, or a well-formed envelope with invalid campaign types could therefore be selected forever with no feedback, no retry signal and no way to tell a rejection from a hang.

## Production change

**`src/ui/title_screen.gd`** — `_choose_slot()` returns after the existing success route and otherwise calls `_report_load_failure(slot)`. That sets `_status`, plays the existing `cancel` SFX and redraws; the Load menu is left open and usable. `status_rect()` is a top-wide band measured from the live viewport (`clampf(vp.x - 80, 240, 720)`, 34 px tall) and drawn through `UITheme.draw_panel`, so the default and compact layouts are laid out from the same numbers the test asserts. `_status` is cleared in `_open_main`, `_open_dev`, `_open_new_game`, `_open_load` and at the start of `_choose_slot`, so ordinary navigation never leaves a stale rejection on screen.

**`src/ui/academy_journal.gd`** — `_do_load()` returns after each existing success route (live-battle resume and campaign load) and otherwise calls `_report_load_failure(slot)`, which plays `cancel` and reuses the existing toast with a new `load_error` flag. The toast box computation is extracted from `_draw` into `_toast_rect()` so the layout test measures the real rectangle. `_switch_tab` clears a toast that is still the load rejection, so changing tabs does not carry it forward. Existing `_show_toast` callers are unchanged; the new parameter defaults to `false`.

**Wording** follows each surface's existing slot numbering: Title keeps its zero-based Load labels ("Slot 0"), Journal keeps its one-based System rows ("Slot 1").

| Situation | Title | Journal |
| --- | --- | --- |
| Occupied file rejected by the existing loader | `Slot N couldn't be loaded — choose another slot.` | `Slot N couldn't be loaded — choose another slot.` |
| Listed slot that vanished before selection | `Slot N is empty.` | `Slot N is empty` (existing string) |

Unchanged: slot count and paths, JSON envelope/version, `Campaign.load_from_slot`, `SaveSystem.load_slot`, the #11 atomic validator, success routing, deferred `change_scene_to_file`, `Resume` staging, RNG, campaign/roster/support/grade/flag state, and the save files themselves. Rejected loads never rewrite, repair, delete or migrate a slot; there is no new validator, autosave or compatibility reinterpretation.

## Controlled headless coverage

`tests/test_load_failure_feedback.gd` (10 tests, 126 assertions) drives the production `TitleScreen`, `ChoiceMenu` and `AcademyJournal` through real key events into a 1280×720 `SubViewport`. Slots are disposable `user://` files; nothing under a real player profile is read or written.

| Test | Assertions |
| --- | --- |
| `test_title_rejects_occupied_invalid_slots_and_keeps_the_menu_usable` | Malformed JSON and valid-JSON-with-invalid-types both report the failure; Load context, menu visibility and the slot listing survive; whole Campaign/roster/RNG/staged resume/prep/room/spawn snapshot unchanged; no scene change; source and neighbour bytes unchanged; retry on the same slot, move to the next slot, then Escape clears the feedback back to the main menu. |
| `test_title_reports_a_slot_that_disappears_after_listing` | A slot removed between listing and selection reports `Slot 2 is empty.` truthfully and keeps the menu open. |
| `test_title_retry_after_repair_loads_and_clears_feedback` | Failure → repaired file → retry takes the existing success route (recorded handoff), clears `_status`, makes the campaign live, and leaves the file byte-identical. |
| `test_title_failure_feedback_fits_default_and_compact_layouts` | At 1280×720 and 640×360 the band stays inside the viewport, the measured text fits it, and it does not overlap the Load menu. |
| `test_journal_rejects_occupied_invalid_slots_and_stays_open` | Same two invalid files through real System rows: toast reports the one-based slot, tab and book stay open, state and both files unchanged; retry, next row, tab change clears the stale rejection, Escape closes without a scene change. |
| `test_journal_reports_empty_invalid_and_missing_slots_truthfully` | Occupied file with no campaign reports the rejection; a slot that vanished after listing keeps the existing truthful empty message. |
| `test_journal_live_battle_slot_with_invalid_campaign_is_rejected` | A live-battle payload with an invalid campaign is rejected before mutation; the previously staged battle, prep, room and spawn survive. |
| `test_journal_failure_feedback_fits_default_and_compact_books` | Toast rect stays inside 1280×720 and 640×360 and fits the measured text. |
| `test_successful_campaign_load_still_enters_the_campaign` | Child process: real Title Load on a valid slot still reaches `house_choice.tscn`. |
| `test_live_battle_slot_still_resumes_into_the_battle` | Child process: real Journal System load of a live-battle slot still resumes `mock_battle.tscn` and consumes the staged payload. |

`tests/fixtures/load_feedback_flow.gd` builds a real battle snapshot through `mock_battle.tscn` for the resume route. Both success checks run in a child process because their deferred scene change must not replace GUT's own running scene; failures stay in-process.

## Regression-first

With the two production files reverted to accepted main `241d947f` and the new test files present, the focused suite reports **2/10 passed, 8 failed**: Journal `_toast` stayed empty on both invalid occupied loads, and `TitleScreen._status`, `status_rect()` and `Journal._toast_rect()` did not exist. The two child-process success-routing tests already passed, confirming they describe existing behavior rather than the fix.

With the production change: **10/10 passed, 126 assertions, exit 0**.

## Focused and full runs

Accepted main `241d947fee9056d5f4f63f84dc5029ec5b3b4111`, then accepted #81/#82 integrated normally by fast-forward to `cd2af67c960fda359549e1bba0f4a62216a81c02` before the final runs; only HANDOFF/STATUS text was resolved, no production file conflicted.

Affected Title/Journal/flow/campaign-load/save/resume groups on the integrated head: **149/149 tests, 9,235 assertions, 16 scripts**, exit 0 (`load_failure_feedback`, `title_flow`, `academy_journal`, `journal_close_input`, `resume`, `campaign_load_validation`, `save_system`, `battle_save_load`, `battle_save_menu`, `campaign_flow`, `studio_resume_validation`, `campaign`). Existing assertions are preserved; #81 added two resume tests and two load-validation tests that pass unchanged.

Clean Godot 4.7.2 `--headless --editor --import`: exit 0, no script-load errors.

Full GUT on the integrated head with this change: **940/940 tests, 16,744 assertions, 115 scripts**, exit 0 (442.304 s), 44 inherited deprecations.

For comparison, the same integrated head without the #83 files (pure `cd2af67c`): **930/930 tests, 16,618 assertions, 114 scripts**, exit 0 (439.745 s). The delta is exactly the 10 new tests, 126 new assertions and one new script.

Both runs serialize under the shared Git-common-directory `vael-godot-heavy.lock` with disposable `XDG_DATA_HOME`; no helper/Python suite applies because no Python changed.

**Exit-time diagnostics are inherited.** One integrated run without #83 and one with #83 printed `2 ObjectDB instances were leaked at exit` plus `1 resources still in use at exit`; a verbose run identifies them as `AudioStreamWAV` / `AudioStreamPlaybackWAV` for `res://assets/audio/music/battle_theme.wav`, i.e. shared `AudioManager` music state still referenced by the audio server at shutdown. The identical diagnostic reproduces on unchanged `cd2af67c` with the #83 files removed, and the new suite alone reports none, so it is not introduced here. All runs still report 0 failures and exit 0.

## Byte preservation

Every rejection case reads the source slot and its neighbour before and after the attempt and asserts `PackedByteArray` equality (`_file_bytes()` in both Title and Journal tests). The repair-and-retry test asserts the same for the successful re-load. No test writes outside its own disposable `user://test_load_feedback_*` directory, which is removed in `after_each`.

## Limits and pending real-window evidence

Automated coverage is production-code and production-input, but it is not a graphical acceptance: it does not prove font rendering, panel contrast or how the band reads to a player at 1280×720 and 640×360.

#81 ended its GUI jobs and explicitly released the desktop, but the engineering lead has not yet named #83 for native input/capture. Under this issue's own gate, no game process, native input or capture was run. Real-window evidence is therefore **pending**, not waived:

1. Seed a disposable profile with an occupied invalid slot (`{broken` and a valid envelope with invalid campaign types) plus one valid slot.
2. Title → Load Game: select the invalid slot, confirm the band appears, the menu stays usable; retry the same slot, move to another, then Escape. Inspect default 1280×720 and compact 640×360.
3. Start a real battle, save it, then corrupt only the campaign section of a copy; Journal → System → load it and confirm the toast, the still-open book, a retry and a tab change.
4. Repair a disposable slot and confirm the existing success route still reaches the campaign/battle.
5. Compare source and neighbour file bytes before and after every rejection and record the exact SHAs.

This receipt is recorded so the gap is visible; it is not a claim that graphical acceptance happened.
