The full pack: Spell FX has 22 spells in 7 elements: storm, holy, shadow and poison on top of
these three, and beams, breaths, volleys, drains, meteors, rains, eruptions, casts, novas,
pillars, ground areas, walls, whirlwinds, auras, wards, orbiting orbs, charge-ups, magic
circles, portals and teleports in every element. Same sheets, same player.
https://heyheythere.itch.io/spell-fx

sheets/256/    every effect at 256 px (bolts, beams, breaths, volleys, drains, walls,
               eruptions and ground areas 256x128, pillars, teleports and vortices 128x256)
sheets/128/    the same at half size
sheets/pixel/  pixel-art versions, drawn at 64 px (scale them up with nearest filtering)
previews/      an animated GIF of each effect
sheets/effects.json  for each sheet: frame size per set, frame count, columns, fps, whether it
               loops, and the anchor (0..1 across and down the frame: the feet of auras,
               wards, areas, walls, vortices, pillars, teleports, rains and meteors, the head
               of bolts, the hand of beams, breaths, volleys and drains, the caster's feet
               of eruptions)

Each sheet is a grid of frames, left to right then top to bottom, 8 to a row, on a transparent
background (straight alpha). Effects named *_bolt, *_beam, *_rain, *_aura, *_ward, *_area, *_rune,
*_portal, *_drain, *_wall, *_vortex, *_orbit and *_charge loop; the rest play once. Bolts, beams,
breaths, volleys (*_missiles) and drains face right: rotate them to their heading; an eruption
runs right along the ground: flip it to run left.

Godot 4.3+
    Copy addons/spell_fx/ into your project and sheets/ into addons/spell_fx/, then
        SpellFX.spawn(self, "fire_impact", enemy.global_position)
        SpellFX.fly(self, "ice", $Wand.global_position, target.global_position)
        var aura := SpellFX.spawn(player, "holy_aura", player.global_position)
        aura.finish()   # loops play until finish()
    SpellFX.default_set = "pixel" (or "128") switches every spawn to that set; set
    SpellFX.sheets_dir if sheets/ is elsewhere. Open addons/spell_fx/demo/demo.tscn to try them all.

Unity
    Import a sheet, set Texture Type to Sprite (2D and UI), Sprite Mode to Multiple, then in the
    Sprite Editor: Slice > Grid By Cell Size with the frame size from effects.json (256x256 for
    most 256 sheets). Select the sprites in order and drag them into the scene to make the
    animation; set its sample rate to the fps. For the pixel set: Filter Mode Point, no
    compression.

GameMaker
    Create Sprite > Import > the sheet, then Convert to Frames with the frame size, 8 frames per
    row and the frame count from effects.json. Set the sprite's speed to the fps and its origin
    to the anchor.

Anything else
    Any engine or framework that cuts a grid sheet: use the frame size and count from
    effects.json.
