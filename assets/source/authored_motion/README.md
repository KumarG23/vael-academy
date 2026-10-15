# CP-4 authored-motion sources

This isolated motion proof reuses a licensed rig and artist-authored animation.
It renders the mannequin into a transparent viewport in the existing 2D painted
cloister. It does not establish Kai's finished model or a production style.

## Quaternius Universal Animation Library 1 — Standard

- Creator: Quaternius.
- Creator pages: https://quaternius.itch.io/universal-animation-library and
  https://quaternius.com/packs/universalanimationlibrary.html
- Original license and readme are retained in `quaternius/`: **CC0 1.0**.
- `UAL1_Standard.glb` is the original in-place mannequin/animation source, with
  65 bones. Runtime uses `Idle`, `Walk`, `Walk_Formal`, and right-finger rotations
  sampled from `Sword_Idle` at 0.3 seconds.
- Original downloaded Standard archive SHA256:
  `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724`.
- Installed GLB SHA256:
  `69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997`.
- The source root-motion companion's Walk_Loop traveled 1.2999999523 m over
  1.333333 seconds. CP-4 uses that measured stride to match in-place playback
  to 2D travel (~131.33 px/s at the pilot's normal scale). The unused companion
  is not installed; the source-stance regression test checks this measurement
  against the installed in-place animation.

Only runtime material overrides, the right-finger pose, a carrying-wrist tilt
of -35 degrees, and attached sword/left-head diagnostic marker are added. Walk
and turn behavior accepted by Neal is preserved; no gait keyframes are edited.

## KayKit Adventurers Character Pack 1.0 — sword reference only

- Creator: Kay Lousberg / KayKit.
- Source: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- Pinned revision: `672074b73ba276876a19e8816ecdc5241817ab47`.
- Original `Knight.glb`, texture and `LICENSE.txt` retained in `kaykit/`:
  **Creative Commons Zero (CC0)**.
- Original GLB SHA256:
  `60428e3abc09ba83e595d256e3af8c5c976b46cdae599f0802fc82b4a3445168`.
- `tools/build_reference_sword.gd` extracts only `1H_Sword` into
  `assets/art/authored_motion/reference_sword.glb`. Its SHA256 is
  `43c0863b267e2b39aa9968e9b4943b898fb127cb4afb04b12446439a3467896d`.
- Runtime scales the sword mesh by 0.5 and moves its handle center to the palm
  origin. A hand-local basis places the blade/guard at the index/thumb end and
  pommel at the little-finger end. The weapon follows `hand_r` via
  `BoneAttachment3D`.

Neal rejected the knight as a visual direction. It is not a selectable actor;
the original model is retained solely for sword provenance/reproduction.

## Reproduction

```sh
godot --headless --import
# Optional: rebuild the extracted reference sword from the retained source.
godot --headless -s tools/build_reference_sword.gd
godot --headless --import
godot res://scenes/proto/authored_motion_pilot.tscn
```

No purchase, credentials, new account or image-generation call is needed to run
or rebuild this proof. The existing CP-2 courtyard is reused, with its original
provenance in `assets/source/illustrated_pilot/`.
