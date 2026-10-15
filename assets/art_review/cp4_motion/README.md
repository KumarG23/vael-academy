# CP-4 — Authored motion foundation, 2026-10-15

Open **Title → Dev Jump → Authored motion pilot**, or:

```sh
godot res://scenes/proto/authored_motion_pilot.tscn
```

**6 / Walk** walks out and back; **T / Turn** rotates the same rig through a full
turn; **C** toggles sword/free hand; **F** toggles normal/formal walk; left/right
arrows walk; **R** resets; **Esc** returns to title. The Illustrated combat button
opens CP-2 with its accepted attack/cast art.

[Watch the pilot](pilot.mp4) · [Idle](01-human-idle.png) ·
[Walking](02-human-walk.png) · [Return](03-human-return.png) ·
[Turn](04-human-turn.png) · [Formal walk](05-formal-walk.png) ·
[Grip close view](06-grip-close.png)

## Acceptance and Neal's review

Neal accepted the grey mannequin's walk and turn on October 14 ("really good")
and rejected the knight look. That gait and turn are preserved. His remaining
feedback was a backward sword. The corrected hilt now points blade/guard out
the index/thumb end, with the pommel toward the little finger; only the carrying
wrist is tilted to rest the blade forward/down. **Neal approved the corrected grip on October 15: "the corrected sword grip
looks good."** Walk, turn and corrected carry have now passed his review.

| CP-4 acceptance | Evidence |
|---|---|
| Licensed reusable source and actual authored gait | Original CC0 licenses, source files and hashes in `assets/source/authored_motion/README.md` |
| In-engine walk at game scale | Recorded out-and-back plus formal walk; source stance cancels measured travel within the regression tolerance |
| Coherent weapon and directional identity | Sword follows right-hand bone, closed artist-authored fingers; same skeleton rotates without reflecting or replacing the head; diagnostic green marker remains on anatomical left |
| Runnable entry and reviewable clip | Title Dev Jump, this scene, `pilot.mp4`, six screenshots and rerunnable capture script |
| Remaining Kai work recorded | Grey mannequin is a motion specimen. Kai's model, clothing, hair, face/mark, painted shading and equipment/attack poses need a separate approved art pass |
| Green suite and handoff | **542/542 tests, 3,325 assertions**; §10, HANDOFF, STYLE_BIBLE and AUDITS updated together |

The four new tests contain 66 assertions. They sample actual source leg/toe
positions, verify the hand-local sword direction and unchanged thigh rotation
after finger modification, check consistent model/head/marker geometry through
turns, and run the live tour without changing Campaign state. See
`targeted-test-log.txt`, `full-suite-log.txt` and `foot-probe-log.txt`.
The real input path also reaches the pilot from Title → Dev Jump and returns
with Esc; see `entry_check.gd` and `entry-check-log.txt`. The full
suite retains its pre-existing 13 deprecation notices and exit-time report of
two leaked objects / one resource.

This is one isolated 2D presentation proof using an offscreen 3D rig. Campaign,
combat formulas, save schema, story canon and CP-2 attacks remain untouched.
Production performance with many actors, full directional movement, clothing
deformation, scene collision/occlusion and distinct weapon/spell attacks are
not established by this proof. Do not roll it out to the cast yet.

## Re-record

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp4-motion.avi \
  -s assets/art_review/cp4_motion/capture.gd
ffmpeg -i /tmp/vael-cp4-motion.avi -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -movflags +faststart -an /tmp/vael-cp4-motion.mp4
```

Use a non-headless run for visual captures. The script writes six screenshots
to `/tmp/vael-cp4-captures/`; the final close view enlarges only the specimen for
inspection. `checkpoint.mp4` retains the previous session's recording;
`pilot.mp4` and the screenshots are the current resumed capture.
