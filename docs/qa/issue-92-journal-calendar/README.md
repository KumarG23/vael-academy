# Issue #92 — Journal calendar readability and navigation

## Scope and plan basis

MASTER_PLAN §§1–2, §6 WO-9.7 (Journal calendar view) and WO-9.4 (readable themed UI), and partial §10 M9 authorize this bounded presentation/input repair. ACADEMY_BIBLE §§3–4 establishes the walkable academy and the calendar's role; the Journal only displays the existing Campaign calendar. HANDOFF's Journal, #16 input-consumption, and disposable-save rules govern the existing UI and validation boundaries.

The six-week `year_one.tres` remains development scaffolding. #30 still owns authored semester dates/mapping and save treatment. No calendar content, resource, ordering, arithmetic, progression, or save schema is changed. No canon contradiction was found; the approved two-semester structure and current six-week scaffold remain separate facts.

## Regression-first automated evidence

- Unchanged accepted main `c07617e24e84685263a748709b274d17dec5700c`: the new live Journal viewport-input suite failed **3/4 tests (5/8 assertions)**. Calendar had no row selection independent of `Campaign.week`, and no shared measured body/layout API for testing the clipped rows. The non-action/Left-Right guard already passed.
- Current implementation: `tests/test_journal_calendar_navigation.gd` passes **4/4 (50 assertions)** through actual keyboard bindings pushed into a live `SubViewport`. It measures the same body and rows used by `_draw_calendar`, checks both list ends, selected/current-week distinction state, full labels and row bounds, the default/800×450/640×360/restored layouts, a shortened/empty/out-of-range data view, current-week opening selection, Left/Right, non-action Enter, full Campaign state/RNG, and sentinel bytes for a manual slot, autosave-like file and settings file.
- This is headless production-scene/input/layout evidence. It is not an original-renderer capture or visual approval.

## Native checkpoint and graphical acceptance — pending

GUI queue is #83 → #85 → #89 → #92. No game process, native input, or capture has been started for this issue. #89 must explicitly end/release its jobs and the engineering lead must name #92 before any GUI work. Do not use another issue's active desktop session.

Planned source checkpoint: the existing native Emberwing Week 2 campus return at `docs/qa/issue-5-school-loop/emberwing-return-save.json`, SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. Once the gate opens, copy it byte-for-byte to an isolated profile, record the final tested commit and fixture hash, launch through ordinary Title → Load, open the Journal, reach/read first/current/final events, resize 1280×720 → 800×450 → 640×360 → restored, close with J/Esc, continue exploration, and inspect captures. Do not change the fixture calendar or infer a canonical week map.

Pending items: original Forward+ renderer proof, reviewed default/compact captures, native Title/campus continuation, and GUI release receipt. No full-year replay or Neal taste approval is claimed.

## Final source checks

- Affected Journal/castle/input/preferences/calendar/save group: **122/122 tests, 4,455 assertions / 12 scripts**, exit 0. This includes existing #16 close-consumption coverage.
- Godot 4.7.2 clean editor import: exit 0; no `SCRIPT ERROR` or failed script-load lines.
- Full GUT: **940/940 tests, 16,719 assertions / 115 scripts**, exit 0 (440.777 s). Inherited exit-time diagnostics: 2 ObjectDB instances and 1 resource still in use. No test/script-load failures.
- Team helpers: **104 tests, 2 existing opt-in skips**, pass.
- Godot runs used the shared Git-directory heavy lock and disposable `XDG_DATA_HOME`.
- Exact-head GitHub Verify and original-renderer real-input acceptance remain pending. The latter is gated as described above; no game/native input/capture was run.
