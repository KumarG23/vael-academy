# Issue #92 — Journal calendar readability and navigation

## Scope and plan basis

MASTER_PLAN §§1–2, §6 WO-9.7 (Journal calendar view) and WO-9.4 (readable themed UI), and partial §10 M9 authorize this bounded presentation/input repair. ACADEMY_BIBLE §§3–4 establish the academy/calendar context; the Journal only displays the existing Campaign calendar. HANDOFF's Journal, #16 input-consumption, and disposable-save rules govern the existing UI and validation boundaries.

The six-week `year_one.tres` remains development scaffolding. #30 still owns authored semester dates/mapping and save treatment. No calendar content, resource, ordering, arithmetic, progression, or save schema was changed. No canon contradiction was found; the approved two-semester structure and current six-week scaffold remain separate facts.

## Regression-first automated evidence

- Unchanged accepted main `c07617e24e84685263a748709b274d17dec5700c`: the new live Journal viewport-input suite failed **3/4 tests (5/8 assertions)**. Calendar had no row selection independent of `Campaign.week`, and no measured scroll layout for clipped rows. The non-action/Left/Right guard already passed.
- Original `tests/test_journal_calendar_navigation.gd` before the lead correction: **4/4 (50 assertions)** through actual keyboard bindings pushed into a live `SubViewport`. On corrected source `11a1aaad`, it passes **4/4 (62 assertions)**, including measured legend bounds against the heading/body at default, intermediate, compact and restored sizes. It also checks first/current/final selection, both ends, complete labels and row bounds, empty/out-of-range/shortened data, Calendar Enter, Left/Right, Campaign/RNG invariance and sentinel manual/autosave-like/settings bytes.
- Accepted #83 was integrated from accepted main `9f76561e` at `784d8b74`. Accepted #85 main `6d11efdd32a9a8ca9fd2c9b3c01e35deb64fc4ae` was later integrated normally at `db55dcd1`; sibling code, assertions, QA and HANDOFF/STATUS records are retained. Post-integration clean Godot 4.7.2 import exited 0; affected Calendar/Journal/#16/castle/layout/calendar/preferences/save/Campaign/rest/Title suites passed **164/164 tests, 4,952 assertions / 16 scripts** under the shared heavy lock and disposable user data. The regression-first and full baseline receipts below remain tied to their original sources; no unchanged full suite was repeated.
- The original pre-integration baseline full GUT run passed **940/940 tests, 16,719 assertions / 115 scripts**; helpers passed **104 tests / 2 existing opt-in skips**. Per accepted-sibling instructions, unchanged full baselines were not repeated after integrations. The post-#85 focused suites also report inherited GUT deprecations, two ObjectDB instances and one still-used resource at exit; all 164 tests passed.

## Original-renderer real-input acceptance — complete

- Tested game-source commit: `f4aaf654eb139e832d2e1c5f61ae624937a4676a` (after accepted #83 integration). Godot 4.7.2, Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2; native X11 input and client-window captures.
- Fixture: the existing native Emberwing Week 2 campus return, [checkpoint](../issue-5-school-loop/emberwing-return-save.json), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. It was copied byte-for-byte into a fresh disposable profile and loaded through ordinary Title → Load Game → occupied Slot 0. Its SHA-256 matched before and after. No slot, Campaign, event, settings or repo fixture values were edited.
- From the loaded campus, opened Journal with J and Calendar with Right. Native Up/Down reached first and final; reopening selected the existing current Week 2 entry. At 1280×720 all six existing events, full labels and kinds fit. Live resize 1280×720 → 800×450 → 640×360 → restored remained usable. At 800×450 the final view shows rows 3–6; at 640×360 the first and last views show rows 1–2 and 5–6, with complete “The Opening Rite — Mock Battle” and “The Closing Rite” labels, kinds and `↑/↓ browse` range feedback. No row enters the tabs or footer. The blue selected row and gold current-week marker remain distinct.
- Closed with J and held Down to walk in the campus; the ordinary Mission Board prompt appeared. No Enter/deploy/rest/week advancement, full-year replay or story/canon action occurred. No Neal taste/visual approval is claimed.
- The original full-acceptance captures listed below all came from tested source `f4aaf654`. [Manifest](manifest.json) records source/integration/checkpoint hashes, renderer and image SHA-256 values; the later lead-correction captures have their own source record below.

| Capture | Evidence |
| --- | --- |
| [Title](images/01-title.png), [Title Load slot](images/02-title-load-slot.png) | Ordinary launch and native occupied checkpoint selection |
| [Current week, default](images/03-calendar-current-1280x720.png), [reopened current week](images/11-calendar-reopened-current-week.png) | Week 2 is selected on open/reopen; current marker is distinct |
| [First row, default](images/04-calendar-first-1280x720.png), [final row, default](images/05-calendar-final-1280x720.png) | Full existing labels and kinds, with both navigation ends reachable |
| [Final row, 800×450](images/06-calendar-final-800x450.png) | Four compact rows fit above the footer; visible range feedback |
| [First row, 640×360](images/07-calendar-first-640x360.png), [final row, 640×360](images/08-calendar-final-640x360.png) | Longest label wraps/readable; first and last events remain reachable |
| [Restored 1280×720](images/09-calendar-restored-1280x720.png) | Live resize restores the full list and selection |
| [Campus after close and movement](images/10-campus-after-close-and-walk.png) | J returns to exploration; native movement reaches the Mission Board prompt |
| [Corrected Calendar header, default](images/12-calendar-header-default-corrected.png), [compact](images/13-calendar-header-640x360-corrected.png) | Lead-requested correction: measured legend visibly inside body after heading on corrected source; detailed provenance below |

## Lead review correction — bounded native retest

- Lead exact-head review retained the core behavior and found the original “Blue: selected / Gold: current” legend drew beyond `body.end.x` because it used a positive-width right-aligned box starting at the right edge. The default/compact captures above confirmed the legend was absent.
- Corrected source: `11a1aaadef6c72e4aedf1e9ad53ae6229f2a4c87`. The heading width is measured with UITheme font metrics; the legend receives the remaining in-body width beginning after the heading and its gap. `test_journal_calendar_navigation.gd` measures the legend/body/heading bounds at 1280×720, 800×450, 640×360 and restored size.
- After lead release, native X11 real-input capture used original Godot 4.7.2 Vulkan Forward+ / llvmpipe. Fresh disposable profile route: Title → Campus Dev Jump → J → Right (Calendar); then resize 640×360. This was limited to the changed Calendar header, with no save/checkpoint or Campaign fixture writes and no replay of the earlier campus route. Both captures were inspected: [1280×720](images/12-calendar-header-default-corrected.png) and [640×360](images/13-calendar-header-640x360-corrected.png). The legend is fully visible inside the book and does not collide with Year/Week; blue selection and gold current-week marker remain distinguishable. The prior Week-2 checkpoint from the complete acceptance remains SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4` before/after that earlier run; the bounded correction run did not mount or modify it.
- Manifest records corrected source/integration and capture hashes. All GUI jobs ended and the desktop was released to #96. Exact-head Verify 40017360692 passed on source/test head `c8930d1d`; this status follow-up is documentation-only. Lead delta review remains pending; PR stays draft. No Neal visual approval is claimed.

## Remaining limits

Verify 40017360692 passed on source/test head `c8930d1d`; the follow-up is documentation-only and lead delta review remains pending. PR #93 stays draft. Accepted #83 and #85 are integrated through normal main merges with both siblings’ tests/status preserved. Integrate any later accepted sibling normally, and do not copy unaccepted branches. The bounded correction capture ended with the game process closed and desktop released to #96. No full-year replay or Neal visual approval was attempted.
