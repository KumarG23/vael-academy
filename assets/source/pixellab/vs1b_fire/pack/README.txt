PixelLab VFX Creator: an effect in pieces for a game engine.

manifest.json says what each clip is. Every clip is a spritesheet (frames left to right,
top to bottom, each frame.w x frame.h px) with exact pixels: scale it by whole numbers
only, with nearest-neighbour filtering.

Placing a clip: draw frame i at anchor + offset (+ moves[i] when the clip has moves).
The anchor is a point on your character (its feet) or the effect's origin; "anchor" in
the manifest gives it on the effect's canvas. A clip starts on the effect's frame
start_frame and plays at fps; loop says whether it repeats.

- whole: the effect without the character.
- whole-with-sprite: the effect with the character in it, as made.
- behind / front: draw behind, then your own character, then front.
- part-<id>: one piece of the effect each (role: cast, projectile, impact, linger,
  ambient). A part that travels comes out in place: move it in code, or follow moves.
