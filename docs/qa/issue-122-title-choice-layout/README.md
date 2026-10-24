# GH-122 — complete Title recovery summaries and shared ChoiceMenu layout

Parent: [#121](https://github.com/KumarG23/vael-academy/issues/121). Basis: MASTER_PLAN §§1–3, §6 WO-4.3 (Title/campaign flow), WO-4.4 (presentation repair), WO-9.4 (shared menus), WO-9.6 (save picker/recovery), partial §10 M9; ACADEMY_BIBLE §§3–4 (existing school/mission continuation). No canon change or contradiction found.

## Acceptance discrepancy

The original brief asked to preserve one-based slot numbers. The lead confirmed the source discrepancy and corrected criterion 1 to physical 0–2 ([receipt](https://github.com/KumarG23/vael-academy/issues/122#issuecomment-6386436274)). Accepted main Title actually displays the physical indices **0–2**; Journal uses one-based labels. Accepted PR #88 explicitly preserves this distinction, and the existing Title tests assert it. This repair preserves Title's existing text/physical mapping. [Reported before implementation](https://github.com/KumarG23/vael-academy/issues/122#issuecomment-6386330902); no renumbering or save-policy decision is inferred.

## Regression-first evidence

Accepted source: `8b442f13b34d86924cdb0fe374b49d7a7872649a`. Clean-cache import, Godot 4.7.2, original project configuration, headless only. A production TitleScreen and its actual ChoiceMenu were instantiated in a real SubViewport, resized through 1280×720, 800×450 and 640×360. Supplementary `_slots` metadata used the issue's complete routed chapter/mode/battle example and an Autosave chapter/week/mode example; no installation files or campaign were loaded.

The unchanged production implementation failed **1/1 tests (5/12 assertions passed)**:

- Active `UITheme.font()` at 20 px measured the complete manual battle label at **555 px**, while the old capped menu supplied only **400 px** to `draw_string`.
- The complete Autosave summary measured **493 px** against the same **400 px**.
- Both measurements failed at all three dimensions (six assertions).
- At 640×360, the whole drawn/hit rectangle extended beyond the viewport (seventh assertion).
- The existing 64 px fallback-font heading measured **621×88 px**. This is an active-font measurement, not a native screenshot or claimed GUI observation.

The regression case is retained and strengthened in `tests/test_title_choice_layout.gd`; its post-fix version verifies the actual wrapped drawing data and row geometry rather than accepting a too-wide single string.

## Implementation and automated evidence

ChoiceMenu retains its existing signals/input paths/font sizes/frame and 34 px short rows. TextParagraph measures adaptive word/character wrapping; drawing, height capacity, selection visibility and `row_at` share the measured rows. Only complete rows are drawn/hit; padding and hidden partial edges never alias another option. Width and both axes respond to live resize, preserving the requested position for restore. The default shared width cap remains 460 px. Title supplies its own available region and measured horizontal room, centers the panel and shifts the existing heading/subtitle proportionally at compact heights. Existing strings, assets, colors, default large-window heading, renderer, Campaign/Resume routing and all save semantics stay in their existing paths.

New production SubViewport tests cover all supported dimensions and shrink/restore; complete title, retry, chapter IDs, physical slot indices, Classic/Casual, week, mid-battle and Back; default/custom keyboard and real pointer input; variable-height reachability/first/final/hidden edges; hover/wheel/wrap/cancel and input consumed before callbacks. Title tests inject unique disposable save directories, preserve the incoming Campaign/RNG/support/progression and transient routing state, compare default-profile manual/Autosave/settings presence and bytes, restore state and remove fixture files. Deliberate fixture writes/removals are separate from read-only navigation intervals. Sparse, all-three occupied, empty, rejected occupied manual/Autosave and missing-after-browse paths are exercised. Existing campaign/load/resume child-process tests supply real successful deferred routing and exact battle restore coverage.

The old polish width test used the headless root's 64×64 viewport while expecting a width over 240 px. It now uses an explicit 1280×720 SubViewport; both original assertions are retained. No existing assertion was removed.

All Godot jobs use the Git-common-dir `vael-godot-heavy.lock` and disposable `XDG_DATA_HOME`, including inherited child processes. Raw host logs and private paths are intentionally absent from this record. Check totals and source hashes are recorded in `manifest.json`.

| Check | Actual result |
| --- | --- |
| Clean-cache import | Exit 0, no script-load errors |
| Implementation cached import | Exit 0, no script-load errors (8.914 s) |
| Helpers | 113 discovered, 111 pass, two existing opt-in skips |
| Affected 16-script boundary before the final hover-fixture correction | 156/157 tests, 7,255/7,256 assertions; every existing test passed; the sole new hover fixture omitted the viewport's mouse-enter notification |
| Corrected ChoiceMenu/Title/polish focus | 24/24, 1,949 assertions / 3 scripts (2.778 s) |
| Final shipped-ID/RNG-restoration refinement | **24/24, 1,970 assertions / 3 scripts**, exit 0 (2.716 s) |
| Full GUT | **1,038/1,038, 24,479 assertions / 127 scripts**, exit 0 (486.484 s GUT / 494.319 s process) |

Full GUT reports 99 inherited GUT deprecations and the existing exit-time two ObjectDB/one resource diagnostics; no script-load errors. After that baseline, the final test-only refinement replaces supplementary excess-length metadata IDs with exact shipped ChapterRegistry IDs and asserts/restores incoming training RNG identity/seed as well as serialized state. Production hashes are unchanged. Its focused result and exact-head CI are recorded separately; no unchanged local full baseline is repeated.

## Native evidence — complete on `1bb92da9`, 2026-10-24

[Lead naming after #117's explicit release](https://github.com/KumarG23/vael-academy/issues/122#issuecomment-6387634754). Process inventory was checked before opening. Original **Godot 4.7.2 / Vulkan 1.4.318 Forward+ / llvmpipe LLVM 20.1.2**, unchanged renderer/project settings, existing 1280×720 X11 desktop. Real `xdotool` keys/pointer, window-manager fullscreen and client resize at 1280×720 → 800×450 → 640×360 → restore. Captures use `xwininfo`'s absolute client origin, omitting desktop chrome. All **29 full-client captures were inspected**.

[Native results/source/checkpoint hashes/limits](native-results.json), [capture and snapshot hashes](artifact-hashes.json), [snapshots](snapshots/). Inspector requests read state only; navigation, load, New Game, preferences and continuation use real input. No state/outcome or position injection. Every process uses its own disposable XDG profile and holds the common Godot heavy lock, including graphical runs.

| Native observation | Evidence |
| --- | --- |
| Existing heading, stripes, fonts and main appearance; New Game complete Classic/Casual/Back, default/800/640/live restore, Back paging/click. | [Title](images/01-title-default.png), [800 New Game](images/02-new-800.png), [640 first page](images/02-new-640.png), [640 Back page](images/22-new-back-640.png) |
| Actual Classic and Casual selections enter the original opening with the proper mode, fresh Campaign, `opening_started`, active routing and cleared staging. No save/settings write. This is opening entry, not a story replay. | [Classic](images/04-classic-opening.png), [Casual](images/05-casual-opening.png), corresponding snapshots |
| Empty Load retains `(no saves found)`/Back, with real pointer Back. | [Empty compact](images/03-empty-load-640.png) |
| Default/800/640/live restore all-three summaries retain physical slots 0–2, complete shipped chapter IDs, Classic/Casual, mid-battle and separate Autosave/week. Wheel reaches every index and final Back; narrow sparse row wraps the complete tag. | [All default/restored](images/09-all-slots-1280.png), [800](images/09-all-slots-800.png), [640 first page](images/09-all-slots-640.png), [wrapped final manual](images/10-wheel-page-2-640.png), [final Back](images/10-wheel-page-4-640.png) |
| Occupied manual rejection stays selected and usable; retry preserves bytes/state. Autosave rejection clears manual status and retains the complete retry instructions, selected Autosave and Back. Heading/subtitle/status/menu/footer remain separate. | [Manual compact](images/11-invalid-manual-640.png), [manual default](images/12-invalid-manual-default.png), [Autosave default](images/13-invalid-autosave-default.png), [Autosave compact](images/14-invalid-autosave-640.png) |
| Deliberate external file removal after browsing keeps the same entry on retry, without fallback. Manual reports empty; Autosave retains retry/Back. Reopening sparse browse shows physical Slot 2 and clicking it dispatches the exact saved Thornrook Classic battle. | [Missing Autosave](images/15-missing-autosave-retry-640.png), [missing manual](images/16-missing-manual-640.png), [sparse Slot 2](images/17-sparse-physical-2-640.png), [correct battle](images/18-sparse-battle-dispatch-640.png), [native cycle/select/cancel continuation](images/19-sparse-native-continuation-640.png) |
| Default and shipped-editor configured **Down U / Confirm P / Cancel N**, pointer hover, click, right-cancel and wheel work. Selected Autosave survives 640→800→default→640; complete state and post-configuration files agree. | [Custom selected Autosave](images/23-custom-selected-autosave-640.png), [restored](images/24-custom-autosave-restored-640.png), [before](configured-files-before.json), [after](configured-files-after.json) |

### Earned checkpoints and intentional effects

The ordinary battle load uses the **unchanged earned #39 round-3 Emberwing checkpoint**, [`emberwing-opening.json`](../issue-39-three-house-contests/saves/emberwing-opening.json), SHA-256 `c156c62b43e6d6f48002d50f787751e708ec03cdef3378ceadddcd806e99a4d3`. Title → Load → pointer Slot 0 routes into `mock_battle.tscn`; every original serialized field matches. The complete current save payload matches after supplying only the existing legacy defaults `campaign.academy_visits=[]` and `campaign.report_card_deliveries=[]` and excluding the file-only `slot` key. Native Kael select → one-cell move → **Wait** continued normally at 640×360; no outcome was injected or save written. [Load menu](images/06-earned-load-default.png), [loaded battle](images/07-earned-battle-loaded.png), [ordinary continuation](images/08-earned-native-wait-continuation-640.png). All three manual files, Autosave and settings presence/bytes match [before](earned-files-before.json) / [after](earned-files-after.json).

Valid Autosave recovery uses the **unchanged earned #85 Week-4 settled-rest checkpoint**, [`week-4-autosave.json`](../issue-85-rest-autosave/week-4-autosave.json); its exact SHA-256 is in `native-results.json`. Selecting the named Autosave restores the **entire Campaign exactly**, including training RNG, supports, grades/receipt, inventory/progression and visits, then enters the campus. Existing hub entry consumes the skip-reset flag and sets `active=false`; that existing behavior is preserved. Ordinary physical movement continues without replay or payout. [Recovered campus](images/20-earned-autosave-loaded.png), [movement](images/21-autosave-native-movement.png). Only afterward, the shipped Journal keyboard editor deliberately writes the three optional aliases to `settings.cfg`; all manual/Autosave bytes remain unchanged and the subsequent Title/reference interval preserves the post-configuration settings bytes too.

Supplementary recovery profile: Slot 0 copies unchanged #39 Tidemark opening; Slot 2 copies unchanged #39 Thornrook Classic opening. These are declared alternate checkpoint fixtures for long labels/physical mapping, not a new earned route qualification. Slot 1 derives from the earned Week-2 campaign but deliberately sets `flags=[]`, a long shipped chapter ID and Classic mode. Autosave derives from the earned Week-4 campaign but deliberately sets `flags=[]`, shipped `closing_rite_thornrook` and week 6 solely to exercise a complete occupied-invalid summary. No fixture value is claimed as canonical progression. Read-only browse/reject/retry/resize preserves full Campaign/RNG seed/state, roster/active/skip/staged resume/prep/room/spawn and all files: [before](recovery-files-before.json), [after read-only interval](recovery-files-after-readonly.json). Subsequent intentional removal of Autosave, Slot 1 and Slot 0 is separate: [after declared removals](recovery-files-after-deliberate-removals.json); remaining Slot 2 bytes are unchanged. No installation saves/settings were used or altered.

A failed initial screenshot authentication attempt produced no image. A startup wait race, an auxiliary unit-ID observer accessor and the expected Castle `active=false` assertion were corrected in the external QA helper; no game source changed. Curated snapshots omit auxiliary unit screen-coordinate fields; complete payload/state/layout comparisons remain. Captures ending `1280` in the resize sequences show the restored default state (earlier same-name captures were overwritten); no before/after image identity is inferred.

All graphical game/input/capture jobs ended normally. [Explicit desktop release](https://github.com/KumarG23/vael-academy/issues/122#issuecomment-6387727595); next controllers require lead naming. No broad school/opening replay, injected result, Neal taste/canon approval or future arbitrary-font guarantee is claimed. Empty-menu Cancel, full alias/edge matrices, callback consumption and broader failure/resolver boundaries retain automated coverage.

Source-head [Verify 40110741306](https://github.com/KumarG23/vael-academy/actions/runs/40110741306) **SUCCESS** on `1bb92da9baa6a78ea84ccafc751beeb68eb27476` was independently checked: helpers, clean import and game tests passed. Native QA and this artifact/status commit change no production or test bytes. Final documentation/integration-head Verify and engineering-lead review remain required; no self-merge.
