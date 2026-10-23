# Issue #92 — Journal calendar readability and navigation

## Scope and plan basis

MASTER_PLAN §§1–2, §6 WO-9.7 (Journal calendar view) and WO-9.4 (readable themed UI), and partial §10 M9 authorize this bounded presentation/input repair. ACADEMY_BIBLE §§3–4 establish the academy/calendar context; the Journal only displays the existing Campaign calendar. HANDOFF's Journal, #16 input-consumption, and disposable-save rules govern the existing UI and validation boundaries.

The six-week `year_one.tres` remains development scaffolding. #30 still owns authored semester dates/mapping and save treatment. No calendar content, resource, ordering, arithmetic, progression, or save schema was changed. No canon contradiction was found; the approved two-semester structure and current six-week scaffold remain separate facts.

## Regression-first automated evidence

- Unchanged accepted main `c07617e24e84685263a748709b274d17dec5700c`: the new live Journal viewport-input suite failed **3/4 tests (5/8 assertions)**. Calendar had no row selection independent of `Campaign.week`, and no measured scroll layout for clipped rows. The non-action/Left/Right guard already passed.
- Current `tests/test_journal_calendar_navigation.gd`: **4/4 (50 assertions)** through actual keyboard bindings pushed into a live `SubViewport`. It measures the same body and rows used by `_draw_calendar`, checking first/current/final selection, both ends, complete labels and row bounds, default/compact/restored layout, empty/out-of-range/shortened data, Calendar Enter, Left/Right, Campaign/RNG invariance and sentinel manual/autosave-like/settings bytes.
- Accepted #83 was integrated normally from accepted main `9f76561e` at merge `784d8b74`; no #85 or #89 branch content was copied. After integration and the final Calendar draw correction, the complete affected group passed **140/140 tests, 5,277 assertions / 14 scripts**, including #83 load feedback and existing Journal-close, castle/layout/toast, calendar, save/load, Campaign and preference suites. Clean Godot 4.7.2 import exited 0 with no script-load errors. Godot runs used the shared Git-directory heavy lock and disposable user data.
- The original pre-integration baseline full GUT run passed **940/940 tests, 16,719 assertions / 115 scripts**; helpers passed **104 tests / 2 existing opt-in skips**. Per the accepted-sibling integration instruction, that unchanged full baseline was not repeated after #83. The current PR exact-head Verify remains pending; do not poll it.

## Original-renderer real-input acceptance — complete

- Tested game-source commit: `f4aaf654eb139e832d2e1c5f61ae624937a4676a` (after accepted #83 integration). Godot 4.7.2, Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2; native X11 input and client-window captures.
- Fixture: the existing native Emberwing Week 2 campus return, [checkpoint](../issue-5-school-loop/emberwing-return-save.json), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. It was copied byte-for-byte into a fresh disposable profile and loaded through ordinary Title → Load Game → occupied Slot 0. Its SHA-256 matched before and after. No slot, Campaign, event, settings or repo fixture values were edited.
- From the loaded campus, opened Journal with J and Calendar with Right. Native Up/Down reached first and final; reopening selected the existing current Week 2 entry. At 1280×720 all six existing events, full labels and kinds fit. Live resize 1280×720 → 800×450 → 640×360 → restored remained usable. At 800×450 the final view shows rows 3–6; at 640×360 the first and last views show rows 1–2 and 5–6, with complete “The Opening Rite — Mock Battle” and “The Closing Rite” labels, kinds and `↑/↓ browse` range feedback. No row enters the tabs or footer. The blue selected row and gold current-week marker remain distinct.
- Closed with J and held Down to walk in the campus; the ordinary Mission Board prompt appeared. No Enter/deploy/rest/week advancement, full-year replay or story/canon action occurred. No Neal taste/visual approval is claimed.
- Inspected captures, all from the same tested source, are listed below. [Manifest](manifest.json) records source/integration/checkpoint hashes, renderer and image SHA-256 values.

| Capture | Evidence |
| --- | --- |
| [Title](images/01-title.png), [Title Load slot](images/02-title-load-slot.png) | Ordinary launch and native occupied checkpoint selection |
| [Current week, default](images/03-calendar-current-1280x720.png), [reopened current week](images/11-calendar-reopened-current-week.png) | Week 2 is selected on open/reopen; current marker is distinct |
| [First row, default](images/04-calendar-first-1280x720.png), [final row, default](images/05-calendar-final-1280x720.png) | Full existing labels and kinds, with both navigation ends reachable |
| [Final row, 800×450](images/06-calendar-final-800x450.png) | Four compact rows fit above the footer; visible range feedback |
| [First row, 640×360](images/07-calendar-first-640x360.png), [final row, 640×360](images/08-calendar-final-640x360.png) | Longest label wraps/readable; first and last events remain reachable |
| [Restored 1280×720](images/09-calendar-restored-1280x720.png) | Live resize restores the full list and selection |
| [Campus after close and movement](images/10-campus-after-close-and-walk.png) | J returns to exploration; native movement reaches the Mission Board prompt |

## Remaining limits

Exact-head GitHub Verify and lead review remain pending. The draft PR must also integrate any later accepted sibling through the normal main merge path, preserving those tests and status records; do not copy unaccepted branches. The GUI acceptance queue has released #92 and this run ended with the game process closed. No full-year replay or Neal approval was attempted.
