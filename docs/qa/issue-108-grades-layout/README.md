# Issue #108 — Journal Grades readable in compact windows

Plan basis: MASTER_PLAN §§1–2, §6 WO-9.4/9.7, partial §10 M9; GRADING_SYSTEM §§1–3; ACADEMY_BIBLE §§3–4. Existing-data presentation/input repair only; no canon contradiction found, no Neal visual approval claimed.

## Native runtime acceptance (original renderer)

- Tested source: `ffd3a16b5ef67121c187b7394ffdb595914b0b53` (includes accepted main `0b54e16b`, #96 Roster, merged normally). Godot 4.7.2, Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2, native X11 key events via xdotool, window captures with scrot, disposable `XDG_DATA_HOME`.
- **Earned fixture:** the Week-2 Emberwing return checkpoint (`docs/qa/issue-5-school-loop/emberwing-return-save.json`), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`, copied byte-for-byte to the disposable profile and loaded via Title → Load Game → Slot 0. Hash identical after the run; no save/settings file was written by QA.
- Flow: J → Right×3 (Grades). 1280×720 class (1152×648 window): every field, all four complete hints, weights, no-data states and the next-report-card line fit on one page ([01](images/01-grades-default.png)). Live resize to 800×450 ([top](images/02-grades-800-top.png), [final](images/04-grades-800-final.png)) and 640×360 ([top](images/05-grades-640-top.png), [mid](images/07-grades-640-down3.png), [final](images/08-grades-640-final.png)): Up/Down browse item by item with a visible `↑/↓ browse a–b of N` line; hints wrap under their mark. Restored live: [09](images/09-grades-restored.png). Enter did nothing ([10](images/10-confirm-actionless.png)); Left/Right returned to Grades at the top; J closed and held Right walked the player ([13](images/13-campus-walked.png)) — no system menu or leak.
- **Defect found and fixed by this QA:** the first native 640×360 pass showed only the header on page 1 (the 54 px rank block did not fit). Compact bodies now use a 40 px rank glyph and tighter padding; the first page shows header + standing; `test_journal_grades_layout.gd` now asserts that at every size. Captures above are from the fixed source.
- **Supplementary fixture (declared, NOT earned):** a disposable-profile copy of the checkpoint with `semester=2, week=4` and one locked Semester-1 card (B / Accomplished / 70), delivered flag true, SHA-256 `6bba057cfbc667652ce4db203f5da26e793e274430d3776490d7fe917a8336f7`. It exercises history at default ([20](images/20-history-default.png)) and 640×360 final page ([21](images/21-history-640-final.png)). The Week-4 festival dialogue on load was dismissed with Enter before capturing.
- All game/input/capture jobs ended (no godot process remains).

## Limits

- Custom-key browsing is verified headless only (`test_custom_keys_browse_and_tab_or_reopen_resets`), not natively.
- Pre-existing, unchanged shared chrome: at these window sizes the gold frame ornament overlaps the "Academy Journal" title/Purse and the left of the footer hint on every tab. Not touched here (shared draw code); flagging for a separate issue.
- No full-school replay. Exact-head Verify and lead review pending.
