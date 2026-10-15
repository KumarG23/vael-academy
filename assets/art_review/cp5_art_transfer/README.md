# CP-5 — Existing Kai art with authored motion, 2026-10-15

Neal rejected the first clothed 3D substitute: it did not look like Kai. He asked
for the existing Kai artwork with the better walking animation. This isolated
proof follows that correction. Neal called it **"a pretty good improvement"**
and requested a forward sword grip and trousers without a knee-pad appearance.
Those corrections are now implemented; **the corrected art awaits review**.

Open **Title → Dev Jump → Kai art motion test**, or:

```sh
godot res://scenes/proto/kai_art_motion_pilot.tscn
```

**6** walks out and back, **K** compares the accepted grey mannequin, **F**
switches normal/formal, **C** toggles the carried sword, arrows walk, **R**
resets, **Esc** returns to title. **T shows the actual mannequin turn**. The one
painted view does not contain Kai's back/side artwork; this proof does not invent
those views or claim the reflected drawing is a genuine 3D turn.

[Watch the corrected transfer](corrections_v2/pilot.mp4) ·
[Corrected close view](corrections_v2/06-kai-art-close.png) ·
[Corrected return](corrections_v2/03-kai-art-return.png)

Initial transfer evidence retained for comparison: [v1 video](pilot.mp4) · [Idle](01-kai-art-idle.png) ·
[Walk](02-kai-art-walk.png) · [Return](03-kai-art-return.png) ·
[Real turn reference](04-mannequin-turn.png) · [Formal walk](05-formal-walk.png) ·
[Close view](06-kai-art-close.png)

## What is preserved

The exact original `assets/art/illustrated_pilot/kai/idle.png` supplies head
and torso. Head UV geometry and scale do not
change through the walk or return. The established mark-facing shader preserves
Kai's anatomical-left brow mark. No face or torso replacement is used. Accepted CP-2 attack/cast code and CP-4 mannequin code are unchanged.

The clean thigh/boot/foot/sleeve/cape textures already made during CP-3 are
reused as art only, with source hashes in
`assets/art/kai_motion_transfer/provenance.json`. Their original prompts and
raw outputs remain in `assets/source/illustrated_pilot/`. **CP-3's rejected
procedural gait/IK/phase code is not used.** A direct deformation of the whole
flat illustration was tried and discarded because legs and occluded parts
became distorted. Separated artwork is needed for independently moving limbs.

`KaiArtMotion` projects actual UAL thigh/knee/ankle/toe and arm joints into the
painted scene. Arms keep the illustration's rest registration, then follow the
source joint displacements. The corrected carrying forearm, closed hand, hilt, guard and blade stay
together at uniform scale, pointing forward/down from the index/thumb end.
This one targeted built-in ImageGen request uses original Kai, the approved
CP-4 grip and the existing sleeve as references. Raw transparent output, exact
prompt and hashes: `assets/source/kai_motion_corrections/`. Continuous navy
trouser cloth now spans the knee and ends inside calf-high boots, removing the
segmented knee-pad appearance. The painted support toe registers at the authored ball joint, with sole angle
from the source toe bones. It uses source animation, not a guessed foot path.

## What still needs art review

This answers whether the original identity can be retained in a source-driven
walk test. It does **not** establish a finished production walk. Judge the
moving result, particularly limb proportions/joins, carrying wrist, boot
registration and cape response. The head/torso are one preserved painted view;
clothing volume, hidden limb artwork, occlusion and directional poses need a
proper drawn rig/asset pass. A single PNG cannot supply unseen sides. Do not
scale this experiment to the cast or restart CP-3's procedural tuning loop on
the strength of green tests.

The rejected generic model is disabled in `../cp5_model_rejected/`; it is not
loaded by this scene or either accepted pilot. Campaign/math/save/canon remain
unchanged. The first transfer reused existing art; the grip correction uses
one built-in ImageGen request. No purchase or account was needed.

## Walk styles verified

The installed UAL1 Standard GLB contains 43 clips. Its everyday walks are
**Walk / normal** and **Walk_Formal**, with jog, sprint and crouch as separate
locomotion. Both root-motion companion loops measure **1.3m / 1.333333s**.
The creator's [UAL1 catalog](https://quaternius.com/packs/universalanimationlibrary.html)
and [UAL2 catalog](https://quaternius.com/packs/universalanimationlibrary2.html)
show the wider animation collection. UAL2 Standard's published list includes
Walk_Carry and Zombie_Walk_Fwd; those files are not installed. Extra clips can
be retargeted to a compatible rig, but the installed two walks do not provide
22 distinct everyday personality walks. Assignments should be reviewed per
character after Kai's artwork/motion method is accepted.

## Verification and reproduction

**546/546 tests pass, 3,385 assertions.** Four CP-5 tests preserve the original
head texture/UV geometry/scale, sample actual support contact cancelling travel
within one screen pixel, verify comparison/real-turn fallback without
Campaign changes, and sample actual steel/hilt pixels to check forward/down
blade direction in both facings. Current logs are in `corrections_v2/`. Tests establish mechanics, not visual acceptance. The suite
retains its inherited 13 deprecations and two object/one resource exit reports.

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp5-art-corrected.avi \
  -s assets/art_review/cp5_art_transfer/corrections_v2/capture.gd
```

The capture needs a real renderer. It writes screenshots to
`/tmp/vael-cp5-art-corrected-captures/`; encode its AVI with ffmpeg as in the CP-4 README.
