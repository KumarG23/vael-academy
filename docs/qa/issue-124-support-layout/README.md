# Issue #124 — Journal Supports compact/live resize

## Scope and plan alignment

This is a presentation-only repair to the existing Journal Supports page. It
follows MASTER_PLAN §§1–2, §4 “Supports & romance,” §6 WO-9.4/WO-9.7 and
partial §10 M9, with ACADEMY_BIBLE §3’s Common Hall / relationship context.
The existing `SupportState` and `Campaign.support_save` remain authoritative;
the Journal reads the current roster and authored Kai chains through the
existing #76 / PR #78 reference contract. Common Hall playback and completion
receipts are unchanged. No plan/bible contradiction was found.

At 640×360, the production Journal SubViewport measures its existing body and
footer. The measured body is `(85.2, 158.8, 469.6, 121.4)`; the prior
monolithic C/B/A/S block’s S-status glyph bottom would have been `288.8`, past
the actual footer glyph top at `262.2` (26.6 px overlap). The corrected layout
keeps one selected current
companion, preserves its existing rank and status text/font sizes, and pages
the status lines with PageUp/PageDown when measured body height requires it.
Up/Down continues to browse companions. The feedback names the visible status
range and total. The empty current-roster wording uses active-font word wrap.

## Automated evidence

- `tests/test_journal_support_layout.gd` drives the production Journal through
  a real SubViewport at 1280×720, 800×450 and 640×360; it measures heading,
  current companion/rank, status glyph rectangles and footer against the actual
  body, pages all existing C/B/A/S Viewed/Unviewed rows, checks first/final/
  wrap companion selection, empty/no-rank states, both resize directions,
  additional movement-key dispatch, actionless Enter, Left/Right tab behavior,
  manual/Autosave/settings byte invariance and ordinary save/reload.
- The maximum Liora display state is a clearly supplementary fixture built with
  the existing SupportState points/consent APIs. It reaches the authored 200
  point S threshold, declares the four existing viewed/unviewed receipts and
  does not play a conversation or claim natural romance earnings.
- The unchanged monolithic compact formula is tested against the production
  SubViewport body/footer to preserve the observed geometry failure as a
  regression case; production statuses are then checked for complete bounds
  and reachability at each supported size.
- Final dedicated Supports viewport/input suite: **7/7 tests, 105 assertions**.
- Clean Godot 4.7.2 import exited 0. The final full GUT run on the current source and tests under the shared
  Git-common `vael-godot-heavy.lock` and disposable XDG data passed **1,034/1,034
  tests, 22,680 assertions / 126 scripts**, exit 0 in 482.268s. The combined
  Journal/support/playback/keyboard/close/save/resume/dialogue→audio boundary
  passed **155/155 tests, 6,710 assertions / 19 scripts** before the two final
  manual/Autosave/settings byte-preservation assertions were added; those
  assertions are covered by the final dedicated and full runs. The paired
  dialogue→audio isolation boundary passed **24/24, 381 assertions** twice in
  the same disposable profile. Helpers found 113 tests: **111 passed, two
  existing opt-in skips**. The final full run reported 116 inherited GUT
  deprecation notices. A clean Godot 4.7.2 import exited 0.

## Native boundary and limits

No GUI authority was available for this change. The approved sequence is
#114 → #117 → #118 → #122 → #124, with explicit controller release and lead
naming at every handoff. No game window, native input or capture was launched
for #124, so no original-Forward+ runtime/layout claim is made for this head.
The draft PR records the single outstanding acceptance boundary: bounded
original-renderer real-key/default/compact/live-resize verification of the
complete maximum earned support record, normal Journal close/exploration and
Common Hall continuation, then ordinary save/fresh Title load with whole-state
and file comparisons. Reuse unchanged #76 Common Hall/reference evidence;
do not infer Neal visual approval.

Existing Roster/Calendar/Grades/Objectives/Items/System/keyboard behavior and
their evidence were not edited. The implementation changes only Supports
drawing/detail paging and input handling; no campaign, romance, support,
playback, progression, RNG, staging, save/settings schema or canon behavior is
added.
