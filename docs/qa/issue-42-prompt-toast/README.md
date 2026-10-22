# Issue #42 — castle prompt and wrapped feedback

## Result

On the PR game source at `ea949be82ae941f7159a080e3b53f1ed4d1c4ca5`, the Common Hall empty-archive feedback remains readable alongside the persistent interaction prompt at 640×360, 800×450, and restored 1280×720. At 640×360 the toast wraps to two lines and ends above the prompt; at 800×450 and 1280×720 it is one line with a clear gap. The Common Hall support archive also remained readable and its prompt stayed in view while the same game window was resized through 800×450 and 640×360.

The game was run with Godot 4.7.2 and the project's unchanged Forward+ renderer. Inputs were sent to a real native window. Navigation was Title → Load Slot 0 → walk through the castle to Common Hall → approach “Gather by the fire (bonds)” → Return. The empty archive retained the existing native Emberwing Week 2 return fixture with no unlocked Common Hall bonds. The window was resized in place from 1280×720 to 640×360, then 800×450, then restored to 1280×720; Return produced the existing “No bonds strong enough yet — fight beside your housemates.” feedback.

For the archive-open resize check, a disposable copy of the same fixture changed only `campaign.support_save.points.kai_kael` from 10 to 20, `campaign.support_save.ranks.kai_kael` from empty to `C`, and `viewed` to `{}`. This made the existing archive entry available for the layout check; it does not represent a naturally earned rank or a completed dialogue. The copy's SHA-256 is `219b9947da451152b2723675bd057e19435c6e9561052ccb24847a007e185900`. The source fixture is [`emberwing-return-save.json`](../issue-5-school-loop/emberwing-return-save.json), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. Both runs used disposable user data; the checked-in fixture and player saves were not modified.

## Captures

Each image is an actual 1:1 window capture at its listed client resolution.

| State | 640×360 | 800×450 | 1280×720 |
| --- | --- | --- | --- |
| Empty archive; wrapped feedback and prompt visible | [capture](images/empty-640-cycle.png) | [capture](images/empty-800-cycle.png) | [capture](images/empty-1280-restored.png) |
| Existing support archive open during resize | [capture](images/archive-640.png) | [capture](images/archive-800.png) | — |

The support archive was opened at 1280×720, then the client window was resized to 800×450 and 640×360. The two captures show the existing “Kai + Kael C” entry and interaction prompt both visible. The empty-archive cycle was separately restored to an exact 1280×720 capture.

## Automated checks and scope

The regression test [`test_castle_toast_layout.gd`](../../../tests/test_castle_toast_layout.gd) combines prompt and toast layout at supported sizes and exercises prompt placement after resizing while the archive/menu is open. It failed against the unchanged composition for the 640×360 overlap and stale/clipped prompt, then passed after the repair. The focused castle/toast/date group passed 31/31 tests (488 assertions); clean Godot import exited 0; integrated full GUT passed 831/831 (12,146 assertions, 105 scripts), exit 0. The exact integrated game-code head's GitHub CI passed; the subsequent main integration and this evidence update changed documentation only, not the game source or test.

This repair follows MASTER_PLAN §1 (walkable school slice), §6 WO-4.4 (playtest readability fixes) and WO-6.2a (usable Common Hall), and ACADEMY_BIBLE §3 (Common Hall as a shared social/support space). No conflict with those sections was found. Text, timing, support receipts, rewards, interaction behavior, story, and art are unchanged. No Neal visual approval is claimed.
