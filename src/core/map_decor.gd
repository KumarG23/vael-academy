class_name MapDecor
extends Resource
## One scenery prop placed on a chapter map (maps v3 — the Dark Deity density
## direction): a texture anchored to a cell. Purely visual; gameplay comes
## from the terrain underneath (author houses on WALL cells so they block,
## crates on PLAINS so they're walkable flavor, etc.).

@export var texture: Texture2D
## The prop's anchor cell: the image's bottom edge sits on this cell's bottom,
## horizontally centered. Multi-tile props overhang upward/sideways.
@export var cell: Vector2i = Vector2i.ZERO
## Extra pixel nudge after anchoring (art-fit tweaks).
@export var offset: Vector2 = Vector2.ZERO
