extends SceneTree
## VS-1B.5: repeatable cosmetic-only dressing; original forces/terrain untouched.
const DIR := "res://assets/art/pixellab/props/"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var chapter: Resource = load("res://data/chapters/prologue.tres")
	# Idempotent: owned props use the road_raid directory, edge flames have an
	# explicit resource_name. Existing cottage and its approved VFX stay intact.
	var keep: Array = []
	for prop: Resource in chapter.decor:
		if prop.resource_name.begins_with("VS1B5_"):
			continue
		keep.append(prop)
	chapter.decor.assign(keep)
	# Keep the original cart anchor: it is the bandit's occupied spawn cell.
	# Reduced offset puts its wreck beside him, never over his head or health bar.
	for prop: Resource in chapter.decor:
		if prop.cell == Vector2i(7, 3):
			prop.texture = load(DIR + "road_raid/cart_overturned.png")
			prop.offset = Vector2(-72, 32)
	var ground := add(chapter, "square_ground", Vector2i(7, 10), "ground")
	ground.offset = Vector2(64, 0) # 512-native-wide dressing aligns to map origin
	ground.ground_layer = true
	# Edge buildings sit on existing impassable mountain border, never in a lane.
	var west := add(chapter, "house_burning", Vector2i(0, 2), "west_fire", false)
	west.effect_frames = load("res://data/vfx/road_cottage_fire.tres")
	west.effect_offset = Vector2(-20, -86)
	var east := add(chapter, "house_scorched", Vector2i(15, 9), "east_smoke")
	east.effect_frames = smoke_frames()
	east.effect_offset = Vector2(-6, -70)
	add(chapter, "house_b", Vector2i(1, 1), "west_edge", false)
	add(chapter, "house_a", Vector2i(15, 3), "east_edge", false)
	var stall := add(chapter, "stall_damaged", Vector2i(12, 6), "market")
	stall.offset = Vector2(32, 16)
	assert(ResourceSaver.save(chapter, "res://data/chapters/prologue.tres") == OK)
	print("Built road dressing; same terrain, 4 allies, 5 foes, visits/objective/dialogue")
	quit()

func add(chapter: Resource, art: String, cell: Vector2i, label: String, own: bool = true) -> Resource:
	var prop: Resource = load("res://src/core/map_decor.gd").new()
	prop.resource_name = "VS1B5_" + label
	prop.texture = load(DIR + ("road_raid/" if own else "") + art + ".png")
	prop.cell = cell
	chapter.decor.append(prop)
	return prop

func smoke_frames() -> SpriteFrames:
	# Reuse the accepted PixelLab pack's effect-only smoke at native resolution.
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 10.0)
	frames.set_animation_loop("default", true)
	var tex: Texture2D = load("res://assets/art/pixellab/vfx/road_cottage_fire/part-smoke.png")
	for i in range(12):
		var frame := AtlasTexture.new()
		frame.atlas = tex
		frame.region = Rect2((i % 4) * 7, (i / 4) * 20, 7, 20)
		frames.add_frame("default", frame)
	assert(ResourceSaver.save(frames, "res://data/vfx/road_cottage_smoke.tres") == OK)
	frames.take_over_path("res://data/vfx/road_cottage_smoke.tres")
	return frames
