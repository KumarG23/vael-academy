# Issue #81 — earned academy fast travel

Authority: MASTER_PLAN §§1–2 (especially rules 2/4/8/9), §6 WO-9.8, partial §10 M9; ACADEMY_BIBLE §§3/4b; HANDOFF #69. No canon contradiction found. Existing room names, geometry, doors, interactions, renderer and calendar are retained.

M opens the existing current-room map. Tab or the gold “Visited rooms” heading switches the side list from exit labels to eligible visited destinations. Up/Down selects, Enter/Space or a row click travels; M/Escape/right-click cancels. Confirming the current room leaves the map and location unchanged. Both lists scroll within the existing compact layout; the room map and live marker remain visible.

`Campaign.academy_visits` is optional campaign metadata, earned by normal `enter_room`, deduplicated and reset by New Game. Ordinary campaign saves and active battle snapshots carry it. Missing legacy metadata means no historical unlocks; subsequent room entry earns only that room. Unknown well-formed IDs and excluded Grove/town IDs are discarded on restore. Invalid collection/member types or malformed IDs are rejected before Campaign/roster/RNG/staging mutation, including Title/Journal callback routes and battle resume/direct slot loads.

Destinations come from the loaded public room resources and existing directed door graph. There is no door access-condition field in the current data model; blocked/out-of-bounds source door cells or destination spawns break an edge. Travel never routes through Grove or town interiors. An eligible destination must have an authored inbound spawn that is in bounds, passable, and on neither a door nor an interaction point. Bad or disconnected data fails closed before the map closes or location changes. Confirmation revalidates the live data. Travel uses normal `enter_room`, including music, camera, NPCs, title and door guard, and clears the old room's interaction reference before fresh input. It does not begin a hub visit, rest, train or advance the calendar.

## Automated evidence

The corrected related run passes **122/122 tests, 5,457 assertions / 11 scripts**, exit 0 (24.712 s), including all nine new travel tests and all original map assertions. There are 24 inherited test deprecations and no script-load or exit-time resource errors in that run. Tests use disposable player data and the shared Git-common-directory `vael-godot-heavy.lock`.

Clean import, full GUT, helpers and exact-head CI receipts are recorded on the PR linked from [issue #81](https://github.com/KumarG23/vael-academy/issues/81) as each completes. They are separate from the pending graphical gate below.

Coverage includes actual movement across physical doors for discovery/deduplication; undiscovered/excluded rooms; keyboard and pointer browse/confirm/cancel/current-room behavior; safe arrival, no bounce, ordinary door/activity continuation; complete Campaign/training-RNG/resources/inventory/support invariance; default/compact list bounds; unknown/disconnected/blocked destinations; all currently reachable public rooms' authored arrivals; campaign slots, New Game, legacy defaults, unknown-ID filtering, active battle save/fresh scene resume; atomic malformed field/member rejection, including real Title/Journal callbacks in child processes. Fresh child processes also perform successful Title/Journal load callbacks and normal campus entry after saving earned visits. Existing map, castle, Journal-close, flow, save and resume assertions are retained. The GH-54 real result-return fixture retains its complete Campaign/grade comparison: its first actual victory return to campus now expects exactly the new `campus` visit; defeat still earns none. No existing grade/result assertion is removed.

## Runtime acceptance — pending, PR stays draft

No graphical game, desktop input or capture was launched for this issue. Issue #81 is queued after #75 then #76. The task explicitly requires #76 to end all jobs and release the desktop, and the lead to name #81, before this issue can use it. Automated viewport tests are not original-renderer graphical evidence.

The required bounded run remains:

1. Record exact source and native checkpoint provenance/hash in a disposable profile; do not seed visit metadata. Enter at least two public academy rooms through ordinary physical doors and distinguish checkpoint state from earned visits.
2. Inspect the map/earned destination list at default and compact sizes. Verify undiscovered exclusion, keyboard/pointer selection, cancel and current-room no-op.
3. Travel to a visited destination, inspect the safe landing, then continue through an ordinary door and activity without a bounce, stray activation, calendar/resource change or lost input.
4. Save through the normal UI, quit, relaunch and load; verify unlocks and travel still work. Inspect and retain captures and exact source/results.

No full-school replay or Neal visual/taste approval is claimed. Same owner retains runtime QA and any PR revisions; the engineering lead reviews and merges the exact passing head.
