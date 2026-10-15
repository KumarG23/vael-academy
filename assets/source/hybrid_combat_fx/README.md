# CP-6 — Free HD effects: source, license and selection record

Verified directly on the creators' pages and in the downloaded license files,
2026-10-15. No purchase, login, account creation or paid generation.

| Candidate | Verified license / source | Evaluation and decision |
|---|---|---|
| Combat FX Free, heyheythere | [CC BY 4.0](https://heyheythere.itch.io/combat-fx-free), archive v1.1.0 | Import only 256px HD white slash, white hit and gold critical. Shapes work with illustrated silhouettes; tint and restrain size in Godot. Original Godot sheet player reused unchanged. |
| Spell FX Free, heyheythere | [CC BY 4.0](https://heyheythere.itch.io/spell-fx-free), archive v1.1.0 | Import only 256px arcane bolt + impact, remapped to Crown emerald with a white core. Original sheet player reused unchanged; Vael controls flight/contact so a miss never produces an impact. Fire/ice deferred. |
| VFX 2D Free, heyheythere | [CC BY 4.0](https://heyheythere.itch.io/vfx-2d-free) | Evaluated published shader demo/features. Explosion/smoke/fire are outside this duel's needs. Not imported; native rings, glints and timed sparks suffice. |
| Particle Pack, Kenney | [CC0](https://kenney.nl/assets/particle-pack), archive license says 1.1 | Import only transparent flare_01 and spark_01. Neutral textures are useful for glints, gathering motes and impact sparks with shared timing. |
| Pixel Magic Effects, Foozle / lordfitoi | [CC0](https://foozlecc.itch.io/pixel-magic-sprite-effects) | 32px pixel effects fit the world/pixel combat candidate, not the illustrated silhouettes. Existing A player already supplies pixel FX; nothing imported. |

CC0 is preferred for generic building blocks. The two CC BY packs provide
finished HD animation that the two neutral CC0 textures alone cannot replace.
No unrelated pack contents, demos, project settings or full paid packs imported.

`manifest.json` records selected source paths, file and archive SHA-256 hashes.
PNG pixels are unmodified. Runtime changes: sheet slicing, tint, scaling,
rotation and timing. Runtime effects.json files contain only installed entries;
the original metadata is retained under combat/ and spell/. Vendor documentation/license text and original metadata have
only line endings/trailing whitespace normalized. Original player scripts are
byte-for-byte copies under addons/hybrid_free_fx/; Vael configures their asset
paths through their documented sheets_dir setting.

## Required attribution

Combat FX Free by heyheythere - https://heyheythere.itch.io/combat-fx-free - CC BY 4.0

Spell FX Free by heyheythere - https://heyheythere.itch.io/spell-fx-free - CC BY 4.0

License: https://creativecommons.org/licenses/by/4.0/

Selected HD sheets tinted/scaled/animated in Godot; original pixels unchanged.
Filtered metadata; original player scripts unchanged. No creator endorsement.

Particle Pack by Kenney - https://kenney.nl/assets/particle-pack - CC0
https://creativecommons.org/publicdomain/zero/1.0/

Credits are included in the prototype's **Credits** dialog and short stage
footer. Retain this record and the pack licenses in any distribution containing
these assets. If moving the presenter into the full game, retain a visible
credits entry there too.

## Existing PixelLab candidate A

No new assets imported from PixelLab. Existing repo-owned generations remain
in assets/art/pixellab/{kai,serra}/, with original archives in
assets/source/pixellab/{kai_battle_pro,serra_battle_pro}/. See the CP-6 comparison
README for IDs, processing and usage costs. These are generated account assets,
not CC0 third-party pack files. PixelLab's current [terms](https://www.pixellab.ai/termsofservice)
permit use/modification/distribution of outputs (sections 1.3/3.3); they also
link an Open RAIL-M policy. No claim that the service itself is open-source or
that generated outputs are CC0.
