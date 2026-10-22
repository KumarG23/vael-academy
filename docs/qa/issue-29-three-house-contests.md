# Issue #29 — routed Clash of Three Banners contests

Scope: the three existing `mock_battle` and three `closing_rite` ChapterRegistry routes. Neal's [contract](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340423944) and [name decision](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340542559) supersede the historical one-rival cycle and annual-only wording. MASTER_PLAN §3 (normal combat/lord defeat), §6 WO-5.6/7.4 and §10 AW-30, ACADEMY_BIBLE §4, and CAMPAIGN_STRUCTURE “What house choice actually forks” own this change. The document reconciliation is #22 / PR #37; calendar/final-sabotage clarification remains #30.

## Data and local placement decisions

Every route fields its existing chosen-house roster plus Kai on team 0. Each other house has its existing full roster on a distinct opposing team. Emberwing and Tidemark each have six units; Thornrook has its six students plus Nilu. Nilu's inclusion follows the shipped Roster and CHARACTER_BIBLE_NILU introduction, not a change to noble membership or the proposed bonded deployment/loss rules in that bible's Combat/Open sections. CHARACTER_BIBLE_HEADS and the three house character bibles own the existing heirs/cast/kits.

- Emberwing opening already has both complete rival factions. Its formation is unchanged.
- Tidemark opening keeps its six existing Thornrook starts and brains on team 1. Nilu is added at **(18,2)**, beside Rina at (17,2). The missing Emberwing force uses the existing Tidemark closing route's southeast placements and brains: Kael (15,13), Dain (17,12), Liora (13,13), Brenna (18,10), Wren (16,11), Perrin (19,12), on team 2.
- Thornrook opening keeps its six existing Emberwing starts and brains on team 1. Its missing Tidemark force uses the existing Thornrook closing route's southeast placements and brains: Osric (15,13), Elowen (17,12), Isolde (13,13), Fenn (18,10), Bertram (16,11), Serra (19,12), on team 2.
- Each closing keeps its existing northeast force on team 1 and gives the existing southeast force team 2. Emberwing closing adds Nilu at **(19,13)** beside its southeast Thornrook group/Rina (19,12). Tidemark closing adds Nilu at **(18,2)** beside its northeast Thornrook group/Rina (17,2). Thornrook closing already fields both full rival rosters.
- Both Thornrook player deployments retain #23's Nilu **(4,11)** entry. All existing player starts remain unchanged.

These are local legal placements, not canonical tile requirements. Tests check every actual movement type, bounds, uniqueness across all factions, and ability to leave the initial cell. No terrain, decor, stats, kits, scene paths, chapter IDs or dialogue changes. Old boss IDs/quotes/yields remain authored; ROUT alone governs victory. The chapter name shown by battle/preparations UI is **Clash of Three Banners**. Calendar entries, authored dialogue and unrelated title cards remain under their existing ownership.

## Runtime evidence boundary

`tests/test_three_house_contests.gd` instantiates all six actual routed PackedScenes with the shipped campaign roster. It exercises native spawning, AI decisions and combat execution, objective/result/campaign capture, real disposable JSON slot IO and `Resume.stage` continuation. Fixtures control HP/positions or remove units where necessary to test outcomes; these are headless runtime checks, not input-earned graphical playthroughs. Existing lord-lifetime tests additionally exercise both animated executor paths across queued node deletion.

Saved battles keep their saved force, positions and objective through the existing snapshot loader; this change introduces no migration or replacement of old checkpoints. Fresh deployments get the repaired resources. Newly created snapshots are covered on all six routes.

Graphical qualification is tracked by dependent [#39](https://github.com/KumarG23/vael-academy/issues/39), after accepted code through #5's sole GUI owner or a separately assigned follow-up: enter all six fresh routed encounters, inspect factions/objective, exercise real-input rival-vs-rival combat, ordinary yields and recovery in Classic/Casual, Kai defeat without calendar advancement, and save/load continuation. Retain screenshots and exact tested SHA; identify any controlled fixtures. Headless success does not sign off this work graphically or complete #28, and does not claim Neal's visual/story approval.

## Verification

On baseline `eecc29f3`, before changing battle resources, the six new tests passed **2/6** and failed **4/6** (909/971 assertions). Failures demonstrated missing rival rosters/Nilu, shared closing teams, the old boss objectives and premature victory, plus the same faction gaps after native JSON resume. Friendly result/campaign persistence and freed-lord defeat already passed in both modes.

After the resource repair, the unchanged six regressions pass **6/6, 1,070 assertions**. The focused house/deployment/rival/closing/mock/AI/turn/objective/campaign/save/resume/lord-lifetime selection passes **144/144, 3,088 assertions across 18 scripts** (40.8 s). This includes native rival-vs-rival combat consuming durability, Classic/Casual house-wide yields followed by slot IO and redeployment, both animated lord executors, and resumed defeat without advancing the calendar.

A separate source comparison confirms identical terrain/decor, deploy maps (including #23), internal IDs and authored dialogue paths on all six chapters. Existing tests remain, with only the approved intro-card name, complete rival count and distinct-faction expectations updated. Helper checks discover 68 tests: **66 pass, two opt-in lifecycle skips**. All game runs use disposable player data; import/full-suite runs hold the shared heavy lock.

Full GUT **813/813, 11,874 assertions, 103 scripts**, exit 0 (213.7 s); clean first/final imports exit 0 with no script-load errors. The full suite reports 22 existing deprecations and the expected malformed-dialogue fixture warnings; no script errors or resource-in-use exit diagnostic. The isolated six-test post-fix run emitted two ObjectDB leak warnings and one resource-in-use exit diagnostic; these were absent from the broader 144-test run and full suite. No diagnostic is represented as a gameplay defect or graphical signoff.
