# VS-1B.5 — Road Raid Visual Cohesion

Neal's visual work order, based on green `8e28b83a` (VS-1B).
Implemented candidates await his visual signoff. No new story revelations or prose.

## What changed, and why

- **Five painted backdrops:** distant approach, endangered child at the well,
  Kai's intervention, four strangers holding the square, and immediate aftermath.
  Multiple separated roof fires/smoke, looters in several lanes, neighbors helping
  an elderly villager escape, damaged market canvas, spilled goods and broken
  wood make the hamlet feel inhabited and attacked. Kai's response remains the
  central personal event within that larger crisis.
- **Shared landmarks:** western fence/steps and escape lane, well, wrecked cart,
  timber/thatched cottages, market awning, eastern water/ford and stone boundary.
  The paintings now acknowledge the tactical river. The map has a worn earth
  apron, scattered load/splinters, distressed market and more edge cottages.
  This is a recognizable tactical abstraction of the same hamlet, not a literal
  camera projection or a rebuilt logical ground plan. The old mountain border
  remains; edge buildings imply the settlement continuing beyond this pocket.
- **Three tactical burn sites:** the original southeast burning cottage and its
  approved PixelLab effect stay intact; a west-edge cottage reuses that fire;
  an eastern scorched cottage uses the original pack's separate smoke clip.
  Existing whole effect already includes fire, smoke and embers. No new VFX
  generation, screen-wide fog, heat distortion or ash veil was needed.
- **Action presentation:** the rescue tableau uses the existing compact portrait
  layout from panel5 onward. Large busts otherwise cover Kai's running face.
  Portrait identity/art is unchanged; later scripts reset layout as before.
  No panel, word, speaker label, event or music cue was added or removed.
- **Quiet callback preserved:** the intimate bread illustration, dialogue and
  portraits are unchanged. The wider aftermath shows damage and exhausted mutual
  help, then the bread closeup gives the player room to come down from the raid.

## Tactical readability and boundaries

All 176 logical cells are byte-for-byte unchanged. Same 16×11 board, four allies,
five original axe raiders, stats/resources, spawn positions/order, AI, objectives,
visits, ford, movement/cover/healing rules and tutorial balance. No new red enemy
sprites or civilians appear on the tactical board: the warden's evacuation still
happens before control. Distant painted raiders imply the wider attack rather
than extra tutorial targets. Every added upright prop anchors to an existing
impassable SITE/mountain cell; flat scatter is walkable flavor. Cosmetic soot
never becomes EMBERS terrain or damage. No save schema, flags, progression,
Crownspark gates, campaign routes or calendar changes.

`MapDecor.ground_layer` defaults false. TerrainTiles draws flat dressing before
upright scenery; range/threat/cursor and actor layers retain their ordering.
Cosmetic effect clocks keep the existing implementation and do not consume RNG
or serialize. Actual movement/threat screenshots and identical native battle
payload before/after camera, selection and animation support the readability
check. Human visual signoff remains Neal's.

## Art provenance and review

- Existing configured **Gemini 3.1 Flash Image** helper: nine requests, all delivered,
  five selected paintings/four rejected versions. Full prompts, immutable masters,
  reference hashes and exact reference snapshots: `assets/source/vs1b5_raid_art/`.
  `jobs.json`, `selections.json`, per-job receipts and `installed.json` describe
  every installed image. Billing dollars are not returned by this helper.
- Rejected versions lost villagers, exaggerated the mark, added a competing
  foreground bucket carrier, or made character composition less useful. Final
  versions favor edits of the established paintings and the compact portrait UI.
- **PixelLab:** one 64×48 empty damaged-cart source, object
  `2520fcc2-8265-4676-a61b-71552e6d08ed`; observed subscription4992→4991, cost
  **one generation**. No further VFX spend. Prompt/result/original/balance receipts
  in `assets/source/pixellab/vs1b5_cart/`. Native cleanup adds a detached wheel,
  broken shaft and scattered load; no smoothing or enlarged fake pixel grid.
- Repeatable pixel dressing: `assets/sprites/sources/generators/road_raid_dressing.py`.
  Existing house/market/cart palette and silhouettes retained; native and 8× sprite
  review plus in-engine inspection. PixelLab smoke reuses the accepted pack's
  12 frames, 10fps, 7×20 effect-only regions and native anchor.
- Existing portraits, kitchen, Hesta departure and bread painting untouched.
  No roster production, new music, academy/gate implementation or character redesign.

## Validation

- Full Godot/GUT: **589/589**, 4,423 assertions, 89 scripts, 151.856s.
- Focused road regressions: **13/13**, 182 assertions, 2.581s. Four new tests cover
  the baseline board/forces, layering and blocker placement, native multi-site
  export/state isolation, and action-inset reset. Existing full suite retains
  opening/flags/save/load/three-house/controlled-Crownspark checks.
- Actual graphical Title→NewGame→seven opening scripts→28-panel rescue→original
  legal seed1 road victory in round 5→29-panel aftermath→result→all three existing
  pitches/oaths→Week 1 campuses. Isolated completed-road save/load, no player slots.
- Native57-panel road playback **2m 03.87s**, plus **15.17s** real tactical animation,
  movement and threat review. Playback logs count every panel; no skipped prose.
- Inherited13 GUT deprecations and two ObjectDB/one resource exit reports remain.
  No new runtime/parse failure in final builder, suite, smoke or playback.

Review files and reproduction: `assets/art_review/vs1b5_raid/README.md`.
Next remains the separately approved **VS-1C arrival / informed house invitations**;
this visual pass adds no arrival scene or house-pitch draft to runtime.
