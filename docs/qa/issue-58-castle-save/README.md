# Issue #58 — castle save feedback

## Result

On the integrated issue #58 source with accepted #42 Castle prompt layout, both castle save entry points report the real slot-write result. The actual Escape menu and War Room interaction each showed success after an ordinary save, `Save failed. Please try again.` while a disposable sibling `.tmp` directory blocked the write, and success after removing that directory and retrying. The Escape menu dismissed on both outcomes; the War Room prompt remained available. No save migration, campaign mutation, Journal/battle behavior change, canon or story edit was made.

## Runtime and fixture provenance

- Tested source commit: `0b42639f2d2b4c34ccf6fcaf4e3504f65b697b84` (issue #58 implementation integrated with accepted #42). Godot 4.7.2, the project's Forward+ renderer, a real X11 game window, and keyboard input sent to that window. The client capture size was 1280×669.
- All game data used a fresh disposable `XDG_DATA_HOME`. Slot 0 and slot 1 began as copies of the checked-in [Emberwing Week 2 return fixture](../issue-5-school-loop/emberwing-return-save.json), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`.
- Title → Load Game → Slot 0 entered the campus at Week 2. Escape → Save Game exercised `_do_system(0)`. Then ordinary keyboard movement through the campus and Entrance Hall reached the War Room's “Record the day's log” point; `ui_accept` exercised the actual interaction handler.
- After a successful write, the sibling `slot_0.json.tmp` path was made a directory to produce a deterministic real open failure. The slot 0 bytes remained SHA-256 `3f022dcfccd56c912df7f72dd2fa0fed358daf91cdc3c8291c5cd27fb0f91fd6` through the failure and subsequent successful retry; slot 1 remained byte-for-byte unchanged at `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. The directory was removed before each retry. The saved envelope remained version 1 / slot 0 with the Week 2, semester 1 Emberwing campaign; the live Week 2 HUD and player position remained in the castle.
- Captures are actual 1:1 captures of the native game window. They were inspected after each route. No checked-in fixture or real player save was modified.

## Captures

| Route | Success | Induced failure | Retry success |
| --- | --- | --- | --- |
| Escape → Save Game | [capture](images/escape-save-success.png) | [capture](images/escape-save-failure.png) | [capture](images/escape-save-retry.png) |
| War Room → Record the day's log | [capture](images/war-room-save-success.png) | [capture](images/war-room-save-failure.png) | [capture](images/war-room-save-retry.png) |

[Escape menu before saving](images/escape-menu.png) shows the existing Save Game choice. On the failure captures, the failure toast is visible after the system menu closes / while the War Room prompt remains available.

## Checks and scope

- Regression-first production-handler tests failed on the unchanged accepted-main handlers at both induced failures (0/1 tests, 24/26 assertions). Repaired tests drive the actual War Room interaction and Escape-menu confirmation, use real disposable JSON IO, verify successful writes, deterministic `.tmp` open failures, prior and neighboring slot bytes, live Campaign state, menu behavior and successful retries.
- After integrating accepted main `f64d2522` (issue #42), focused castle, toast/date layout, SaveSystem, Journal and battle-save checks passed **70/70 tests, 1,482 assertions**. A subsequent clean Godot 4.7.2 import exited 0, and full GUT passed **832/832 tests, 12,172 assertions, 105 scripts** (220.706 s) under the common heavy lock with disposable player data. It reported 22 deprecations and the existing exit-time ObjectDB/resource diagnostics; no script-load errors. Existing Journal and battle save behavior stayed covered.
- Plan and bible basis: MASTER_PLAN §§1–2, §6 WO-4.3/4.4/9.6 and §10 AW-74–76; ACADEMY_BIBLE §3 (walkable school). No relevant canon contradiction was found. This is ordinary feedback for an existing save action, with no story/design decision or Neal visual approval implied.
