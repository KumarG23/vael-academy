# Issue #117 — Journal System rows readable in compact windows (native QA)

Plan basis: MASTER_PLAN §§1–2, §6 WO-9.4/9.6, partial §10 M9; ACADEMY_BIBLE §3. Presentation repair only; no canon contradiction, **no Neal taste/visual approval claimed**, not a full-school replay.

## Environment and sources
- Tested source: `3c10c7802d33c9d2b9f7900f09050bd602cbb40f` (System implementation + accepted main `8b442f13`). `academy_journal.gd` unchanged by the QA.
- Original Godot 4.7.2 / Vulkan 1.4.318 Forward+ / llvmpipe LLVM 20.1.2 on the shared 1280×720 X11 desktop (xfwm4). Real `xdotool` key events; window client resized with `xdotool windowsize` (1152×648 default window, 800×450, 640×360); captures with `scrot -u`. Disposable `XDG_DATA_HOME`.
- **Earned fixture:** `docs/qa/issue-5-school-loop/emberwing-return-save.json`, SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`, slot 0, loaded through ordinary Title → Load Game. Unchanged after every step.
- **Supplementary (declared, NOT earned):** slot 1 = `emberwing-rite-start.json` (live battle), SHA-256 `f572791a377b78cacf40f957d3a81bc66cddc17608633656da67e93bd18d268d`, unchanged; slot 3 was first empty, then the QA's deliberate save; later a hand-made invalid slot-3 file `{"version":1,"campaign":"broken"}` (SHA-256 `d85a5708…a1f6`) replaced it, copy of the deliberate save kept outside the repo.
- Capture hashes: `manifest.sha256`. All captures listed below were viewed.

## Observed
- **Default window** ([first row](images/sys_default_first.png), [restored after live resize](images/s_default_restored.png)): all twelve rows, empty/occupied/mid-battle summaries (`mock_battle · Casual`, `⚔ mid-battle`, `— empty —`), three bars + percentages, text speed, key summary visible; no windowing hint.
- **800×450** ([top](images/s800_first.png) rows 1–7/12, [bottom, Up from first wraps](images/s800_final_keyboard.png) rows 6–12/12) and **640×360** ([top](images/s640_first.png) 1–4/12, [mid](images/s640_row6.png) 3–6/12, [final](images/s640_final_keyboard.png) 9–12/12): selected row always visible, all text at one readable size, `↑/↓ more · rows a–b / 12` clear of footer. Live shrink and restore (1152→800→640→800→1152) kept the selected row.
- **Settings:** Left on Music 70→60 %, Right on Text Speed Normal→Fast ([capture](images/v_textfast.png)). **Editor** at [640](images/ed640.png)/[800](images/ed800.png) (accepted #89 layout, unchanged); Up←`I`, Down←`N`; Esc returns to System with Keyboard Controls still selected and `Default + 2 additional` ([capture](images/back_from_editor.png)).
- **Custom keys:** N/I browse System (wrap to Save Slot 1, back to final row after reload — [capture](images/n_to_keyboard_after_load.png)).
- **Intentional save** to Save — Slot 3 (`Saved to slot 3`, [capture](images/saved_slot3.png)); **load** Load — Slot 1 reloaded the castle; System reopens working. Esc closed it; held Right walked the player with no menu leak ([walked](images/walked.png)).
- **Fresh launch persistence:** custom `N` worked on Title; Load shows three slots ([title](images/f_title_load.png)); System shows 60 %, Fast, `Default + 2 additional` ([default](images/f_system_default.png), [640 final](images/f_640_final.png)).
- **Supplementary:** invalid slot 3 → `Slot 3 couldn't be loaded — choose another slot.`, Journal stayed open, retry gave the same message, file bytes unchanged ([capture](images/inv_load_reject.png)); Load — Slot 2 (live battle) resumed into the battle ([capture](images/midbattle_resume.png)).

## Deliberate writes vs invariants
- Browsing/resizing/editor navigation/failed loads wrote nothing; slot 0/1 hashes unchanged throughout.
- Deliberate: `settings.cfg` (`music 0.6`, `text_speed fast`, `[keyboard] up=I down=N`, final SHA-256 `1b5430da3bfbcead5ac9…`) and `slot_2.json` (save, SHA-256 `75f79485…efbce7`).

## Findings / limits
- **Toast overlap (not System data):** at 640×360 the existing 2.2 s toast (`Saved…`, `Text speed…`, load rejection) covers the `↑/↓ more · rows` hint and footer; selected row and data remain readable. Shared toast sizing belongs to #114 — not changed here.
- **Title (out of scope):** the Title Load Game menu clips `⚔ mid-battle` ("mid-bat") in its panel at the default window, and lists slots 0-based while the Journal is 1-based. Pre-existing; not touched.
- Observed natively vs automated: native covers the flow above on one machine/renderer; exhaustive row/size/volume/speed/key-count geometry is automated (`tests/test_journal_system_compact.gd`). 1152×648 stands in for the "1280×720" class; the 640×360/800×450 windows are real client resizes. Only one extra-key count (2) was observed natively (0 and 6 are automated). No Casual/Classic contrast was observed natively (earned fixture is Casual).
- Process note: the first game instance did not exit on SIGTERM and a second instance was started by mistake; both were killed (`pkill`) and the QA re-run from a clean launch. No game/input/capture process remains.
