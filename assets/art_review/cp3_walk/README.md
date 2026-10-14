# CP-3 — rejected walk experiment, 2026-10-14

**Neal rejected this approach. The live pilot has been restored to CP-2. Walking remains unresolved.**

The first separated-art procedural rig read as injured walking and a backward sword hand. Centering each stride beneath its own hip, adjusting bone lengths to prevent hard knee locks, reducing clearance/bounce, and installing a painted closed-hand/sword assembly still failed Neal's visual review. He requested a different approach. Do not present this checkpoint as a solved walk or restart the same tuning loop.

[Rejected walk footage](rejected-walk.mp4) · [Facing/grip render](rejected-facing-proof.png) · [Restored suite](restored-suite-log.txt)

## What was tried

Four bounded Gemini image requests generated lower rig parts, upper rig parts, a plain-navy trouser cleanup and a right-hand/weapon assembly. The runner reads `VAEL_ART_API_KEY` directly from gitignored `.env`; no credential is exported or stored in artifacts. Exact prompts, reference hashes and raw outputs are in `assets/source/illustrated_pilot/kai_walk_*_layers*_gemini_sheet.{png,json}` and `kai_walk_grip_gemini_sheet.{png,json}`.

`rejected_layers/` preserves extracted transparent parts and rig.json. `tools/prepare_kai_walk_layers.py` reproduces that archive, with no live installation. The three `.gd.txt` files preserve disabled experiment code/tests; they are not runtime scripts or active tests.

The walk used distance-paced half-cycle-offset legs, heel/toe stance pivots, low swing clearance, IK knees, start/stop blending, opposing sleeves and cape sway. Its torso mesh used the exact approved idle texture. Facing reused the existing mark-only Crown shader. The closed carry assembly kept hand/hilt/guard together; mesh registration shortened the generated sleeve and extended the blade to match the character's scale. Those mechanisms did not produce a convincing walk/grip.

The experimental tree passed 544 tests (3,884 assertions), including contact cancellation, alternating support, phase continuity, no calf stretch/knee locks, preserved head geometry, closed carry binding and attack recovery. These checks demonstrate mechanical constraints, **not visual quality**. After rollback, the actual shipped tree passes **538/538 tests, 3,259 assertions, 79 scripts**. Existing 13 deprecations and two object/one resource exit reports match the prior baseline.

## Proposed different foundation

Use a consistently rigged character and an authored or motion-captured walk, with the weapon attached to a posed hand. Establish motion with an existing coherent model/animation first. Then test a cel-shaded Kai model against the approved illustration. Render the character from fixed views into transparent 2D sprites so the existing tactical game, painted backgrounds and combat logic can remain intact. Share the animation skeleton across compatible characters and add weapon/spell motions to that foundation.

This recommendation needs a real visual proof. A 3D rig is not an automatic guarantee of good animation, and creating a model that matches Kai is upfront art work. There are currently no `.blend`, `.glb`, `.gltf` or `.fbx` character/motion assets in this repo, and no local Blender executable was found. No external assets have been acquired, no services purchased, and no 3D gameplay migration authorized. An alternative for an exact drawn look is an animator-authored 2D cycle/proper deformation rig; another improvised cutout gait is not the proposed next step.

Verified Godot foundations: [humanoid animation retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html), [bone attachments](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html), [offscreen viewports](https://docs.godotengine.org/en/stable/classes/class_subviewport.html), and [toon shading](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). These establish technical feasibility; they do not establish the final art quality.

## Acceptance

| Requirement | Outcome |
|---|---|
| Natural walk and convincing weapon carry | **Failed Neal's review; OPEN** |
| Head scale and left-brow mark preserved | Preserved during experiment; existing CP-2 solution restored |
| Liked combat art, campaign/math/saves unchanged | Restored runtime byte-for-byte to green CP-2 |
| Sources, review evidence, handoff and tests | Archived; current tree 538/538 green |
| Expand spell/weapon attack presentation | Deferred until the animation foundation is settled |
