# Issue #136 — Fish Log complete-string layout

## Scope and references

This repairs the existing Journal Fish Log only. It follows MASTER_PLAN §§1–2 (preserve authored scope and existing state contracts), §6 WO-6.4 (fishing results persist through save/load), §6 WO-9.4 (active UI theme), §6 WO-9.7 (Fish Log display), and partial §10 M9. ACADEMY_BIBLE §3 places fishing at the castle grounds/waterside and describes the activity as a separate existing system. The accepted #68 / PR #73 read-only Fish Log contract remains in force. The issue fixture's unknown key and large count are explicitly supplemental accepted-save display cases, not new species, rewards, or naturally earned quantities. No contradiction with the owning documents was found.

## Reproduction and repair

The regression-first production `AcademyJournal` / `SubViewport` test using `UITheme.font()` reproduced the original fixed-width draw failure: the `123456789` quantity exceeded the old 64 px count column at 1280×720, 800×450, and 640×360; the long declared unknown key exceeded the old `body.width - 100` name column at 640×360. Existing tests had checked stored values rather than all rendered text.

The existing Fish Log now measures wrapped glyph lines and row heights with the active font. It keeps the selected row fully visible, admits surrounding rows only when they fit above the existing browse hint, and keeps the shared footer outside the body. Names, quantity conversion, ordering, tab indices, wording, and font sizes are unchanged; no ellipsis, count clamp, save normalization, or shared-footer/tab redesign was added.

## Automated regression evidence

`tests/test_journal_fish_log_compact.gd` runs the production Journal Control and actual draw layout for empty state, all four shipped names, the declared long unknown key, and counts including `123456789`. It checks complete rendered strings, glyph/row/body bounds, heading/hint/footer clearance, every entry reachable through selection, and live shrink/restore at 1280×720, 800×450, and 640×360. The input/state test covers rebindable Up/Down, first/final wrap, actionless Enter, complete Campaign/RNG equality, three manual slots, Autosave and audio/dialogue/keyboard settings byte equality, and an ordinary SaveSystem load round trip. It compares the existing displayed integer conversion after load rather than changing malformed-save conversion semantics.

The initial regression failed against the original fixed-width implementation. The corrected focused Journal/Fish Log tests passed **7/7, 282 assertions**. Full GUT, helper tests, clean import, and final exact-head Verify results are recorded in the PR after completion.

## Native runtime evidence

Godot 4.7.2, original Forward+ renderer, X11/Xvfb, real `xdotool` window input, ordinary Title → Load of the unchanged earned checkpoint, then Journal open / Fish Log selection / live size changes / close / exploration movement. All game and capture jobs exited normally and slot A was released.

The source checkpoint SHA-256 is `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`. Across default → 800×450 → 640×360 → restored default, `xwininfo` reported the requested client dimensions for every capture. The unchanged checkpoint slot hash was `505feade82c9c3b7dd8a52690edb2ce4dc4062069c62a765faf3897d2c14e59c` both before and after normal browsing. The isolated empty profile hash was `a193c20429d64a9d27fbfea2edae9144622a7e99f90ad8792173d20986cdbb7e` before/after; the supplemental profile hash was `f2118d54b9c8bd188638900c065bbc4269c874b42302d9cfda04dd21922513c8` before/after. No settings or Autosave files appeared in any profile. The automated production regression independently compares Campaign/RNG state and all manual/Autosave/settings bytes byte-for-byte.

Screenshots are full 1280×720 display captures. Compact game windows occupy the requested upper-left client area; the black remainder is the unused Xvfb desktop.
SHA-256 for the unchanged source checkpoint and each committed capture: [capture hash manifest](capture-sha256.txt). Private slot logs and machine-local paths are intentionally omitted.

- Existing earned checkpoint: [default](images/checkpoint-fish-default.png), [800×450](images/checkpoint-fish-800.png), [640×360](images/checkpoint-fish-640.png), [restored](images/checkpoint-fish-restore.png), [normal exploration after close](images/checkpoint-exploration-after-close.png).
- Empty state: [default](images/empty-fish-default.png), [800×450](images/empty-fish-800.png), [640×360](images/empty-fish-640.png), [restored](images/empty-fish-restore.png), [normal exploration after close](images/empty-exploration-after-close.png).
- Declared supplemental accepted-save cases: [first row and complete record](images/supplemental-first-default.png), [Up wrap to final row](images/supplemental-wrap-final.png), [large quantity at 640×360](images/supplemental-large-count-640.png), [large quantity at 800×450](images/supplemental-large-count-800.png), [restored](images/supplemental-large-count-restore.png), [long key at 640×360](images/supplemental-long-name-640.png), [long key at 800×450](images/supplemental-long-name-800.png), [restored](images/supplemental-long-name-restore.png), [normal exploration after close](images/supplemental-exploration-after-close.png).

The supplemental profile contains the four shipped names plus `Unknown Accepted Save Catch With a Deliberately Long Name` and `Silver Dace ×123456789`. It was seeded only for rendering/input QA from the unchanged checkpoint; this does not claim those supplemental values were naturally earned. `capture_slot.sh` documents reproducible input/capture steps. Captures are source-specific to this issue branch. No full-school replay, repeated fishing sequence, canon change, or Neal visual approval is claimed.
