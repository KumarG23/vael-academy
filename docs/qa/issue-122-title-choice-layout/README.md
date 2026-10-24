# GH-122 — complete Title recovery summaries and shared ChoiceMenu layout

Parent: [#121](https://github.com/KumarG23/vael-academy/issues/121). Basis: MASTER_PLAN §§1–3, §6 WO-4.3 (Title/campaign flow), WO-4.4 (presentation repair), WO-9.4 (shared menus), WO-9.6 (save picker/recovery), partial §10 M9; ACADEMY_BIBLE §§3–4 (existing school/mission continuation). No canon change or contradiction found.

## Acceptance discrepancy

The issue asks to preserve one-based slot numbers. Accepted main Title actually displays the physical indices **0–2**; Journal uses one-based labels. Accepted PR #88 explicitly preserves this distinction, and the existing Title tests assert it. This repair preserves Title's existing text/physical mapping. [Reported before implementation](https://github.com/KumarG23/vael-academy/issues/122#issuecomment-6386330902); no renumbering or save-policy decision is inferred.

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

## Native boundary — pending, no authority used

No graphical game, input or capture job was launched. The assigned gate is explicit release **and lead naming**, after #114 → #117 → #118. This PR remains draft. No native capture/checkpoint hash, ordinary earned-checkpoint load, real desktop continuation or Neal visual approval is claimed.

When explicitly named, the remaining bounded original-Forward+ check must inspect complete Title/New Game/manual and Autosave summaries/retry at default/compact/live resize, real keys/pointer dispatch, an unchanged ordinary earned-checkpoint load and normal continuation. Supplementary long occupied/battle/invalid fixtures must be labeled separately. Record source/checkpoint/capture hashes, observed versus automated coverage, complete state/file comparisons and deliberate writes, then end/release every GUI job. No full-school replay is required or claimed.
