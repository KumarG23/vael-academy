# CP-5 ankle join correction

Neal reported that the foot sometimes detached from the leg after the sword
and trouser corrections ("looking better"). The rigid painted foot was
registered at the authored ball joint, but its cuff differed from the source
ankle by up to 11.49 screen pixels. The boot shaft ended at that source ankle,
leaving a visible gap. The recorded old pose and probes reproduce the defect.

The shaft now ends inside the actual painted foot cuff. Its upper opening
keeps its existing registration below the knee; the rigid foot keeps its
source-driven planted toe and rotation. This changes only the garment join.
The trouser mesh, forward grip, original face/torso and accepted mannequin
motion are unchanged. No texture edits or image-generation calls.

`pilot.mp4` shows the ordinary out-and-back comparison followed by complete
close-up Normal/Formal cycles in both facings. `before-detached-foot.png`
records the old break; `ankle-*.png` records the repaired matching phases.
`capture.gd` reproduces the video with a real renderer:

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp5-ankle.avi \
  -s assets/art_review/cp5_art_transfer/ankle_v3/capture.gd
```

The focused regression samples opaque foot-cuff pixels against the transformed
boot-shaft texture across 80 phases of Idle, Walk and Walk_Formal, both legs
and both facings (960 poses). The pre-fix walk has zero overlap at some poses;
post-fix probes retain at least 47 sampled overlap pixels through both walks.
The planted-toe, original-head, comparison and sword checks remain green.

**547/547 tests pass, 3,386 assertions; focused 5/5, 61 assertions.**
Full-suite and focused logs are saved beside the capture. These verify the
join and existing mechanics; the overall art/motion remains Neal's review.
