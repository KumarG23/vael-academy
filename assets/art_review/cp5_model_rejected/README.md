# CP-5 — rejected generic 3D Kai assembly

**Neal rejected this model as unlike Kai. It is removed from runtime.**

The first CP-5 attempt combined Quaternius's free skinned head/hair, peasant
shirt and ranger trousers/boots, fitted to the unchanged accepted UAL skeleton.
Navy/gold/crimson material colors, simple collar/cravat/epaulettes/belt/cape and
a left-brow crown were added. Matching the palette and retaining animation did
not establish Kai's likeness. Neal's correction was to use the existing art.

The screenshots and `pilot.mp4` show that rejected attempt. Disabled `.gd.txt`,
`.gdshader.txt` and `.py.txt` files preserve the experiment; they are not runtime
scripts. `generated_model/` is the rejected export/build record. Original source
geometry/licenses are recorded in `assets/source/rigged_kai/README.md`. The
builder snapshot originally lived at `tools/build_kai_rig.py` and resolves
paths relative to that location; it is retained for traceability, not as an
active production tool. No purchase or new AI art call was made.

A 545-test run during this attempt checked mechanical binding and unchanged
animation, but **did not prove visual acceptance**. Those model-specific tests
were removed together with the runtime change. The current full suite tests
the separate original-art transfer proof instead. Do not resume or present this
generic assembly as an approved Kai model. The accepted mannequin and CP-2
art/attacks remain the references.
