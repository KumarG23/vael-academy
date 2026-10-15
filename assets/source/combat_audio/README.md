# CP-8 combat audio

Five original synthesized cues, generated locally with `generate.py` (Python
standard library; deterministic seeds, 48 kHz mono PCM16). No third-party samples,
recordings, downloads, generation services or spend. These project-authored
assets add no third-party attribution requirements. Existing AW-36 hit/crit/miss,
victory, UI sounds and battle music remain unchanged.

| File in assets/audio/sfx | Trigger in illustrated combat |
|---|---|
| blade_whoosh.wav | Melee commitment, leading into contact |
| magic_gather.wav | Casting anticipation |
| magic_release.wav | Projectile launch |
| magic_impact.wav | Connected magical impact only |
| armor_drop.wav | Defeat pose after the upright lethal hit hold |

Cue names are in `data/presentation/illustrated_combat.json`; playback uses the
existing AudioManager voice pool, volume/mute controls, and cache. Hit/crit/miss
remain in the inherited contact pipeline and are not replayed by these hooks.
These are a reusable first sound pass, subject to Neal's listening review.

Neal's intended music resource is **Gemini / Google's Lyria**. Official sources
checked 2026-10-15: [Gemini music generation](https://ai.google.dev/gemini-api/docs/music-generation)
and [Lyria in Gemini](https://blog.google/innovation-and-ai/products/gemini-app/better-tracks-lyria-gemini/).
Use exported, reviewed tracks with AudioManager and existing per-room hooks;
do not add runtime music generation. No Lyria tool/API generation was invoked,
no access/credit entitlement was assumed, and no new music was imported in CP-8.
Keep source prompts, exports and generation provenance alongside future tracks.
