# GH-112 — Battle reference UI live resize

Implements child [#112](https://github.com/KumarG23/vael-academy/issues/112) of [#111](https://github.com/KumarG23/vael-academy/issues/111), from accepted main `300f146a4192e6078735827d496355c005e7650c`.

Basis: MASTER_PLAN §§1–2 (inspectable tactics, typed presentation separated from logic), §3 (unchanged combat math), §6 WO-9.4 (readable themed UI), WO-9.5 (forecast polish), partial §10 M9; ACADEMY_BIBLE §4 (ordinary tactical competition/lord defeat). No contradiction was found. No canon, combat, camera/input binding, progression, save schema, renderer or project setting changes.

## Repair and regression proof

The production BattleView in a real 1280×720 SubViewport reproduced the issue before source edits: both new tests failed, **42/57 assertions**. On shrink, objective stayed at `(860,10)`, hover at `(16,570)`, forecast at `(900,510)`, and inspection at `(40,235)` with height 250. The native baseline also exposed the disappearing references, but its compact X11 crops used an incorrect window-origin translation and were rejected; they are not published as valid compact captures. The exact baseline geometry evidence is the production SubViewport regression.

BattleView now recomputes only reference presentation on viewport changes and content/visibility updates. Compact headers wrap above the reference panels. Forecast and hover occupy separate lower lanes; inspection and hover use opposite lanes. An oversized inspection sheet reflows its existing fields into two balanced columns, with header and hover above it. The five-slot pack regression first demonstrated an out-of-client 361px sheet, then passes with complete fields retained. TextParagraph measures and paints the same active-font paragraphs; required text is neither clipped nor ellipsized, and existing font sizes remain. Word wrapping is adaptive only when needed. The three reference panels use the complete existing frame corner source slice within the unchanged destination margin, preventing ornament stretching through data. No new art or general UI framework.

## Automated checks and source attribution

All runs used the Git-common `vael-godot-heavy.lock` and disposable XDG data. Existing assertions were retained.

| Check | Actual result |
|---|---|
| Initial production regression on unchanged main | 0/2, 42/57 assertions |
| Early affected camera/mouse/hover/polish/forecast/keyboard/cycle/turn/exchange/prep/save boundary, before final frame/pack refinements | 114/114, 5,155 assertions / 14 scripts |
| Clean-cache import on base, followed by cached import of implementation | Both exit 0; no script-load errors |
| Full baseline at `results.json`'s `native_source_first_pass` hashes, before the added full-pack reflow | 1,017/1,017, 20,930 assertions / 124 scripts, exit 0, 477.451s |
| Helper baseline | 113 discovered, 111 pass, two existing opt-in skips |
| Final proportional boundary after full-pack reflow | 55/55, 3,774 assertions / 7 scripts, exit 0, 15.933s |

The final boundary includes eight new resize tests plus existing polish, camera, mouse, stationary-hover (#72), keyboard/custom control and cycling suites. It checks initial compact viewports, shrink/restore while references are open, both forecast columns, shipped long labels, every shipped inspection kit/role hint, promoted/full five-weapon packs, active-font glyph/paragraph bounds, header/hint separation, any-key/click dismissal, objective wording, full state invariance, and real forecast cancel/confirm with identical complete resolver/RNG/support/roster results against an unresized run. Broader turn, prep, exchange, saves, dialogue, busy/results gates remain covered by the affected group/full baseline and final exact-head CI. The later pack/extra test delta uses proportional local checks; final full clean-import/GUT/helper coverage is the PR's exact-head Verify, not a claimed second local full run.

The full baseline reports 76 inherited deprecations and existing exit-time two ObjectDB/one resource diagnostics. The final boundary reports two deprecations and the same exit diagnostics. Existing popup tests record their expected headless screenshot read-back errors; no new script-load error was observed. Exact-head Verify is linked on the PR.

Reproduce the new suite:

```sh
profile=$(mktemp -d)
flock -x "$(git rev-parse --git-common-dir)/vael-godot-heavy.lock" env XDG_DATA_HOME="$profile" godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_reference_resize.gd -gexit
```

## Native evidence — 2026-10-24

Original **Godot 4.7.2 / Vulkan 1.4.318 Forward+ / llvmpipe LLVM 20.1.2**, existing 1280×720 X11 desktop. Real `xdotool` keyboard/pointer events; window-manager fullscreen for 1280×720 and real client resizing for 800×450/640×360. Captures use X11 absolute **client** origin from `xwininfo`, not the differently translated `xdotool` window position. Renderer/project settings unchanged. All 22 curated full-client captures were inspected. [Source/file hashes and structured comparisons](results.json), [artifact hashes](manifest.json), [snapshots](snapshots/).

The game loaded the unchanged [#39 earned round-3 Emberwing battle](../issue-39-three-house-contests/saves/emberwing-opening.json) through **Title → Load Game → Slot 1**, SHA-256 `c156c62b43e6d6f48002d50f787751e708ec03cdef3378ceadddcd806e99a4d3`. This is existing earned progression, not a fresh deployment or a new school playthrough. The optional-key setup used the shipped Campus Dev Jump solely to enter Journal → System → Keyboard Controls: Up I / Down U / Left L / Right O / Confirm P / Cancel N. That Campus setup is supplementary, not earned. The installation then returned to Title and loaded the earned checkpoint.

Observed through real input:

- Hover Kael at `(3,12)`, then default → 800×450 → 640×360 → 800×450 → default. Name/class/level/HP/XP, bars, objective, terrain header and ordinary hints remain readable. [Compact hover](images/hover-640-360.png).
- Select Kael, move normally to `(8,12)`, choose Attack/equipped weapon and target Marlow `(9,12)`. Both forecast columns retain names, HP and damage/hit/crit through the same resize sequence beside hover. [Default](images/forecast-1280-720.png), [800×450](images/forecast-800-450.png), [640×360](images/forecast-640-360.png). Native sample is ordinary counter-capable combat; no-counter/doubling and long-name variants are automated fixture evidence.
- Configured N cancels forecast to command menu, then undoes movement. Configured P selects and I/U/L/O move the cursor, then N cancels without spending state. Wren `(3,13)` → ordinary command menu → Stats shows the complete Emberlight Rod and healer restriction at all sizes. V dismisses by the existing any-key rule; normal menu cancel continues. Real pointer selection, Stats and resized-sheet click dismissal also pass. [Compact Wren](images/stats-640-360.png), [pointer sheet](images/pointer-stats-640.png).
- A later configured P confirms one ordinary native Kael→Marlow exchange. Marlow yields normally; RNG advances only for that combat. PageDown then selects Dain, with select/cancel continuation. No HP, result, RNG or action outcome was injected. [Forecast before actual confirm](images/custom-confirm-forecast-640.png), [map return](images/normal-combat-continuation-640.png), [continuation](images/normal-menu-continuation-640.png).

Each reference resize interval compared the entire save payload (whole active Campaign, battle RNG/state, roster/progression, supports), cursor, phase, selection, move origin and busy state. Captured comparisons agree; normal movement/combat are separate intentional actions outside those intervals. [Before file hashes](files-before.json), [after original pass](files-after.json), [after final delta](delta-files-after.json) are identical for all three manual files, Autosave and post-configuration settings. Additional comparison files were copied unchanged from #39 but never loaded/written: Tidemark opening in Slot 2, Thornrook opening in Slot 3, Emberwing opening in Autosave.

The final source delta has separate evidence, rather than attributing earlier captures to a later source:

- **Supplementary full-pack fixture:** fresh production BattleView, existing Brenna promotion (`Bastion`), five shipped weapon resources. No campaign activation or save writes; no claim of earning those items/promotion. Real menu input opens Stats, then default/800×450/640×360/shrink/restore preserve complete fields and recorded state. [Default](images/supplementary-pack-0-1280-720.png), [800](images/supplementary-pack-1-800-450.png), [640 wide reflow](images/supplementary-pack-2-640-360.png), [restored](images/supplementary-pack-4-1280-720.png). Wide-sheet pointer dismissal returns normally. Current hover intentionally retains its existing UnitDef class convention; inspection retains its existing promoted-class convention.
- **Earned delta recheck:** a fresh Title load of the same unchanged earned checkpoint exercises ordinary Wren Stats at all three sizes and both resize directions, configured close/cancel, cycling, select/cancel and file comparisons. [Final compact](images/earned-final-2-640-360.png), [final restored](images/earned-final-4-1280-720.png). The ordinary sheets keep the previously captured layout; only oversized sheets use the new reflow.

Source SHA-256 groups in `results.json` distinguish the first earned pass/full automated baseline from the final promoted-pack/earned delta. Captures without a delta prefix belong to the former; `supplementary-pack-*` and `earned-final-*` belong to the latter. Intermediate invalid/empty-hover/cropped captures were rejected, not curated.

GUI inventory was checked before each acquisition. [Initial claim](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385409643), [first release](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385514401), [bounded delta claim](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385597634), [final release](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385623578). All graphical game/input/capture jobs ended normally. No full-school replay, other-route native qualification, future arbitrary-font guarantee or Neal visual/taste/canon approval is claimed. M9 remains partial; lead reviews and merges.
