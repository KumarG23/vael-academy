# CP-7 — contact before collapse

Based on green **6394aef2 (CP-6)**. Neal approved illustrated battles, the
color/magic pass and removal of illustrated walking. He reported Serra
appearing to go down before the hit. Pixel exploration/tactics stays locked.

The underlying HP/contact order was correct, but the inherited lethal reaction
selected the kneeling defeat illustration immediately at contact. The hit-stop
therefore froze an already-defeated silhouette. CP-7 changes only B's lethal
visual sequence: upright parry/hit at contact → brief recoil + 0.16-second
upright hold after hit-stop → defeat pose/knockback → existing fade. Whole
illustrations retain scale/rotation; no anatomy deformation or generated art.
HitReaction classification, actual contact-time HP and the resolver are unchanged.

[Motion review](defeat-timing.mp4) — native **1152×648, 60fps, 10.85 seconds**,
with sound. Ordinary wounded-target defeat and full critical/counter exchange
use the same native seeds/results as CP-6. Screens show approach, upright impact,
collapse and critical collapse. The capture script waits for actor texture
refresh before saving stills; beat logs record requested pose/HP synchronously.

In the recorded ordinary hit, commit is frame 100 with Serra idle at 6 HP;
contact is frame 108 with her hit pose at 0 HP; collapse is frame 132. Critical
lethal contact is frame 490, collapse frame 514. Both give **24 rendered frames
(0.4 seconds, including hit-stop)** before collapse. Impact/collapse now read in
that order. This remains a key-pose change, not a newly drawn falling animation;
the existing kneeling art also omits Serra's lance. A dedicated fall/weapon pose
could improve that later, but is not required to fix the premature-collapse read.

Focused regression: **1/1 test, 32 assertions**, native ordinary/critical lethal
exchanges; checks approach pose, contact-time source HP, upright hold, single
collapse after that hold, unchanged anatomy scale/rotation, complete ordered
native results and clean map return. Full suite: **553/553 tests, 3,604
assertions, 83 scripts, 110.828s**; results in `gut-full-log.txt`. Inherited 13
deprecations and two ObjectDB / one resource exit reports remain.
Existing CP-6 parity/miss/real-input tests remain in the suite.

No imports, new generation calls or spend. Existing art and FX credits/licenses
are unchanged: [CP-6 provenance](../../source/hybrid_combat_fx/README.md).
CP-2/4/5 and original CP-6 captures are preserved.

Reproduce from the project root:

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp7-defeat.avi -s assets/art_review/cp7_defeat/capture.gd
ffmpeg -y -i /tmp/vael-cp7-defeat.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart assets/art_review/cp7_defeat/defeat-timing.mp4
```

Next proposed WO: integrate this player into one supported existing Kai/Serra
tactical encounter through the existing executor. Verify counters, contact HP,
weapon uses, XP/results, boss yield and map return without re-resolving combat.
Preserve the existing presentation for unsupported units/weapons and the existing
kit eligibility policy. Keep roster production paused until that flow works.
