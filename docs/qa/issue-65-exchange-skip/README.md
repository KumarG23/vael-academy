# Battle exchange skip — GH-65 / WO-9.5

Scope: MASTER_PLAN §6 WO-9.5 (animation skip) and §10 row 4.9 ("skip input"), §§1–3; HANDOFF CP-8 production integration and battle cut-in gates; ACADEMY_BIBLE §4 ordinary school combat. No canon contradiction was found. Combat formulas, RNG, saves, bindings, art and animation style are unchanged.

A fresh Esc/Backspace (`cursor_cancel`) press while an attack or heal exchange is playing skips the rest of that exchange. The executor resolves once, then arms a per-exchange skip clock. Presenters await timers, tweens and animation signals through that clock, so after a skip the same code still applies each native contact, death/yield and teardown in order, and only the elapsed time is removed. The shared durability/XP/level-up/objective tail then runs unchanged. A UITheme "Esc  Skip" hint shows at the top right while armed. Echoes and releases are swallowed and never skip; outside an exchange the layer is inert.

## Automated evidence

`tests/test_battle_exchange_skip.gd` drives production Mock Battle views in 1280×720 SubViewports with real viewport key/mouse input. Each skip is compared with a same-seed normal playback in a fresh view. It covers:
- illustrated early / inside the first contact callback / settle;
- enemy-initiated crit;
- lethal yield with level-up, boss quote/yield/outro and victory, where a held echo leaves results up;
- map early / mid / during hit-stop / late, and lethal yield with a counter;
- pixel popup establish / contact / late;
- map heal and popup heal;
- held Esc echo across the next (enemy) exchange;
- keyboard and pointer continuation;
- save → fresh load;
- hint bounds/layer/no-overlap.

On untouched main `5663ec2c` the file fails 8/11 (886/922 assertions); with the change it passes 11/11 (934 assertions). Full checks are recorded in the PR.

## Real-window acceptance — 2026-10-23

Tested source **`6b118e31a13d0e9c8088a1f5f3636c59dfdaf8c7`** (#63 main `e296c03f` integrated), original Godot 4.7.2 **Vulkan 1.4.318 Forward+**, llvmpipe, existing 1280×720 shared desktop. The game was started with Godot's `--fullscreen` window flag; renderer and project settings were unchanged. Every run used a fresh disposable `XDG_DATA_HOME`.

The desktop was released to #65 by #63 ([6364596137](https://github.com/KumarG23/vael-academy/issues/65#issuecomment-6364596137)). A process check found no graphical Godot, input or capture job before #65 started. All gameplay used native X11 keyboard/pointer input. [`tools/qa_reporter.gd`](tools/qa_reporter.gd) only reads state; it never calls an action, input, combat or save handler. [`tools/qa_runner.gd`](tools/qa_runner.gd) holds the entry modes. Structured timelines and comparisons: [results.json](results.json); hashes: [manifest.json](manifest.json).

Each route was played twice with **identical inputs**, once with Esc and once without. The settled battle state (including the combat RNG state), roster (HP, cells, acted, XP, level, weapon uses), supports and every native illustrated contact are **identical** between the two runs.

| Route / provenance | Normal presentation | Skipped | Esc → map control |
|---|---|---|---|
| **Map strike**, native #39 round-3 checkpoint, byte-identical (SHA-256 `c156c62b…`), Title → Load → Slot 0. Kael attacks Marlow: hit, Marlow yields. | 1,740 ms | 718 ms | same frame |
| **Real map heal**, same checkpoint. Wren heals Perrin 10 → 24. | 1,560 ms | 715 ms | same frame |
| **Illustrated**, CP-8's documented rehearsal placement (real Mock Battle, seed 1, Kai/Serra adjacent; boss quote real). Kai hit → Serra counter → Kai double. | 4,374 ms | 961 ms | 1 ms |
| **Pixel popup**, *declared fixture* (`battle_popups_enabled=true`; no production scene opts in), Kael/Osric adjacent. | 7,910 ms | 882 ms | same frame |

- **Map:** the strike's native contact and hit-stop (`time_scale` 0) completed before the press. Esc then returned to idle map control in that frame: Marlow yielded and was removed, Kael acted with XP 30, `time_scale` 1 and map UI visible. [Hint during the strike](images/map-skip-02-attack-armed.png), [after](images/map-skip-02-attack-after.png).
- **Next ordinary command → real heal:** Wren's heal (HP applied before presentation, as before) was skipped as well. [Hint](images/map-skip-04-heal-armed.png), [after](images/map-skip-04-heal-after.png). Pointer continuation then selected Liora with her normal ranges, and Esc cancelled normally. [Pointer selection](images/map-skip-05-pointer-select.png).
- **Illustrated:** Esc at the first `contact` beat (Serra 26 → 20). In that frame the queued counter (Kai 26 → 15) and follow-up (Serra 20 → 14) applied in native order, and the stage closed. Then: map with real HP; next command, Kael moves and Waits; pointer select/cancel. [Stage with hint](images/ill-skip-02-stage-hint.png), [after](images/ill-skip-03-after.png), [next command](images/ill-skip-04-next-command.png).
- **Popup:** [popup with hint](images/pop-skip-02-popup-hint.png), [after](images/pop-skip-03-after.png).
- Clips (skip passes, native input): [map attack + heal + continuation](map-skip.mp4), [illustrated](ill-skip.mp4), [popup fixture](pop-skip.mp4).

No script or runtime error occurred in any run. Every game exited normally with Alt+F4, and the recording and input jobs ended.

### Defects found and fixed during this QA

1. At the original ~40 px height the noble 9-slice frame collapsed into a band through the hint text ([zoom](images/defect-hint-frame-band-zoom.png)); fixed in `afa7444d`.
2. The bottom-right hint covered Serra's illustrated HP numbers ([before](images/defect-hint-over-hp-plate.png)); moved top-right at y=72, clear of every presenter's chrome, in `6b118e31`. The headless hint test now asserts it.

### Pre-existing defect filed

[#72](https://github.com/KumarG23/vael-academy/issues/72): the cursor hover box and header keep the pre-action HP after a heal or attack until the cursor moves. It's identical in normal playback ([normal heal](images/map-normal-04-heal-after.png)), so it isn't caused by the skip.

Limits: popup coverage uses the declared fixture above. Level-up and result screens are not exchange presentation and are not skipped. This was not a full school/year replay. This is functional acceptance, not Neal's visual or taste approval.
