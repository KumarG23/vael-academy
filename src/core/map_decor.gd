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
## Flat dressing (dust, scorch, scattered goods) beneath upright scenery.
## Still cosmetic: never changes the cell's terrain or movement cost.
@export var ground_layer: bool = false

## Optional pixel-world overlay, exported from a VFX Creator game pack.
## Uniform default-animation frames, cosmetic only; no collision/RNG/save state.
@export var effect_frames: SpriteFrames
## Native sprite pixels relative to this prop's bottom-center (pack anchor).
@export var effect_offset: Vector2 = Vector2.ZERO


func effect_texture_at(seconds: float) -> Texture2D:
	if effect_frames == null or not effect_frames.has_animation("default"):
		return null
	var count: int = effect_frames.get_frame_count("default")
	var fps: float = effect_frames.get_animation_speed("default")
	if count == 0 or fps <= 0.0:
		return null
	var frame: int = int(floor(maxf(seconds, 0.0) * fps)) % count
	return effect_frames.get_frame_texture("default", frame)
