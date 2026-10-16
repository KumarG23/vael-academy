# VS-1B.5 — native visual review

Start with [road story](road-story.mp4) (2m 03.87s), then
[tactical effects / ranges](tactical-review.mp4) (15.17s).
Both are actual Godot MovieWriter 1152×648 / 30fps output, H.264/AAC transcoded.
Story clip covers all 28 intro  + 29 outro panels with revealed text and reading
holds. Production typewriter is unchanged. Tactical footage shows the normal
camera, full-board review camera, Kai's real movement overlay and threat toggle.
Full-board framing is a review aid; production camera settings are untouched.

[Contact sheet](review-contact.jpg) combines resized native screenshots only.
Individual captures preserve native resolution:

- [Hamlet raid](road-00.png), [Kai intervenes](road-06.png),
  [four strangers](road-27.png).
- [Normal battle camera](map-start.png), [full board](map-overview.png),
  [movement](map-movement.png), [threats](map-threats.png).
- [Aftermath](aftermath-00.png), [Essa's bread](aftermath-11.png).
- `08-native-forecast.png` and `victory-after-bread.png` verify actual battle/result;
  `{emberwing,tidemark,thornrook}-{choice,pitch,campus}` verify every route.

The normal-camera/movement/threat evidence shows clear actor silhouettes, original
road/ford lanes, and existing UI over the new dressing. More danger is conveyed
by scenery, not fake target sprites or extra enemies. Four new native edge props
and one market prop all anchor on existing blockers; scatter adds no collision.

## Verification and reproduction

- `full-tests.log`:589/589, 4,423 assertions, 89 scripts, 151.856s.
- `focused-tests.log`:13/13, 182 assertions, 2.581s.
- `smoke.gd` / `smoke.log`: real NewGame, all seven VN scenes, legal original
  round 5 victory, bread before result, all three real oaths/Week 1 campuses and
  completed-road isolated saves. Original units/terrain/stats; seed1.
- `map_review.gd` / `map-playback.log`: animation/camera/selection leave full
  native battle save payload unchanged. No combat commands are executed here.
- `playback.gd` / `story-playback.log`:57 panels counted, real advance input;
  no Campaign or save writes. New kitchen/handoff are unchanged and omitted
  from this focused review clip, but included in the separate full-path smoke.
- Known inherited 13 GUT deprecations/two ObjectDB/one resource exit reports remain.

```sh
/tmp/vael-pilot-venv/bin/python assets/sprites/sources/generators/road_raid_dressing.py
godot --headless --import
godot --headless -s tools/build_road_raid_dressing.gd
godot --path . -s assets/art_review/vs1b5_raid/smoke.gd
godot --path . --fixed-fps 30 --write-movie /tmp/vael-vs1b5-map.avi -s assets/art_review/vs1b5_raid/map_review.gd
godot --path . --fixed-fps 30 --write-movie /tmp/vael-vs1b5-story.avi -s assets/art_review/vs1b5_raid/playback.gd
```

Transcode each AVI with ffmpeg/libx264 CRF20,yuv420p,AAC160k,faststart.
Source prompts/selections/rejections and engineering rationale: `VS1B5_VISUAL_NOTES.md`.
Previous VS-1B evidence stays in its own folder. No original portraits or bread
illustration were changed. Neal's remaining review is the taste/readability
judgment, especially chaos vs focus and the transition into the pixel board.
