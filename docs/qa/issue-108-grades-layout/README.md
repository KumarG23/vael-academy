# Issue #108 — Journal Grades readable in compact windows

Plan basis: MASTER_PLAN §§1–2, §6 WO-9.4/9.7, partial §10 M9; GRADING_SYSTEM §§1–3; ACADEMY_BIBLE §§3–4. Existing-data presentation/input repair only; no canon contradiction found, no Neal visual approval claimed.

## Native runtime acceptance (original renderer)

- Tested source: `ffd3a16b5ef67121c187b7394ffdb595914b0b53` (includes accepted main `0b54e16b`, #96 Roster, merged normally). Godot 4.7.2, Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2, native X11 key events via xdotool, window captures with scrot, disposable `XDG_DATA_HOME`.
- **Earned fixture:** the Week-2 Emberwing return checkpoint (`docs/qa/issue-5-school-loop/emberwing-return-save.json`), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`, copied byte-for-byte to the disposable profile and loaded via Title → Load Game → Slot 0. Hash identical after the run; no save/settings file was written by QA.
- Flow: J → Right×3 (Grades). 1280×720 class (1152×648 window): every field, all four complete hints, weights, no-data states and the next-report-card line fit on one page ([01](images/01-grades-default.png)). Live resize to 800×450 ([top](images/02-grades-800-top.png), [final](images/04-grades-800-final.png)) and 640×360 ([top](images/05-grades-640-top.png), [mid](images/07-grades-640-down3.png), [final](images/08-grades-640-final.png)): Up/Down browse item by item with a visible `↑/↓ browse a–b of N` line; hints wrap under their mark. Restored live: [09](images/09-grades-restored.png). Enter did nothing ([10](images/10-confirm-actionless.png)); Left/Right returned to Grades at the top; J closed and held Right walked the player ([13](images/13-campus-walked.png)) — no system menu or leak.
- **Defect found and fixed by this QA:** the first native 640×360 pass showed only the header on page 1 (the 54 px rank block did not fit). Compact bodies now use a 40 px rank glyph and tighter padding; the first page shows header + standing; `test_journal_grades_layout.gd` now asserts that at every size. Captures above are from the fixed source.
- **Supplementary fixture (declared, NOT earned):** a disposable-profile copy of the checkpoint with `semester=2, week=4` and one locked Semester-1 card (B / Accomplished / 70), delivered flag true, SHA-256 `6bba057cfbc667652ce4db203f5da26e793e274430d3776490d7fe917a8336f7`. It exercises history at default ([20](images/20-history-default.png)) and 640×360 final page ([21](images/21-history-640-final.png)). The Week-4 festival dialogue on load was dismissed with Enter before capturing.
- All game/input/capture jobs ended (no godot process remains).

## Native custom-key continuation (lead request, same source)

- Fresh disposable profile with the earned Week-2 checkpoint (slot SHA-256 `681e0c32…1b1fe4`, identical after the run). Journal → System → Keyboard Controls (existing #89 editor): Up ← **I**, Down ← **N** ([capture prompt](images/c3-capture.png), [both assigned](images/c7-both-assigned.png)). An attempt to use K was correctly rejected (reserved Dev Jump key) and cancelled with Esc. These two assignments are the *intentional* settings write: `settings.cfg` = `[keyboard] up="I" down="N"`, SHA-256 `616550e1671adc6fd6303c7224fdc9f3f9ba4e902ee6d1eacefa4048e6864f83`; it was unchanged by everything after.
- At 640×360 on Grades: N ×2 → items 3–3 of 7 ([c9](images/c9-n-twice.png)); N to the end → 6–7 of 7 ([c10](images/c10-n-final.png)); I back up one page → 5–5 ([c11](images/c11-i-up1.png)); I to the top. Enter did nothing ([c13](images/c13-confirm-actionless.png)); J closed the Journal and held Right walked normally with no system menu ([c15](images/c15-walked.png)). No save slot was added or changed. Game closed; no godot process remains.

## Accepted #106/#98 integration boundary — bounded native continuation

- Source: merge of accepted main `300f146a` (#106 Objectives + frame/footer/title chrome, #98 test isolation) into this branch, head `98b67e16`. Same original Forward+ llvmpipe, native X11 input, fresh disposable profile, earned Week-2 checkpoint (slot SHA-256 `681e0c32…1b1fe4`, unchanged).
- The accepted chrome fixes the earlier overlap: title/Purse and the footer hint are clear of the frame ornaments at default and 640×360, with the new Objectives tab in the tab row ([default](images-integrated/d1-grades-default.png), [640 top](images-integrated/d4-640-top.png), [640 final](images-integrated/d5-640-final.png)). 800×450 and live resize/restore were exercised in the run.
- Custom keys again via the #89 editor (Up=I, Down=N; `settings.cfg` SHA-256 `616550e1…864f83`, the intentional write, unchanged afterwards): [assigned](images-integrated/d7-keys-assigned.png), N/I browsing at 640×360 ([d8](images-integrated/d8-n3.png)), actionless Enter, consumed J close, held Right walking ([d11](images-integrated/d11-walked.png)); no slot added or changed.
- Supplementary (not earned) history fixture from the earlier section (SHA-256 `6bba057c…8336f7`, unchanged): [default](images-integrated/h1-history-default.png), [640×360 final](images-integrated/h2-history-640-final.png).
- Headless after integration (heavy lock, disposable data): Grades/Objectives/Roster/Calendar/Journal/close/keyboard/grading/report-card/save/Campaign selection 150/150 (3,214 assertions / 15 scripts); the accepted dialogue→audio preference adverse-order pair run twice with reused data: 24/24 each (381 assertions). All game jobs ended.

## Limits


- The earlier title/footer frame-ornament overlap was pre-existing shared chrome and is resolved by accepted #106 (see integration section); the first-run captures above predate it.
- No full-school replay. Exact-head Verify and lead review pending.
