# VS-1B — final package / portrait style / pixel fire review

Start with [full native story playback](story-playback.mp4) (3m24.9s,1152×648,30fps),
then [pixel road fire with threats](road-fire.mp4) (8.03s). Both are actual Godot
MovieWriter output, transcoded to H.264; no synthesized/composited footage.
Story playback covers all100 package panels, reader-paced with text revealed;
normal play keeps the existing typewriter. It omits the five established scenes
from this review clip only; the real NewGame smoke plays all seven VN scripts.

## Current native captures

| Beat | Captures |
|---|---|
| One morning kitchen / exact existing Kai face style | [Kai's goat](home-02.png), [Tam](home-03.png), [come home](home-22.png) |
| Established scenes retain words/events/art | `established-01` through `established-05` |
| Hesta handoff | [departure](handoff-08.png), [warden](handoff-11.png), [smoke](handoff-19.png) |
| Independent rescue | [well](road-00.png), [Kai](road-06.png), [Serra](road-08.png), [Perrin](road-12.png), [Rina](road-17.png), [four strangers](road-27.png) |
| Quiet bread | [before portraits](aftermath-08.png), [offer](aftermath-09.png), [Essa callback](aftermath-11.png), [child](aftermath-12.png), [waiting](aftermath-14.png) |
| Return to group | [Serra critique](aftermath-15.png), [names](aftermath-24.png), [last beat](aftermath-28.png) |
| Existing flow | `victory-after-bread`, `{emberwing,tidemark,thornrook}-{choice,pitch,campus}` |
| Pixel world VFX | [roof/threats](fire-threats.png), `fire-loop-a/b`, [nearest8× atlas](fire-sheet-8x.png) |

All screenshots are native1152×648; no mockups. Original cast portraits are
unchanged. New commoner/supporting portraits were redone after Neal's style
correction, using exact original portrait references and square framing.
`bread-standard-before.png` is rejected historical comparison with superseded
cutouts; current bread uses small framed portrait insets. The gesture, mother's
presence and child remain visible in the painting through the full exchange.
Old `bread-insets-after.png` is an intermediate cutout review; use final
`aftermath-11.png`, not that intermediate, to judge current portraits.

## Validation

- **585/585 GUT**,4,336 assertions,88 scripts,152.958s: `gut-full-log.txt`.
- **44/44 focused**,595 assertions,3.368s: `gut-focused-log.txt`.
- **6 Python** credential/stdio regressions: `python3 tools/test_pixellab_connection.py`.
- `smoke.gd`/`smoke-log.txt`: actual Title/NewGame → home → five unchanged scenes
  → waystation → original seed1 road victory in round5 → bread before result →
  real existing pitches/oaths for **all three houses** → Week1 campus. Legal
  cursor/menu combat commands; no altered units/stats/terrain/RNG formulas.
  Isolated completed-road save/load branches; no player save slots touched.
- `fire_playback.gd`/`fire-playback-log.txt`: actual road map/fire/threat overlay;
  full battle payload unchanged by animation/panning.
- `playback.gd`/`playback-log.txt`: every package panel logged and counted23/20/28/29;
  no skipped dialogue, Campaign or save writes.
- Existing13 deprecated GUT calls and two ObjectDB/one resource exit reports
  remain. Final tests/captures have no new runtime failures.

```sh
godot --headless --import
godot --path . -s assets/art_review/vs1b_package/smoke.gd
godot --path . --fixed-fps 30 --write-movie /tmp/vael-vs1b-story.avi -s assets/art_review/vs1b_package/playback.gd
godot --path . --fixed-fps 30 --write-movie /tmp/vael-vs1b-fire.avi -s assets/art_review/vs1b_package/fire_playback.gd
```

Transcode with ffmpeg/libx264, CRF20 story / CRF16 pixel clip, yuv420p,
AAC160k and faststart. Originals remain in `/tmp`, not the repository.

## Review questions

Does the commoner Kai read as the same existing boy? Do Tam/Essa/Hesta match the
cast's portrait rendering, and do their faces suit their roles? Does the kitchen
banter make the promise to come home hurt? Is the28-panel rescue too slow before
control? Does Hesta's refusal of answers sound human? Is the bread understated
enough? Does the small fire loop help the map feel alive without hiding play?

Authoritative notes: `VS1B_STORY_NOTES.md`; art provenance:
`assets/source/vs1b_story_art/README.md`; restored VFX connection and8-generation
pilot: `VS1B_VFX_PILOT.md`. VS-1C gate/house drafts are archived, not implemented.
