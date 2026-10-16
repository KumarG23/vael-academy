extends GutTest
## VS-1B: real PixelLab export, native anchors and cosmetic-only map playback.

func _fire() -> MapDecor:
	var chapter: ChapterDef = load("res://data/chapters/prologue.tres")
	for prop: MapDecor in chapter.decor:
		if prop.effect_frames != null:
			return prop
	return null


func test_export_frames_and_native_anchor_match_the_delivered_game_pack():
	var prop := _fire()
	assert_not_null(prop)
	assert_eq(prop.cell, Vector2i(11, 7), "existing burning house placement")
	assert_eq(prop.effect_offset, Vector2(-20, -86), "manifest offset, relative to bottom-center anchor")
	var frames := prop.effect_frames
	assert_eq(frames.get_frame_count("default"), 12)
	assert_eq(frames.get_animation_speed("default"), 10.0)
	assert_true(frames.get_animation_loop("default"))
	for i in range(12):
		var frame: AtlasTexture = frames.get_frame_texture("default", i)
		assert_eq(frame.region, Rect2((i % 4) * 40, (i / 4) * 59, 40, 59))
	assert_true((frames.get_frame_texture("default", 0) as AtlasTexture).atlas.get_image().detect_alpha() != Image.ALPHA_NONE,
		"effect-only sheet stays transparent; never bake the preview house over the live prop")


func test_clock_uses_exported_fps_and_loops_without_affecting_other_props():
	var prop := _fire()
	assert_eq(prop.effect_texture_at(0.0), prop.effect_frames.get_frame_texture("default", 0))
	assert_eq(prop.effect_texture_at(0.11), prop.effect_frames.get_frame_texture("default", 1))
	assert_eq(prop.effect_texture_at(1.11), prop.effect_frames.get_frame_texture("default", 11))
	assert_eq(prop.effect_texture_at(1.21), prop.effect_frames.get_frame_texture("default", 0))
	assert_eq(prop.effect_texture_at(3600.11), prop.effect_frames.get_frame_texture("default", 1))
	assert_null(MapDecor.new().effect_texture_at(0.0))
	var empty := MapDecor.new()
	empty.effect_frames = SpriteFrames.new()
	assert_null(empty.effect_texture_at(1.0), "empty optional animation cannot divide by zero")


func test_only_animated_maps_redraw_and_never_change_campaign_or_terrain():
	var tiles := TerrainTiles.new()
	add_child_autofree(tiles)
	var road: ChapterDef = load("res://data/chapters/prologue.tres")
	var state := Campaign.to_dict()
	var terrain := road.terrain.duplicate()
	tiles.setup(road.make_grid(), road)
	assert_true(tiles.is_processing())
	assert_eq(tiles.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	tiles._process(0.3)
	assert_eq(tiles._effect_time, 0.3)
	assert_eq(Campaign.to_dict(), state)
	assert_eq(road.terrain, terrain)
	var plain := ChapterDef.new()
	plain.width = 1
	plain.height = 1
	plain.terrain = PackedInt32Array([Terrain.Type.PLAINS])
	tiles.setup(plain.make_grid(), plain)
	assert_false(tiles.is_processing(), "maps without effects keep event-driven redraw")
	assert_eq(tiles._effect_time, 0.0, "new map starts its own cosmetic clock")
