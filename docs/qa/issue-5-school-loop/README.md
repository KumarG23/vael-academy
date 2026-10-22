# Issue #5 — graphical school-loop qualification

Functional QA of existing delivered behavior; not story, art, pacing or Neal visual approval.

## Basis and environment

- [Issue #5](https://github.com/KumarG23/vael-academy/issues/5), within reliability milestone [#8](https://github.com/KumarG23/vael-academy/issues/8).
- MASTER_PLAN §1 school-slice checkpoint; §3 lord-loss rule; §6/§10 WO-4.3/4.4, 5.3, 5.6, 6.2a and 6.4. ACADEMY_BIBLE §§3–4 (campus activities, Common Hall, inter-house rites); CAMPAIGN_STRUCTURE **What house choice actually forks**. HANDOFF migration qualification, issue #3 support receipt repair, and AW-30 known limits.
- Route baseline: `f975683c63fef668b35fff841b92407db7d52cdf`, current main when QA began, 2026-10-22.
- Godot `4.7.2.stable.official.ed1daf0bf`; unchanged Forward Plus renderer, Vulkan llvmpipe, 1280×720 graphical window.
- Used the existing shared desktop, real X11 keyboard/pointer events and inspected screenshots. The prescribed display rejected authentication; another existing desktop was available. No service was started and renderer configuration was preserved.
- All game/test processes used disposable `XDG_DATA_HOME`; real saves and old branches were untouched. Native saves were copied only within disposable QA data.
- Tactics were assisted by read-only inspection of live units/reachability/forecasts. Actions were sent through keyboard menus and watched through normal animations. No victory, HP, RNG, dialogue completion, roster or campaign progress was injected in the route runs. Reading was accelerated; this does not assess emotional pacing.

## Route provenance and results

| Route | Starting point | Activity / persistence | Opening rite and return |
| --- | --- | --- | --- |
| Emberwing | Fresh New Game, Casual; seven opening scripts; road introduction, round-3 victory and completed aftermath; existing pitch/oath; Week 1 campus | Fishing: Warded Coin ×1. Native Save Game → Title → Load preserved house, Week 1 and catch. Initial Common Hall correctly had no unlocked bonds. | Three factions; victory round 6, Perrin sole survivor; returned to Week 2 **Term begins**. Kai had fallen in round 2, so this is reachable flow with a rules failure, not a clean pass (#19). |
| Tidemark | Native round-3 road save reused from the fresh run; boss fight/aftermath replayed, then existing choice/pitch and Week 1 campus. **Not a fresh New Game run.** | Training: Serra 18 → 28 XP, training-used recorded. | Rina defeated, victory round 12 with Kai alive; returned to Week 2 **Term begins**. Fenn fell; six player units survived. |
| Thornrook | Same earned round-3 road checkpoint; boss/aftermath replayed, existing choice/pitch and Week 1 campus. **Not a fresh New Game run.** | Rina trained 27 → 37 XP; native Save → Title → Load preserved Thornrook / Week 1. | Perrin defeated, victory round 5 with Kai alive; returned to Week 2 **Term begins**. Rurik fell; seven player units survived. Original arrival-frame capture missing; native post-return save records Week 2 (see provenance below). |

The reused road save contained Kai at (7,6), 26 HP and unacted; Serra at (9,5), 12 HP and unacted; Rina at (8,5), 20 HP and acted; only the bandit boss remained at (13,5), 27 HP. Native Title → Load restored round 3 and these states. It is an input-earned checkpoint, not a seeded fixture.

### Return-evidence provenance (review correction)

The original Emberwing and Tidemark campus captures are byte-identical (SHA-256 `349a1c38716ff62265de543eb0bcfa299e03017078017e4ec90de13f1b3e0732`). They were separately captured at the shared initial campus view after their respective result dismissals. They show **Week 2 — Term begins**, but contain no route identity and cannot independently prove which house returned. Route identity comes from the preserved native post-return saves, not those images.

The file originally labeled Thornrook “Week 2 return” was captured too early and actually shows the battle **Victory** overlay. It is now [labeled as that result](images/thornrook-victory.png). **The original Thornrook arrival-frame capture is missing.** The following native save was written after the transition and records Thornrook, Week 2 and victory; contemporaneous read-only inspection also reported the castle scene. The earlier result screenshot itself does not establish castle return.

For additional reviewable proof, byte-for-byte copies of each original native post-return save were loaded through Title in separate disposable data directories on accepted game source `366a8e5f358fb57cc64a3b37a986f3a217be8313`. No house/week/result was edited or seeded. The Journal was opened with real J input after loading. These are **later native-save reload captures**, not replacement frames from the original playthroughs.

| Original route save | Later reload: house-identifying Journal + Week 2 header |
| --- | --- |
| [Emberwing native return](emberwing-return-save.json) | [Emberwing reload](images/emberwing-native-return-journal.png) |
| [Tidemark native return](tidemark-return-save.json) | [Tidemark reload](images/tidemark-native-return-journal.png) |
| [Thornrook native return](thornrook-return-save.json) | [Thornrook reload](images/thornrook-native-return-journal.png) |

[Curated provenance checks](return-reload-provenance.json) record hashes, loaded house/week/result and tested source. Reproduce by copying one native return file unchanged to `godot/app_userdata/Vael Academy/saves/slot_0.json` beneath a new disposable `XDG_DATA_HOME`, launch, Title → Load, then J. This differs from the explicitly seeded support fixtures below.

## Actual roster and rival selection

| Player route | Player team | Opposing teams |
| --- | --- | --- |
| Emberwing | Kai, Perrin, Kael, Brenna, Wren, Dain, Liora (7) | Team 1: Osric, Elowen, Isolde, Fenn, Bertram, Serra (6). Team 2: Rina, Thessaly, Corvin, Marlow, Vesper, Rurik, Nilu (7). |
| Tidemark | Serra, Osric, Elowen, Isolde, Fenn, Bertram, Kai (7) | Team 1 only: Marlow, Rurik, Thessaly, Corvin, Vesper, Rina (6); objective **Defeat Rina — or rout them all**. |
| Thornrook | Rina, Thessaly, Corvin, Marlow, Vesper, Rurik, Nilu, Kai (8) | Team 1 only: Kael, Dain, Liora, Brenna, Wren, Perrin (6); objective **Defeat Perrin — or rout them all**. |

**Document discrepancy:** MASTER_PLAN §4 / WO-5.6 and CAMPAIGN_STRUCTURE describe the two unpicked houses as rivals. The §10 WO-5.6 completion row instead records a single-rival cycle; HANDOFF AW-30 explicitly limits the three-house free-for-all to Emberwing and leaves house-aware parity as follow-on work. Both alternate routes match that known limitation. Neal subsequently resolved the acceptance in [#22](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340423944): three mutually competing houses on every route, friendly/nonlethal competition with normal defeat, at each semester’s beginning and end. The approved name is [Clash of Three Banners](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340542559). Delivery is tracked in #28/#29; precise calendar/story mapping remains #30. This later decision does not change the historical observed asymmetry or establish implemented parity. This report does not invent a canon exception or claim all routes are three-way. Nilu is the separately documented Thornrook companion, not an additional noble student.

## Reproduction through existing UI

1. Launch the project with a new disposable data directory. New Game → Casual. Advance the current authored opening with Return, then play the road battle through normal move/action/target menus. Finish the aftermath before dismissing victory.
2. Use Left/Right to select a house, R to inspect its roster preview, and the oath button to commit. Complete the pitch. Verify the Week 1 campus header and selected house roster.
3. Emberwing: walk to Waterside, interact at the fishing spot, then press Space when the bite appears. Escape → Save Game; Escape → Return to Title; Load the occupied campaign slot. Check house/week/catch.
4. Training alternative: enter Training Grounds, interact with **Train a housemate**, select the first roster member, and check +10 XP / one-use state.
5. Deploy from the War Room mission table (Emberwing tested through the building) or campus Mission Board. Check Preparations, actual teams and objective; Begin battle. Play to result, dismiss it and inspect the castle calendar.
6. For alternate routes, use the isolated native road checkpoint above, finish its remaining fight/aftermath, and choose the next house. Do not call these full fresh playthroughs.

## Functional defects found

| Issue | Observed behavior | Qualification impact |
| --- | --- | --- |
| [#14](https://github.com/KumarG23/vael-academy/issues/14) | Sparse save rows display metadata for the wrong fixed slot; an apparently empty row overwrites the occupied slot. Title also uses zero-based labels. | Baseline save safety failure; repaired row/write mapping graphically verified on `19cad888` below. Title numbering remains unchanged. |
| [#15](https://github.com/KumarG23/vael-academy/issues/15) | Fishing, training and empty-archive feedback is clipped off the right edge. | Baseline feedback unreadable; repaired toast bounds/default and 800×450 real-input feedback verified on `eecc29f3`. Separate composed-HUD limits #40/#42 remain below. |
| [#16](https://github.com/KumarG23/vael-academy/issues/16) | Journal close key reaches the castle: Escape opens the system menu; J reopens the Journal. | Baseline input failure; fixed behavior verified on accepted `9afc166a` below. |
| [#19](https://github.com/KumarG23/vael-academy/issues/19) | Animated defeat frees Kai before objective checks; Emberwing continues and awards victory/Week 2 after lord loss. | Baseline rules failure under MASTER_PLAN §3; fixed behavior verified on accepted `366a8e5f` below. |
| [#20](https://github.com/KumarG23/vael-academy/issues/20) | Road bandit at (8,7) occupies a water tile labeled impassable and remains attackable. | Baseline terrain/spawn defect; accepted repair and road victory verified on `19cad888` below. |
| [#23](https://github.com/KumarG23/vael-academy/issues/23) | Thornrook’s Nilu has no chapter deployment entry and defaults to isolated (0,0). | Fresh opening/closing deployments and real move/Wait verified on `eecc29f3`; provenance below. |

These issues were checked against all open/closed issues and PRs before filing and left for lead assignment. QA did not implement repairs or change canon.

## Support archive — isolated fixture

Retest baseline: accepted main `ca584fe27be2dacdf83e63c8d50aa25b3bcdf465` (includes PR #17 pointer and PR #18 mute repairs). This was a new graphical process with a separate disposable data directory.

The natural Emberwing return had Kai–Kael 10 points, no rank and no viewed scenes. For archive coverage only, copy that native return save and set `campaign.support_save.points.kai_kael = 20`, `ranks.kai_kael = "C"`, leaving `viewed = {}`. This is **seeded support eligibility**, not an earned C-rank playthrough. Load it through Title, walk to Great Hall → Common Hall, and interact at **Gather by the fire (bonds)**.

| Case | Real UI result | Viewed receipt / availability |
| --- | --- | --- |
| Initial C fixture | **Kai + Kael C**, no checkmark | Unviewed and available |
| Missing path | Rejects playback, keeps archive menu | Still unviewed and available |
| Malformed JSON (`{`) | Rejects playback, keeps archive menu | Still unviewed and available |
| Empty JSON (`[]`) | Rejects playback, keeps archive menu | Still unviewed and available |
| Authored `kai_kael_c.json` | Actual portrait/dialogue playback; Return advances all lines | Unviewed during playback; checkmark only after completion |
| Replay | Same authored conversation plays again | Exactly one viewed key, `kai_kael:C`; archive entry remains available |
| Native Save → Title → Load → Common Hall | Checkmark still shown | Viewed key persists; entry remains replayable |

For invalid-asset cases only, duplicate the live Kai–Kael `SupportChainDef` in the disposable process, replace its C path with a missing or malformed/empty `user://` fixture, then close/reopen the archive and select it with real Return input. Restore the authored path before the valid case. No repository dialogue/resource was edited, and no support handler or completion callback was called directly. The clipped error toast remains #15. These checks confirm the issue #3 receipt repair in the Common Hall; battle-menu coverage follows.

### Battle support fixture

Separately copy the native Emberwing prebattle save, set Kai–Kael to 20/C in **both** its top-level `supports` and `campaign.support_save`, and clear viewed receipts. Load normally (begin only if Preparations appears), select Kai without moving, then choose Supports. The same missing/malformed/empty paths returned to the action menu with Supports still available and no viewed receipt. Valid authored playback stayed unviewed until completion, then removed Supports from this unit's unwatched menu. Kai remained at (2,12), unacted. A native battle save, process restart, Title → Load and reselecting Kai preserved `kai_kael:C` and the absence of Supports. No battle action, HP or RNG was altered by the fixture.

## Accepted repair retests

Both checks below ran on accepted main `ca584fe27be2dacdf83e63c8d50aa25b3bcdf465`. They are focused fixtures, not additional fresh campaign playthroughs.

### Pointer repair — PR #17 / issue #9

Using the native Emberwing prebattle continuation above and real pointer input:

- Hover Kael at (3,12), move the keyboard cursor left to Kai without moving the pointer, then left-click: **Kael selected**, movement range visible.
- Right-click cancels selection and leaves Kael unacted.
- Pan using keyboard movement to (11,9), then point/click Kael at his transformed visible position: **Kael selected**.
- Repeat at a 960×540 window and camera zoom 1.75: **Kael selected** and cancellation spends no action.
- Fit the map at zoom 0.3, select Kael, then click the visible outside-map margin: selection and cursor remain unchanged. Valid right-click still cancels.

The two explicit zoom values and window resize were presentation-only runtime fixture settings; no renderer/project configuration or gameplay state was changed. Original-size keyboard movement and native camera following were also exercised. This extends PR #17's headless input dispatch proof with actual desktop events.

### Audio repair — PR #18 / issue #10

Captured the graphical game's actual PulseAudio output monitor as signed 16-bit PCM. This is real audio-driver output, not the dummy driver or only `AudioStreamPlayer.playing` flags. It measures functional silence/resumption on a virtual output device; it is not a speaker/headphone listening or music-taste approval.

Invoke existing AudioManager methods in the disposable graphical process. Play `campus_chill.mp3`; mute; request `rooms/library.mp3` while muted; unmute. Separately stop music, play `vo/prologue/p1_opener.wav`, then mute while its voice player is still active. Repeat with `victory.wav` SFX at pitch 0.25 so the short one-shot is still active when muted. That pitch is only a test fixture setting. After mute, wait 0.3 s to drain output buffering and capture one second. Unmute must not replay old voice/SFX; new one-shot requests while muted must stay silent.

| Output sample | Peak PCM amplitude | RMS |
| --- | ---: | ---: |
| music-before | 16042 | 3180.81 |
| music-muted | 0 | 0.0 |
| new-track-while-muted | 0 | 0.0 |
| latest-track-resumed | 21885 | 4743.857 |
| voice-before | 8409 | 1816.464 |
| voice-muted | 0 | 0.0 |
| voice-not-replayed | 0 | 0.0 |
| sfx-before | 18170 | 12220.177 |
| sfx-muted | 0 | 0.0 |
| new-oneshots-muted | 0 | 0.0 |
| oneshots-not-replayed | 0 | 0.0 |

Active voice and SFX player state was checked immediately before mute; both were still playing. All seven silent intervals had peak **0**. Music resumed with the latest requested library track; narration and SFX did not replay. See [sample measurements](audio/measurements.json) and the linked PCM clips below. Capture command: `ffmpeg -f pulse -i auto_null.monitor -t 1 capture.wav` (use your existing output monitor; do not start a service).

### Lord-loss repair — PR #25 / issue #19

Accepted game source: `366a8e5f358fb57cc64a3b37a986f3a217be8313`. Loaded a byte-for-byte copy of the original [native Emberwing prebattle save](emberwing-rite-start.json) through Title in a new disposable data directory. Repeated the **first 12 actions** of the [original transcript](emberwing-actions.md), through Dain’s round-2 attack, using real keyboard menus and unchanged production animations. No unit HP, position, RNG, progression or outcome was seeded or injected.

Kai fell during the ensuing enemy phase. The game now displayed **Defeat in round 2**, with Perrin (24 HP), Brenna (20 HP) and Dain (28 HP) still alive. Units and turn state stayed unchanged during a two-second result hold; no later rival action or rout victory occurred. Dismissing Defeat returned to Title with campaign week still **1**, not the castle or Week 2. This is a checkpoint regression retest, not a new fresh playthrough. The earlier erroneous baseline victory evidence is preserved.

Evidence: [18-second tail of the actual replay](lord-loss-retest.mp4), [Defeat result](images/lord-retest-defeat.png), [Title after dismissal](images/lord-retest-title.png). Native battle reload resumes directly; choose Begin battle only if Preparations is actually shown.

### Campaign-load rejection — PR #27 / issue #11

Accepted game source: `883ff334e26ee3429c84b26657e0237065242d76`. New disposable data and real keyboard input through Title and Journal; no load callback was invoked directly. This is a **malformed-save fixture check**, not a fresh playthrough.

Reproduction:

1. Copy the unchanged native Emberwing return save to `slot_0.json`. Copy the native Tidemark return into two other disposable slots, set their saved week to **6**, then set `campaign.flags = []` in `slot_1.json` and `campaign.report_cards = {}` in `slot_2.json`. These intentionally corrupted fixtures differ from the live campaign.
2. Title → Load Game → select each malformed slot with Return. Both selections leave the same Title scene and Load menu open. Read-only before/after comparison confirms the entire live campaign, roster house, active/training-load flags and pending battle/castle staging remain unchanged. Neither file is rewritten. [Flags rejection](images/save-title-reject-flags.png), [report-cards rejection](images/save-title-reject-report_cards.png).
3. Select the valid native Emberwing slot: castle and Journal show [Emberwing / Week 2](images/save-valid-emberwing.png). Open Journal → System and select **Load — Slot 2**, then **Load — Slot 3**. Both malformed loads keep the same scene and Journal instance open; campaign/staging and slot bytes remain unchanged. The header stays Week 2, not the fixture’s Week 6. [Flags rejection](images/save-journal-reject-flags.png), [report-cards rejection](images/save-journal-reject-report_cards.png).
4. Replace only disposable slot 0 with the byte-for-byte [original native Thornrook campus save](thornrook-campus-save.json); select Journal **Load — Slot 1**. The castle reloads successfully, the old book closes, and J shows [Thornrook / Week 1](images/save-valid-thornrook-training.png). Read-only state confirms `training_used = true` and Rina XP **37**, preserving the actual earlier training visit. The native slot remains byte-identical (SHA-256 `ea3b33faabc50df45a55b0cb234ad666bb9fd47ae96fe542fb676e1b5202f833`).

All four rejection checks and both valid transitions passed. [Curated results](save-validation-results.json) accompany the inspected captures. UI slot numbering still differs between Title and Journal (#14); this retest does not claim that separate defect fixed. Rejection is observed as remaining in the current flow; no new error-message UX is claimed.

### Journal repair — issue #16

Accepted game source: `9afc166af8769ce18bd059ea1e988122ed865ab4` (PR #26). Loaded an unchanged copy of the original native Thornrook Week-2 return save through Title in fresh disposable data. All inputs below were actual desktop keyboard events; inspection only read UI/campaign state. No seeded campaign or directly invoked input/close handler. The native slot stayed byte-identical.

| Real input sequence | Observed result |
| --- | --- |
| J opens Roster, then one Escape | Book closes once; zero Journal nodes, no castle menu; [exploration visible](images/journal-fixed-escape.png). |
| J opens Roster, then J | Book closes with zero Journal nodes and no replacement/menu. |
| J → Right twice → Return twice | Inventory reaches [give-recipient selection](images/journal-fixed-inventory-give.png); no transfer confirmed. |
| Escape, Escape, Escape | Give → item → [student list](images/journal-fixed-inventory-back.png) → closed. First two steps retain the same book; final step leaves zero books and no castle menu. |
| Hold Right for 0.4 s after closure | Avatar moves from x=3008 to x≈3220.69 at the same y=2112; [exploration responds normally](images/journal-fixed-exploration.png). |
| Reopen Inventory give selection, then J | Closes directly from the nested mode, with zero books/no castle menu. |
| Fresh Escape, then Escape | [Normal castle menu opens](images/journal-fixed-fresh-escape.png), then closes. This is a new keypress after Journal closure, not propagation from its close event. |
| Fresh J, then Escape | [One new Roster book opens](images/journal-fixed-fresh-j.png), then closes to exploration without a system menu. |

All **11 inspected state checks passed**; house remains Thornrook and week remains 2. [Curated results](journal-retest-results.json) retain the input cases, UI counts/modes and movement receipt. This is a focused native-save continuation retest, not another fresh campaign run. The original failing screenshot/issue #16 remains as historical evidence.

### Sparse save rows — PR #31 / issue #14

Accepted main: `19cad888161230bbc6c17b377bde4f496a4f63fc`, including #31 merge `59334ad3`. Godot 4.7.2, unchanged Forward Plus, real keyboard input and disposable data. These are **existing Dev Jump encounters plus an isolated file-occupancy fixture**, not additional campaign playthroughs.

For each path, initialize only disposable `slot_2.json` with a copy of the native Thornrook return save. Enter Title → Dev Jump → Mock Battle for Preparations, then Begin battle for the field; restart through Dev Jump → Arena for the third path. Restore the same isolated Slot-3-only arrangement between paths. Open Save game from the normal preparation/field menu.

| Path | Only Slot 3 occupied | Slots 1 + 3 occupied, Slot 2 empty |
| --- | --- | --- |
| Preparations | [Correct three rows](images/save-rows-prep-only-third.png) | [Correct gap](images/save-rows-prep-gap.png) |
| Field | [Correct three rows](images/save-rows-field-only-third.png) | [Correct gap](images/save-rows-field-gap.png) |
| Arena | [Correct three rows](images/save-rows-arena-only-third.png) | [Correct gap](images/save-rows-arena-gap.png) |

In each path: cancel the sparse picker without writing; reopen and save row 1; reopen with the 1+3 gap and save row 2; reopen full and overwrite row 3. All **nine writes** changed exactly the displayed physical slot (`slot_0/1/2.json` respectively), wrote an actual battle payload and preserved every other occupied slot byte-for-byte. Reopening showed the new occupancy; [arena’s full picker](images/save-rows-arena-full.png) now identifies all three saves as arena. All **three cancellation checks** preserved the files. Preparations cancellation returns first to its [Preparations menu](images/save-rows-prep-cancel.png), then Escape restores the prep map; field/arena cancel directly restore map input. [Curated checks](save-rows-retest-results.json).

The related zero-based **Title Load Game** labels remain unchanged, as explicitly retained by #31’s accepted numbering scope. This pass verifies the repaired battle picker, not a numbering redesign.

### Road spawn passability — PR #32 / issue #20

Accepted main: `19cad888161230bbc6c17b377bde4f496a4f63fc`. Use Title → Dev Jump → Prologue battle, then advance the existing road introduction. This creates a **fresh encounter from current chapter data**, not a full New Game/opening playthrough or restoration of an old battle snapshot. Old snapshots retain their saved positions and cannot prove a new deployment correction.

Actual four allies/five foes spawned. [Perrin at (3,6)](images/road-fixed-perrin-spawn.png) and [bandit_b at (7,7)](images/road-fixed-bandit_b-spawn.png) both visibly show **Plains, move 1** in the HUD. Read-only live movement inspection found 62 standable cells for Perrin and 35 for bandit_b. The accepted correction moves Perrin off the former cottage footprint as well as moving the reported bandit off water; the lead explicitly accepted both local corrections under the all-spawns-passable requirement.

Two distinct encounters were exercised:

1. **Completed encounter:** move Perrin from (3,6) to (4,6) through the normal movement menu and Wait; let Kai, Serra and Rina Wait in place. Continue normal tactical inputs/animations. The battle reached [Victory in round 4](images/road-fixed-result.png), with Kai 14 HP, Serra 19 HP and Rina 20 HP; Perrin had fallen. The authored aftermath completed and dismissing Victory reached the [existing house-choice screen](images/road-fixed-house-choice.png). No outcome, HP, RNG or progression was injected.
2. **Movement capture repeat:** start a separate fresh Dev Jump road encounter and repeat only that first turn. [Perrin moves to (4,6)](images/road-fixed-perrin-moved.png). During the normal enemy phase, bandit_b moves from (7,7) to (4,5), attacks Perrin and is defeated by his counterattacks. [Combat after movement](images/road-fixed-bandit-moved.png), [17-second input/movement/combat video](road-mobility-retest.mp4). Read-only observation sampled the live bandit at (4,5), HP 20 → 8 → 0 before removal. This repeat stops after enemy phase 1; its video is not the full victorious encounter.

[Curated spawn, movement and completed-encounter input/results](road-spawn-retest-results.json) distinguish both runs. Captures and sampled video frames were inspected. The historical water-spawn failure remains above; no terrain, roster, canon or renderer change was made by QA.

## Nilu deployment — PR #34 / issue #23

Tested accepted main `eecc29f3b23bcd3591a9772f87b2cb9f464c32f5`, including #23 merge `8770639b`. Godot/renderer unchanged. These are focused **freshly entered encounters**, not new full campaign runs or restored battle snapshots.

- **Opening, native continuation:** byte-copy [the earned Thornrook Week 1 campus save](thornrook-campus-save.json) to a new disposable data directory. Title → Load → walk to campus Mission Board → Deploy. The routed scene is `mock_battle_vs_emberwing.tscn`; eight players include Nilu at `(4,11)`, between Rurik `(4,10)` and Rina `(4,12)`, facing the existing six Emberwing rivals. [Spawn/HUD](images/nilu-opening-spawn.png).
- **Closing, explicit calendar fixture:** in a separate copy of that same campus save, change **only** `campaign.week` from 1 to 6. Load through Title and deploy through the same Mission Board. The routed scene is `closing_rite_thornrook.tscn`; Nilu again occupies `(4,11)` alongside the same eight-player roster. Existing twelve Emberwing/Tidemark rivals share team 1 on this tested source. [Closing spawn/HUD](images/nilu-closing-spawn.png). This is not earned Week 6 progression or a semester playthrough.
- In **both** scenes, use Escape → Begin battle; select Nilu, move to `(5,11)` and choose Wait. Live state records 24 HP, `has_acted=true`, round 1 and battle still in progress. [Opening action](images/nilu-opening-acted.png), [closing action](images/nilu-closing-acted.png). No positions, actions, HP or outcomes were injected. These focused checks stop after that action; they do not claim closing-battle victory.

[Curated roster/cell/action receipts and fixture delta](nilu-retest-results.json). Existing battle snapshots retain saved positions under the accepted repair; none was used to demonstrate new deployment. The owning basis is MASTER_PLAN §2 data-driven resources / §6–10 WO-5.5/5.6/7.4 and CHARACTER_BIBLE_NILU introduction, Combat and Open/to-decide. No bonded deployment/loss mechanics were added or inferred.

## Castle feedback — PR #38 / issue #15

Same tested accepted main `eecc29f3`. Real keyboard gameplay and OS window resizing, with client-window-only captures inspected; no direct toast/fishing/support-completion handler calls. This complements #15's scripted renders.

**Native activity and empty archive:** load a byte-copy of the earned Emberwing Week 2 return, with its original Warded Coin ×1 and no unlocked C support. Walk to Waterside, cast with Return and strike with Space during the observed bite. At 1280×720 the new [Lakeperch ×1 result](images/toast-fish-default.png) is fully readable; the fish log gains the catch. After leaving fullscreen/unmaximizing and resizing the same window to 800×450, another [Silver Dace ×1 catch](images/toast-fish-800.png) is fully readable and recorded. One intermediate catch occurred at the window manager's 1280×669 size while leaving fullscreen; it is not represented as an 800×450 check. No fishing RNG or catch was seeded.

Walk through Great Hall to Common Hall and interact at **Gather by the fire (bonds)**. The complete [empty-archive message fits at 800×450](images/toast-empty-800.png), rect `(40,60,720,34)`. At 640×360 it wraps to two lines, rect `(40,60,560,71)`, but [overlaps the interaction prompt](images/toast-empty-640.png): this fails composed readability, despite passing bounds/line-count checks. Restoring 1280×720 makes the [same message readable again](images/toast-empty-restored.png), with height reduced to 34.

**Support availability/completion, separate eligibility fixture:** copy the original Emberwing return to another disposable directory; set Kai–Kael points to 20/rank C and viewed to `{}`, exactly as in the earlier archive fixture. Load through Title and walk to the Common Hall. The [unwatched entry](images/support-available-default.png) is readable at 1280×720. Complete its actual authored dialogue with Return; the [completed checkmark](images/support-completed-default.png) appears and the entry remains replayable. Resize to 800×450 and replay it through real dialogue input: the [completed row remains readable](images/support-replayed-800.png), with exactly one `kai_kael:C` receipt. There is no completion toast in this path; the visible completion feedback is the archive checkmark. This fixture does not establish natural C-rank accrual. Earlier reload and missing/malformed/empty-asset coverage remains the evidence for those unchanged boundaries; it was not rerun here.

[Curated feedback/viewport/receipt observations](toast-retest-results.json). #15's old off-right-edge toast displacement is repaired at the tested sizes; **small-window HUD composition is not fully qualified**:

- [#40](https://github.com/KumarG23/vael-academy/issues/40): resizing 1280→800 leaves the calendar at `(850,12)`, size `(198,26)`, entirely outside the viewport. Compare the default and small fishing captures. Restoring the original size restores visibility. This is the separate absolute-position date label that #38 left untouched.
- [#42](https://github.com/KumarG23/vael-academy/issues/42): the persistent interaction prompt collides with wrapped feedback at 640×360. The resized 800×450 archive capture also shows a stale/clipped interaction prompt while the archive menu is open; the target archive row itself is readable. Repair must consider the composed HUD, not only the toast rect.

Both are reproducible functional display defects, not taste observations or progression blockers. All open/closed issues and PRs were checked before filing; implementation remains separately assigned by the lead. Basis: MASTER_PLAN §1 school slice, §6/§10 WO-4.4, WO-6.2a/6.4 and WO-7.1; ACADEMY_BIBLE §§3–4. Approved Clash semantics and unresolved calendar/story mapping are not changed by this QA.

## Final verification and remaining limits

Latest focused accepted-code retest (`eecc29f3`): serialized editor import exit 0, no script-load errors; deployment/layout regressions **7/7, 487 assertions, 2 scripts**, exit 0 (2.616 s), disposable data. The focused run retains two ObjectDB leak warnings and one resource-in-use exit diagnostic. Per the lead’s focused-retest instruction, no redundant full GUT/helper rerun was made: accepted PR #34 Verify **39814352011** and PR #38 Verify **39815369649** both succeeded on their reviewed heads. The later main integration `24b9bf53` changes only MASTER_PLAN, HANDOFF and the two owning bibles (#37); game source/data/tests are identical to the tested SHA. No QA source/test/renderer/canon changes.

Previous combined verification after accepted #14/#20 (`19cad888`): editor import exit 0/no script-load errors; full GUT **800/800, 10,296 assertions, 100 scripts, 201.302 s**, exit 0. Shared lock/disposable data; helpers **42 pass/two opt-in skips** (44 discovered). The suite retains 22 deprecations, two ObjectDB leak warnings and one resource-in-use exit diagnostic; these did not fail the run and are not claimed fixed. No gameplay source/tests/renderer changes in this evidence revision.

Previous combined verification after accepted #16 (`9afc166a`): editor import exit 0, no script-load errors; full GUT **791/791 tests, 9,501 assertions, 99 scripts, 200.053 s**, exit 0. Shared lock and disposable data; helpers **35 pass/two opt-in skips**. There were 22 deprecations, no script-load errors and no ObjectDB/resource-in-use exit diagnostic in this run.

Previous integration verification after accepted #11 (`883ff334`): editor import exit 0, no script-load errors; full GUT **787/787 tests, 9,467 assertions, 98 scripts, 198.36 s**, exit 0. Both used disposable data and the shared heavy lock. Helpers: **35 pass, two opt-in skips**. The suite reported 18 deprecations. No game source/tests/renderer changes relative to accepted main.

Earlier route/support verification: Editor import exited 0 with no script-load errors. Full GUT exited 0: **771/771 tests, 6,823 assertions, 96 scripts, 180.212 s**. Both ran under the shared lock with disposable data. The suite retains 18 deprecation reports, two ObjectDB leak warnings and one resource-in-use exit error; none failed the run. Team helper checks ran 37 tests: 35 passed, two opt-in user-systemd probes skipped. No story/design, source mechanics or tests were edited by QA.

Remaining qualification gaps are explicit: six baseline functional defects were filed separately. #19 now passes its accepted-code graphical regression retest above; #14 now passes sparse-row/write/cancel checks and #20 passes spawn/movement plus road-victory checks on accepted `19cad888`. #23 now passes fresh opening/closing deployment and movement checks; #15 passes repaired toast layout and default/800×450 feedback, with newly filed calendar/prompt defects #40/#42 still open; Title’s related zero-based labels are unchanged by #14’s accepted scope. #16 now passes its accepted-code desktop close/nested-Inventory retest above. Neal resolved the event contract/name in #22; implementation remains #28/#29, with precise calendar/story mapping pending #30. Accepted #11 now passes the graphical malformed/valid-load retest above. Only Emberwing was a fresh New Game run; the two other routes reused the earned road checkpoint. Archive eligibility and malformed assets were fixtures; natural C-rank accrual was not established. Speaker/headphone listening and Neal’s visual/story/taste approvals were not claimed. Earned later-week/full-semester progression, active-defense production adoption and VS-1C are outside this validation; the closing deployment above is explicitly a Week 6 fixture. #37 reconciles the approved Clash contract in the owning documents; upcoming #29 six-scene parity and its separate #39 graphical qualification are not certified here. Retest the affected paths on accepted repair commits before closing parent #8.

## Evidence index

- [Road introduction](images/road-intro.png), [native round-3 reload](images/road-resumed.png), [water-tile forecast](images/road-perrin-forecast.png).
- [Emberwing preview](images/emberwing-preview.png), [Week 1 campus](images/emberwing-campus.png), [fishing result / clipped toast](images/fishing-result.png).
- [Sparse save labels](images/sparse-save-slots.png), [Journal Escape opens system menu](images/journal-cancel-system.png), [initial locked archive feedback](images/archive-initial.png).
- [Emberwing preparations](images/emberwing-rite-prep.png), [round 3 after Kai fell](images/emberwing-mock_battle-turn3.png), [victory](images/emberwing-mock_battle-result.png), [Week 2 return](images/emberwing-return.png).
- [Tidemark preview](images/tidemark-preview.png), [Tidemark preparations / six foes](images/tidemark-rite-prep.png).
- [Native Emberwing prebattle save](emberwing-rite-start.json), [curated input transcript](emberwing-actions.md). To reproduce, copy the JSON to `godot/app_userdata/Vael Academy/saves/slot_0.json` beneath a **new disposable** `XDG_DATA_HOME`, launch normally and Load through Title; choose Begin battle only if Preparations appears (native battle loads can resume directly). Do not overwrite a real player's slot.

- [Archive eligible / unwatched](images/archive-unwatched.png), [malformed asset retained](images/archive-malformed.png), [actual playback](images/archive-playback.png), [completed checkmark](images/archive-completed.png), [native reload checkmark](images/archive-reloaded.png).
- [Thornrook roster preview](images/thornrook-preview.png), [house persisted on reload](images/thornrook-reloaded.png), [six-rival preparations](images/thornrook-rite-prep.png), [Thornrook Victory overlay](images/thornrook-victory.png), [Tidemark Week 2 return](images/tidemark-return.png).

- [Battle invalid asset remains available](images/battle-support-malformed.png), [completed battle support](images/battle-support-valid.png), [receipt retained after battle reload](images/battle-support-reloaded.png).
- [Stationary pointer selects Kael after keyboard movement](images/pointer-stationary-selected.png), [selection after camera pan](images/pointer-panned-selected.png), [960×540 client / zoom fixture](images/pointer-resized.png), [outside-map margin ignored](images/pointer-outside-margin.png).
- [Nilu at (0,0)](images/nilu-corner.png), [native Thornrook prebattle save](thornrook-rite-start.json). Reproduce with the same isolated-save instructions above, then move the preparations cursor to (0,0). This screenshot was retaken on accepted `ca584fe2`; the native route run was on `f975683c`.
- PCM clips: music [before](audio/music-before.wav) / [muted](audio/music-muted.wav) / [latest track resumed](audio/latest-track-resumed.wav); narration [before](audio/voice-before.wav) / [muted](audio/voice-muted.wav); SFX [before](audio/sfx-before.wav) / [muted](audio/sfx-muted.wav).
