The full pack: Combat FX has 22 hits: cross cuts, thrusts, spin attacks, flurries, bites,
dashes, chops, sword beams, whips, arrows, parries, guard breaks and ground smashes on top of
these, and every hit in white, red, gold, blue, purple and green. Same sheets, same player.
https://heyheythere.itch.io/combat-fx

sheets/256/    every effect at 256 px (thrusts, dashes, waves, whips and arrows 256x128)
sheets/128/    the same at half size
sheets/pixel/  pixel-art versions, drawn at 64 px (scale them up with nearest filtering)
previews/      an animated GIF of each effect
sheets/effects.json  for each sheet: frame size per set, frame count, columns, fps, and the
               anchor (0..1 across and down the frame: the point of a thrust or a whip, the hit
               on a block, where a dash stops, where a wave sets off, where an arrow sinks in, where a
               smash or a chop hits the ground, the centre of the rest)

Each sheet is a grid of frames, left to right then top to bottom, 8 to a row, on a transparent
background (straight alpha). Every effect plays once. Thrusts, dashes, waves, whips and arrows go
to the right, and blocks face a hit coming from the left: rotate them to the attack.

Godot 4.3+
    Copy addons/combat_fx/ into your project and sheets/ into addons/combat_fx/, then
        CombatFX.spawn(self, "red_slash", enemy.global_position)
        CombatFX.spawn(self, "white_thrust", enemy.global_position, (enemy.global_position - global_position).angle())
    Each frees itself when done. CombatFX.default_set = "pixel" (or "128") switches every spawn
    to that set; set CombatFX.sheets_dir if sheets/ is elsewhere. Open addons/combat_fx/demo/demo.tscn to try them
    all.

Unity
    Import a sheet, set Texture Type to Sprite (2D and UI), Sprite Mode to Multiple, then in the
    Sprite Editor: Slice > Grid By Cell Size with the frame size from effects.json (256x256 for
    most 256 sheets). Select the sprites in order and drag them into the scene to make the
    animation; set its sample rate to the fps and untick Loop Time. For the pixel set: Filter
    Mode Point, no compression.

GameMaker
    Create Sprite > Import > the sheet, then Convert to Frames with the frame size, 8 frames per
    row and the frame count from effects.json. Set the sprite's speed to the fps and its origin
    to the anchor.

Anything else
    Any engine or framework that cuts a grid sheet: use the frame size and count from
    effects.json.
