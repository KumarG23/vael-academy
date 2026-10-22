# Six routed Clash of Three Banners contests — issue #39

Graphical qualification of the six existing sample encounters, using accepted game source `2e96594e303d811a9d35dcfd7f7309069bdedc68` (includes #29 merge `2c1698fe`). Godot 4.7.2, original Vulkan Forward+ renderer on llvmpipe, existing shared 1280×720 desktop, disposable player data. Screenshots are unaltered desktop captures and were inspected. Production behavior, stats, equipment, HP and RNG were unchanged. Every combat action used the game’s real input path; no combat/result handler was called to assign an outcome.

Owning contract: [MASTER_PLAN §3, §6 WO-5.6/WO-7.4, §10 AW-30/GH-29](../../../MASTER_PLAN.md); [ACADEMY_BIBLE §4](../../../ACADEMY_BIBLE.md#4-calendar--traditions); [CAMPAIGN_STRUCTURE “What house choice actually forks”](../../../CAMPAIGN_STRUCTURE.md#what-house-choice-actually-forks); [CHARACTER_BIBLE_NILU introduction, Combat and Open](../../../CHARACTER_BIBLE_NILU.md). Nilu uses the shipped roster, including the preserved Thornrook player cell (4,11); no proposed bonded deployment/loss rule is assumed. The sample calendar and authored dialogue remain historical scaffolding; this qualification does not implement the approved first-year structure or final hostile interruption in #30/#52, approve new canon/art, or complete #28/#8.

## Entry and fixture provenance

The #40 and #43 explicit desktop releases preceded the original #39 claim. The quota successor reconciled/stopped the inherited `all.sh`/`entry.sh` input jobs before input, retained one existing game/controller, and then used sequential OS keyboard/pointer input. No second desktop controller was started. The final release is recorded on #39.

Every fresh encounter follows **Title → Load campus slot → walk to Mission Board → Deploy → advance authored intro → preparations → Begin battle**. No Dev Jump was used for these successor runs. All positions are zero-based map cells. Keyboard arrows move the cursor/avatar; Return confirms, Escape opens preparations/cancels, T → End Turn runs the ordinary enemy phase. Pointer hover selects visible map cells; movement, attacks and saves still go through the real menus.

The native Thornrook opening byte-copies the earned `../issue-5-school-loop/thornrook-campus-save.json` with no field changes. Other fixture copies use the corresponding earned `*-return-save.json`: only `campaign.week` changes 2→1 for an opening or 2→6 for a closing. Classic additionally changes `campaign.casual` true→false. Contrary to an early preparation note, these fixture files do not change `training_used`. They contain no battle snapshot, so fresh ChapterRegistry entry uses #29's forces and ROUT. Pre-#29 battle snapshots intentionally preserve their historical forces, cells and objective and are not used to qualify the repair.

Exact fixture changes are retained in [fixtures.json](fixtures.json). Recovery runs first earn a new victory, return to campus, and save through Journal → System → Slot 3. Only the resulting copy's week 2→6 changes for the next deployment; that calendar setup is explicitly a fixture, not a played semester. Unit progression, inventory, loss/recovery state and mode are preserved.

## Coverage

[Coverage receipts](results.json) retain route/roster/placement, combat and save comparisons. [Curated action sequences](actions.md) reproduce the completed battles without direct handler calls. The saves are newly earned UI snapshots on the declared accepted source, not pre-repair fixtures.

All six fresh boards contain **20 unique actors**, with the exact shipped chosen roster + Kai and both complete rival rosters. Live movement inspection confirms in-bounds, traversable starts and more than one legal stopping cell per actor; the two Thornrook player entries preserve Nilu **(4,11)**. Each entry shows **Clash of Three Banners** and ROUT. Calendar/mission-board labels retain their existing sample wording.

| Chosen house | Event | Player / rival teams 1,2 | Victory round | Entry | Result | Resumed UI save |
| --- | --- | --- | --- | --- | --- | --- |
| Emberwing | Opening | 7 / Tidemark 6, Thornrook 7 | 5 | [Capture](images/emberwing-opening-entry.png) | [Victory](images/emberwing-opening-victory.png) | [Capture](images/emberwing-opening-resumed.png) |
| Tidemark | Opening | 7 / Thornrook 7, Emberwing 6 | 10 | [Capture](images/tidemark-opening-entry.png) | [Victory](images/tidemark-opening-victory.png) | [Capture](images/tidemark-opening-resumed.png) |
| Thornrook | Opening | 8 / Emberwing 6, Tidemark 6 | 7 | [Native entry](images/thornrook-opening-entry.png) | [Victory](images/thornrook-opening-victory.png) | [Capture](images/thornrook-opening-resumed.png) |
| Emberwing | Closing | 7 / Tidemark 6, Thornrook 7 | 9 | [Capture](images/emberwing-closing-entry.png) | [Victory](images/emberwing-closing-victory.png) | [Capture](images/emberwing-closing-resumed.png) |
| Tidemark | Closing | 7 / Thornrook 7, Emberwing 6 | 9 | [Capture](images/tidemark-closing-entry.png) | [Victory](images/tidemark-closing-victory.png) | [Capture](images/tidemark-closing-resumed.png) |
| Thornrook | Closing | 8 / Emberwing 6, Tidemark 6 | 10 | [Recovery entry](images/thornrook-closing-entry.png) | [Victory](images/thornrook-closing-victory.png) | [Capture](images/thornrook-closing-resumed.png) |

All six victories have **zero surviving rivals, Kai alive and `last_result = victory`**. Openings return to the sample’s Week 2; closings to Week 7. The five calendar-fixture routes explicitly let both AI phases run, exercise a real player forecast/attack, save in round 3, relaunch/load, then continue the same earned board to victory. The native Thornrook opening saves/reloads in round 1 and completes the whole battle; its later lord-loss replay also samples passive rival combat. A terminated long input process was reconciled during Thornrook closing: the existing game had reached round 5 and was continued unchanged to round-10 victory.

Actual rival combat includes Fenn (team 2) damaging Dain (team 1), Thessaly (2) downing Elowen (1), Brenna (2) damaging Vesper (1), and Corvin (2) downing Fenn (1). [Per-route samples, HP changes and captures](results.json) identify the acting/defending factions. These are ordinary AI-phase exchanges, triggered by T → End Turn.

| Route | Actual rival AI exchange | Actual player forecast/strike |
| --- | --- | --- |
| Thornrook opening | [fenn → dain, HP 28→19](images/thornrook-opening-rival-combat.png) | [corvin → kael](images/thornrook-opening-player-forecast.png) |
| Thornrook closing | [fenn → dain, HP 28→19](images/thornrook-closing-rival-combat.png) | [kai → isolde](images/thornrook-closing-player-forecast.png) |
| Emberwing opening | [thessaly → elowen, HP 7→0](images/emberwing-opening-rival-combat.png) | [perrin → isolde](images/emberwing-opening-player-forecast.png) |
| Tidemark opening | [brenna → vesper, HP 18→5](images/tidemark-opening-rival-combat.png) | [kai → thessaly](images/tidemark-opening-player-forecast.png) |
| Emberwing closing | [corvin → fenn, HP 11→0](images/emberwing-closing-rival-combat.png) | [perrin → isolde](images/emberwing-closing-player-forecast.png) |
| Tidemark closing | [brenna → vesper, HP 18→5](images/tidemark-closing-rival-combat.png) | [kai → thessaly](images/tidemark-closing-player-forecast.png) |

The old quoted boss is also insufficient for victory: in Emberwing opening, **Serra has yielded, her quote has played, all Tidemark rivals are gone, and six Thornrook rivals remain**. The battle continues in round 3, then wins only after the last Thornrook unit falls in round 5. [Live boundary receipt](boss-boundary.json), [continued-play capture](images/quoted-boss-cleared-continues.png).

## Save/load and defeat boundaries

Field menu → Save game → Slot 2, normal window close, new game process, Title → Load → Slot 2, and a second field-menu save. Comparisons include the entire campaign, battle, roster and supports payload: house/mode, objective, independent teams, positions, HP, inventory/uses, acted flags, round, combat RNG and progression. The restored chapter ID resolves through ChapterRegistry's existing resume table. The cursor itself is intentionally restored by the production loader; it is not part of the serialized board comparison.

**Casual:** Marlow, Vesper and Rurik yielded during the native opening, which still won in round 7. Dismiss Victory → campus Week 2 → Journal/System/Slot 3 save → copy only week 2→6 → Title load → Mission Board → fresh closing. All three return at full HP **20/18/27**, with the complete eight-player roster and Nilu (4,11). [Actual loss and fresh recovery receipts](casual-recovery.json), [continued play after losses](images/casual-yields-continued.png), [next deployment](images/casual-next-deployment.png).

**Classic:** start the explicitly declared mode fixture (`campaign.casual: true→false`). Corvin, Marlow, Nilu and Vesper yield during ordinary play; the opening wins in round 9 with no permanent losses. The same earned-result → real campus save/load → week-only next-deployment setup restores all four at full HP **19/20/24/18**. Classic persists through deployment and another exact UI save/relaunch comparison. [Receipts](classic-recovery.json), [Victory](images/classic-victory.png), [fresh next deployment](images/classic-next-deployment.png), [earned campus payload](saves/thornrook-classic-campus-return.json). This checks the delivered school-battle mode behavior without claiming a complete Classic campaign.

**Lord loss and resume:** replay the unchanged native opening’s round-1 UI save. Let two ordinary AI phases run, then move Kai through movement/Wait menus and end turns. Damage reduces him normally to **3 HP**; the actual round-5 [field-menu pre-loss save](images/lord-preloss-save-ui.png) retains a live lord, unfinished ROUT and the earned board/RNG. End Turn produces animated Kai defeat/removal: `lord_node_valid=false`, `lord_alive=false`, Defeat and `last_result=defeat`, **Week 1 unchanged**, with Rina, Corvin and Nilu still alive. Dismissing Defeat reaches Title.

Load that same [earned pre-loss payload](saves/lord-preloss.json) through the real Title UI and End Turn again. The entire loaded payload matches, and the entire defeated campaign/battle/roster/support payload matches the first loss, including combat RNG. The freed-lord result again shows Defeat and no calendar advance. [First Defeat](images/lord-defeat.png), [resumed Defeat](images/lord-resumed-defeat.png), [Title after defeat](images/lord-title-after-defeat.png), [4.3-second silent real-time replay clip](lord-loss-resume.mp4), [structured boundary receipt](lord-loss.json). No lord-loss flag, HP, removal or result was synthesized; saving after the terminal overlay is unavailable, so this uses the practical pre-loss UI boundary.

## Limits and integration

Live inspection was observational: it sampled existing nodes, legal movement, forecast/AI decisions and serialized state. Decisions were carried out with real OS input and normal menus/animations. It did not call combat executors, damage/kill/result/progression handlers or change production properties. Actual AI phase exchanges are recorded separately from player choices.

The tested source predates the separate #54 report-card attribution repair. This report qualifies battle routing, factions, combat, ROUT, recovery, lord loss and save continuation; it does not claim correct closing-score attribution on that older source. Later accepted-main integration and its affected boundaries are recorded below. No new functional defect is inferred from an existing issue or a test-only diagnostic.

Accepted-main integration fast-forwards to `11e08763`, after graphical execution on the declared `2e96594e`. Contest chapter/scene data, units/kits, battle presentation/input/spawning, AI, formulas, Campaign/ChapterRegistry, objective/turn and save/resume source are identical across those SHAs. The production delta is the separately accepted audio-preference persistence in AudioManager and Journal volume handling; workflow/first-year documents also advance. The captures remain attributed to their actual test SHA. The approved two-semester structure and distinct final hostile interruption remain authoring/implementation scope in #30/#52; these six sample friendly contests do not establish that full-year outcome.

[Verification receipt](verification.json): clean Godot import **exit 0** (54.08 s), then full GUT **829/829 tests, 12,106 assertions, 105 scripts**, exit 0 (reported test time 221.132 s; process wall time 226.60 s). Both checks used disposable player data and the shared heavy lock on integrated game source `11e08763abfd33b963b4c8e73732225b68b37fc8`. Existing tests are preserved. There are 22 existing deprecations and expected malformed audio/dialogue fixture diagnostics; no script-load errors, ObjectDB leak warnings or resource-in-use exit diagnostic. These headless checks validate integration separately from the graphical evidence above. Local evidence links, JSON/schema invariants, screenshot metadata, public-text scan and `git diff --check` pass. [Artifact hashes](manifest.json) cover the curated files, excluding generated import caches.

The desktop was explicitly [released to #42](https://github.com/KumarG23/vael-academy/issues/39#issuecomment-6350378269) after the final game, input and capture processes ended. No additional functional defect was found to file; #54 remains the existing independent grading repair. Engineering lead review is pending; no Neal visual/story approval is claimed.
