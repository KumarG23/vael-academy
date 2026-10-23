# Held battle fast-forward — GH-75 / WO-9.5

Basis: MASTER_PLAN §§1–3 (deterministic combat, logic/presentation split, authoritative formulas), §6 **WO-9.5** (animation skip + fast-forward), §10 **WO-4.9 / partial M9**; HANDOFF **CP-8 production integration / accepted #65 clock boundary**; ACADEMY_BIBLE **§4 ordinary tactical combat**. Parent [#74](https://github.com/KumarG23/vael-academy/issues/74); delivery [PR #77](https://github.com/KumarG23/vael-academy/pull/77). No canon contradiction found.

A fresh held Space runs only the current armed attack/heal presentation at 2×. Release restores its active waits and motion; focus loss, teardown, skip and disarm restore the rate. A new exchange requires another fresh press. Space edges/echoes are consumed while armed; idle Space retains its existing confirm binding. Escape retains accepted skip. The themed hint shows the instruction and explicit active state; compact viewports stack the two controls to clear the illustrated face and existing UI.

`ExchangeSkip` rescales the remaining time of its existing native timers, tracked tweens and registered sprite animations. Concurrent reactions/FX/numbers/splash/shake, camera transitions and existing hit-stop waits share that local clock. Accelerated exchanges settle remaining feedback at their end. Normal playback retains native waits/signals and feedback lifetime. Fast-forward does not set `Engine.time_scale`, change audio pitch or resolve combat again. The existing hit-stop still briefly freezes as before. Native HP/contact order, death/yield, durability, XP/level-up, objective/dialogue, Campaign and save continuation remain shared; dialogue, progression and results stay outside the clock.

## Automated verification

- Regression-first on accepted base `55c59f54`: initial two production tests fail (163/169 assertions). Space does not shorten any route; state equivalence holds. Original implementation: 11/11 speed tests, 621 assertions; existing skip 11/11 green.
- Graphical QA found the wide hint covered Serra's face at 640×360. A projected-head geometry regression fails on the original hint (18/20 assertions), then passes after the compact repair. The final guard also checks popup-nameplate and map-forecast clearance. Two readable lines fit within the existing ornate frame; the default single-line hint remains.
- Accepted #72 main `93cabd07` is normally integrated at `77c41f6a`; status insertion conflicts retain both issues. New production-input checks cover stationary post-attack header/hover on all three routes and a real normal/accelerated Heal command returning through `_finish_action()`. They preserve action state, HP, RNG and the entire saved payload.
- Final affected group on `5bc0f825`: **30/30 tests, 1,688 assertions / 3 scripts**, exit 0 (178.611 s): speed **12/12**, unchanged skip **11/11**, accepted hover **7/7**. This group held the common Git-directory heavy lock with disposable data.
- Initial implementation clean import exit 0/no script-load errors; local full GUT **905/905, 15,963 assertions / 112 scripts** (420.254 s), helpers **102 pass/two opt-in skips**. Serialized common lock/disposable data; 27 inherited deprecations and existing exit-time ObjectDB/resource diagnostics.
- Accepted #68 main `353b8621` integration: Journal/input/map/save **77/77, 1,801 assertions / 8 scripts**; audio separately **15/15, 204 assertions** in a fresh process. Existing assertions are retained. Integrated-source Verify passed on `29ef2f78` and `c9536fd9`: clean import, helpers, **909/909 GUT / 15,988 assertions / 112 scripts**. Final exact-head CI is recorded in the PR comment to avoid a status-only commit loop.

Coverage includes native normal/held state and contact-order equivalence; early/mid release and release inside a real map hit-stop/popup animation; focus/disarm/teardown; echoes across exchanges; acceleration → Escape; enemy initiation/crit; map lethal yield; illustrated lethal yield/level-up/boss quote/yield/outro/victory; actual map and declared popup heal; fresh save/load; unrelated scene timer; keyboard/pointer continuation; default/compact hint bounds and no later presentation mutation. Tolerant wall-clock bounds accompany state assertions and a motion-retention lower bound. Headless popup readback errors are explicitly asserted, as in #65.

Headless fixture deltas: adjacent Kai/Serra or Kael/Osric on real Mock Battle; native seeds selected when a crit/lethal/counter is required. Popup heal duplicates only Wren's UnitDef and changes its art ID to `tm_mage` (kit exists, map rig absent), retaining staff/stats to exercise the executor fallback. Final-rival fixture leaves Serra at 1 HP and Kai at 95 XP; dialogue advancement is fixture plumbing. These fixtures change no production resource.

## Real-input graphical acceptance — 2026-10-23

Original **Godot 4.7.2 Vulkan 1.4.318 Forward+ / llvmpipe (LLVM 20.1.2)**, fresh disposable profile per run, native X11 keyboard/pointer input. No action/result/combat/save handler is called by the driver or reporter. The reporter reads actual state, contacts and payloads. Window flags and viewport size are the only renderer-adjacent changes; no renderer/project setting changed.

The [#72 release](https://github.com/KumarG23/vael-academy/issues/72#issuecomment-6367992108) and [lead's named handoff](https://github.com/KumarG23/vael-academy/issues/75#issuecomment-6368003048) preceded every #75 graphical game/input/capture. Pre-check found no leftover jobs. [#75 explicitly ended all jobs and released to #76](https://github.com/KumarG23/vael-academy/issues/75#issuecomment-6368506108) after the final pass. Each game exited through native Alt+F4; the post-check found no graphical Godot, input driver or capture process.

### Exact sources and fixtures

| Pass | Tested source | Only fixture deltas |
|---|---|---|
| Nine default normal/hold/release runs | `c9536fd9520ac4f20fc7ebf0a322899daf13ed05` | 1280×720 fullscreen window flag; routes below. |
| Default hint recheck | `19ae15139ccca94d51b5a106e3dd0201255337f3` (full hash in manifest) | Same illustrated fixture; native held attack/Wait/pointer sequence. Default hint geometry stays unchanged by the later compact-only height adjustment. |
| Three corrected compact passes | `548fdd15bb56b0965cbfd431bc7a840ffdc08079` | Same map/illustrated/popup fixtures, 640×360 game client (`QA_COMPACT=1`). Native pointer follows live camera projection; capture uses the absolute client origin from `xwininfo`, excluding desktop/decorations. |
| Accepted #72 integration | `5bc0f8255f6b59204a23cc97b7a3461fb97ae61f` | Same byte-identical native map checkpoint and held attack/actual heal/continuation. No save edit. |

- **Map:** byte-for-byte [#39 native Emberwing round-3 checkpoint](../issue-39-three-house-contests/saves/emberwing-opening.json), SHA-256 `c156c62b43e6d6f48002d50f787751e708ec03cdef3378ceadddcd806e99a4d3`, copied to disposable slot 0. Ordinary Title → Load Game → Slot 0. Kael moves and attacks Marlow; then Wren moves and actually heals Perrin **10 → 24**. Pointer selects/cancels Liora, then normal PageDown continuation.
- **Illustrated:** real Mock Battle, seed 1; suppress opening intro during construction, re-enable ordinary boss quote; Kai `(8,12)`, Serra `(9,12)`. Everything else remains native. Attack → counter → follow-up; then Kael moves and Waits and pointer selects/cancels Liora.
- **Pixel popup:** declared fixture because no production scene opts in. Real Mock Battle, `battle_popups_enabled=true`, seed 1, dialogue off, Kael `(8,10)` / Osric `(9,10)`. Attack, then ordinary Kai Wait; compact pass also selects/cancels Liora by pointer.

Entry modes and these exact deltas are in [qa_runner.gd](tools/qa_runner.gd). [qa_reporter.gd](tools/qa_reporter.gd) only observes. [drive.py](tools/drive.py) sends native X11 input and supports explicit client origin/size for windowed captures. [compare.py](tools/compare.py) asserts outcome equality, rate restoration, motion-retention bounds and duration reduction. Busy-state snapshots also include ordinary movement/Wait continuation; none are discarded to make the comparison pass.

### Actual comparisons

Wall-clock armed presentation durations in milliseconds; the initial interval before the fresh press remains at 1×.

| Route | Normal | Held | Held then released |
|---|---:|---:|---:|
| Native map attack | 1,726 | 927 | 1,385 |
| Actual map heal | 1,577 | 827 | 1,237 |
| Illustrated CP-8 | 4,391 | 2,464 | 4,028 |
| Declared pixel popup | 7,852 | 4,068 | 7,550 |

Every default run's **entire** settled battle/roster/support snapshots match its normal reference, including ordinary continuation. Native illustrated contacts match exactly in order: Serra **20**, Kai **15**, Serra **14**. Observed native map HP changes, yields/removal, healed HP, uses/XP/acted flags and final RNG match. The popup retains its accepted HP-commit boundary after cut-in; its actual final state and visible HP-bar/animation playback agree with the unchanged native result.

[results.json](results.json) records rate edges, exact durations, actual final RNG, ordered contacts/observed HP changes and canonical SHA-256 fingerprints of all settled payloads. The three compact runs also match their default held references' entire settled snapshots. The default hint recheck and accepted-#72 native map integration match their original held/normal references respectively.

After each release/end the native rate returns to 1; presentation/camera flags clear, `Engine.time_scale` is 1, and map UI/control returns. [Released illustrated hint mid-exchange](images/illustrated-default-released.png); [released actual heal](images/heal-default-released.png). The final accepted-#72 integration also clears [Marlow's stationary readouts](images/integrated-attack-after.png), shows [Perrin 24/24 in both stationary readouts](images/integrated-heal-after.png), and preserves [pointer continuation](images/integrated-pointer.png). Earlier comparisons captured #72's existing stale text; actual state was already identical. Final source includes the accepted repair.

### Inspected motion and hint evidence

Each native recording is **4 seconds, 1280×720, 30 fps**, retained without frame/timing edits: [map motion](motion-map.mp4), [illustrated motion](motion-illustrated.mp4), [popup motion](motion-popup.mp4). Inspected frames at 0.20/0.65/1.20 s (map/popup) and 0.25/0.65/1.25 s (illustrated) show lunge/contact/recovery or attack/counter/follow-up movement, rather than an immediate skip. Illustrated contact/follow-up stills: [first](images/motion-illustrated-contact.png), [follow-up](images/motion-illustrated-follow-up.png).

Default hint: [instruction](images/map-default-instruction.png), [active map](images/map-default-active.png), [actual heal](images/heal-default-active.png), [illustrated](images/illustrated-default-active.png), [popup](images/popup-default-active.png). Corrected compact hints: [heal / forecast clearance](images/heal-compact-active.png), [illustrated face / HP clearance](images/illustrated-compact-active.png), [popup name / HP clearance](images/popup-compact-active.png); [compact pointer continuation](images/popup-compact-pointer.png). [manifest.json](manifest.json) binds each artifact to its tested source and hash.

Limits: popup is a declared fixture; no new production opt-in. Compact checks cover the hint and continuation within existing presenter layouts. Level-up/dialogue/results use their normal continuation and are tested outside acceleration. This is bounded functional QA, with no full-school/year replay, new art/canon/active defense or Neal taste/visual approval claim.
