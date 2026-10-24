# Issue #124 — Journal Supports compact/live resize

## Scope and plan alignment

This is a presentation-only repair to the existing Journal Supports page. It
follows MASTER_PLAN §§1–2, §4 “Supports & romance,” §6 WO-9.4/WO-9.7 and
partial §10 M9, with ACADEMY_BIBLE §3 Common Hall / relationship context. The
existing `SupportState` and `Campaign.support_save` remain authoritative; the
Journal reads the current roster and authored Kai chains through the existing
#76 / PR #78 reference contract. Common Hall playback and completion receipts
are unchanged. No plan/bible contradiction was found.

At 640×360, the production Journal SubViewport body is `(85.2, 158.8, 469.6,
121.4)`. Before the repair, the monolithic C/B/A/S block's S-status glyph
bottom was `288.8`, past the actual footer glyph top at `262.2` (26.6 px
overlap). The repaired layout retains one selected current companion, current
rank and all existing status text/font sizes. PageUp/PageDown exposes the
complete selected record when measured height requires pages and labels the
visible status range. Up/Down continues browsing companions. Empty current-
roster wording wraps at the active font.

## Automated evidence

- `tests/test_journal_support_layout.gd` drives the production Journal through
a real SubViewport at 1280×720, 800×450 and 640×360; it measures heading,
current companion/rank, status glyph rectangles and footer against the body,
pages every existing C/B/A/S Viewed/Unviewed row, checks first/final/wrap
companion selection, empty/no-rank states, both resize directions, additional
movement-key dispatch, actionless Enter, Left/Right tabs, manual/Autosave/
settings byte invariance and ordinary save/reload.
- The maximum Liora display state is a supplementary fixture built through the
existing SupportState points/consent APIs. It reaches the authored 200-point S
threshold and declares four existing receipts (C/A Viewed; B/S Unviewed). No
conversation plays and no naturally earned romance is claimed.
- The unchanged monolithic compact formula is measured against the production
SubViewport body/footer as a regression case; production statuses are checked
for complete glyph bounds and reachability at each supported size.
- Dedicated Supports viewport/input suite: **7/7 tests, 105 assertions**.
Clean Godot 4.7.2 import exited 0. Full GUT on the pre-integration source/test
head passed **1,034/1,034 tests, 22,680 assertions / 126 scripts**, exit 0
(482.268s); 116 inherited GUT deprecation notices. Helpers found 113 tests:
**111 passed, two existing opt-in skips**.
- The broader Journal/support/playback/keyboard/close/save/resume/dialogue→audio
boundary passed **155/155 tests, 6,710 assertions / 19 scripts** before two
final byte-preservation assertions were added; those assertions are covered by
the dedicated and full runs. Paired dialogue→audio isolation passed
**24/24, 381 assertions** twice in the same disposable profile.

## Native acceptance — original Forward+ on source head `c6bb0f37`

The lead named #124 as sole shared-desktop controller after #122's explicit
release. Native work used Godot 4.7.2, Vulkan 1.4.318 Forward+ on llvmpipe
LLVM 20.1.2, real X11 keyboard input and an isolated game-data profile. The
initial opened window was 1152×648. The exact target-size pass then kept the
Journal open through a live sequence of **1280×720 fullscreen → 800×450
windowed → 640×360 → 800×450 → 1280×720 fullscreen**. Runtime window and
viewport queries confirmed each client size. The `images/44`–`49` captures
show the exact-size sequence; `captures.json` records every retained capture's
pixel dimensions and SHA-256.

On the exact 1280×720 and 800×450 clients, Liora's complete S record fits on
one page. At 640×360, the active-font body keeps the heading, `Liora · Current
rank: S`, one complete status glyph, and the footer visible. The truthful hint
reports `statuses 1–1 of 4`; real PageDown input reached pages 2, 3 and 4, with
S **Unviewed** visible on the last page. Shrinking and restoring the same open
Journal kept Liora selected and restored the full record. Captures for all four
640×360 status pages are `images/08`–`11`; the combined live resize path's first
and last compact pages are `images/46`–`47`.

Real Right/Left moved between Journal tabs. Up/Down selected the first/final
current-roster records and wrapped at both ends; the shipped alternate `S`
`cursor_down` binding also selected the next companion. J and Escape closed the
Journal, after which ordinary movement continued. The Journal's existing
System action **Save — Slot 1** completed and displayed its normal confirmation.
That existing one-based Journal label writes data slot 0; the next independent
Title process loaded the saved file as Title **Slot 0**. The loaded record still
showed the same complete statuses. Empty/no-chain wording, no-rank behavior and
actionless Enter remain automated SubViewport cases; this native pass did not
claim those supplementary fixtures as naturally earned state.

The saved payload was then opened in the existing Common Hall through normal
campus → Great Hall → Common Hall walking. The existing bonds archive listed
Kai + Kael C/B and Kai + Liora C/B/A/S; its C and A receipts stayed checked,
and the unviewed B/S rows stayed unchecked. No entry was selected or played.
The full `support_save` hash before/after the archive was identical.

## Fixture, state and file comparisons

The source checkpoint is `docs/qa/issue-5-school-loop/emberwing-return-save.json`,
SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`.
`fixtures/maximum-support-supplemental-slot0.json` is a copy with only
`campaign.support_save` supplemented; it hashes to
`903851c838f8095253c867be2de18289e6e8bcd3e95c1f877988ccff3b612d36`. The
fixture keeps the checkpoint's week, house, units, RNG, flags and every other
campaign field intact. It supplies `kai_kael` B (60 points, C Viewed/B
Unviewed) and `kai_liora` S (200 points, C/A Viewed, B/S Unviewed), with the
existing consent/romance fields produced by the SupportState APIs. The fixture
is test display data, not a playthrough or earned-romance claim.

The runtime snapshots include the complete `Campaign.to_dict()`, active flag,
active house, `BattleView.next_resume`, current room, avatar position, door
arming and room-fade state. `reference-before-navigation.json`,
`reference-after-navigation.json`, `fresh-title-load.json` and
`fresh-load-after-navigation.json` are byte-identical (SHA-256
`99eca0dd50b36352bf9e436e8b90a0e73ccab201ccbe7e1aac8624bea9132e44`). Thus the
ordinary saved/fresh-loaded Campaign matched before reference navigation and
remained identical through tab/companion/detail/resize navigation. The
Common Hall full snapshot differs only after ordinary room visitation; its
support receipt hash still matches (`07b83609f6cf8f3596e4b482697027c2bb93a4e0c487601ac8e4bffade8bf686`).

The deliberate System save changed the manual file from the supplementary
fixture hash above to saved `saves/slot_0.json` SHA-256
`e1a25a815e31d551fd257263b54da55fced9e2545d9b373b4a5b70ff703cdcef`. After
that write, the manual file remained byte-identical across reference
navigation and the fresh Title load. `autosave.json` and `settings.cfg` were
absent before/after those read-only intervals. See the full Campaign snapshots,
fixture, image list and hashes in this directory; the temporary runtime log and
isolated profile are not included.

The window-size inspector was first queried with an invalid room property and
later with an untyped nullable local. Both temporary inspector scripts were
corrected; these did not change production code or gameplay state. Initial
windowed 1280-pixel captures clipped at the display boundary, so they were
rejected and are excluded; the exact 1280×720 evidence uses the verified
fullscreen viewport. No native gameplay script error or player-facing defect
was observed.

## Limits and delivery state

All native game/input/capture jobs ended normally; the shared desktop is
released. No full-school replay, replayed support scene, injected outcome,
canon change or Neal visual/taste approval is claimed. The graphical pass is
attributed to source head `c6bb0f37`; accepted #117 main `2d7ae523` was
integrated afterward without a production conflict, so its sibling System
behavior is not attributed to these captures. Accepted #117 main `2d7ae523` was then integrated normally; its System code/tests/QA remain intact. Under the common heavy lock and disposable XDG data, the combined Journal/System/Supports/playback/keyboard/close/save/resume/dialogue→audio/battle-resize boundary passed **131/131 tests, 15,854 assertions / 14 scripts**. No unchanged full baseline or GUI pass was repeated. Native captures above are attributed to pre-integration #124 source `c6bb0f37`. All graphical jobs ended and the shared desktop is released. Exact integrated-head Verify and lead review remain pending; the PR stays draft.

## Captures

- [Supports, exact 1280×720 fullscreen](images/44-fullscreen-support-liora-1280.png)
- [Live resize to 800×450](images/45-live-window-800x450.png)
- [640×360 status 1 of 4](images/46-live-window-640-page1.png)
- [640×360 status 4 of 4](images/47-live-window-640-page4.png)
- [Live resize to 800×450 with complete record restored](images/48-live-window-800-restore.png)
- [Restore to exact 1280×720 fullscreen](images/49-live-window-fullscreen-restore-1280.png)
- [All four compact status pages](images/08-640-support-page1.png), [2](images/09-640-support-page2.png), [3](images/10-640-support-page3.png), [4](images/11-640-support-page4.png)
- [Fresh Title load, maximum record](images/40-fresh-load-support-max-chain.png)
- [Common Hall bonds archive, no entry selected](images/35-common-hall-support-archive.png)

Exact source/checkpoint/fixture hashes are in [source-hashes.json](source-hashes.json); whole-state and file comparisons are in [comparisons.json](comparisons.json). The complete native capture hash/dimension index is [captures.json](captures.json).
