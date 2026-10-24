extends RefCounted
## Pure existing-chapter presentation shared by battle and the Journal.
## PackedScene inspection never instantiates a gameplay node or runs _ready.

static func objective_text(chapter: ChapterDef) -> String:
	match chapter.objective:
		ChapterDef.Objective.SEIZE:
			return "Objective: Seize the marked tile"
		ChapterDef.Objective.DEFEAT_BOSS:
			return "Objective: Defeat %s — or rout them all" % boss_display_name(chapter)
		_:
			return "Objective: Rout the enemy"

static func boss_display_name(chapter: ChapterDef) -> String:
	for spawn in chapter.enemy_spawns:
		if spawn != null and spawn.unit != null and spawn.unit.id == chapter.boss_unit_id:
			return spawn.unit.display_name
	return "the enemy commander"

static func chapter_from_path(path: String) -> ChapterDef:
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return chapter_from_scene(load(path) as PackedScene)

static func chapter_from_scene(scene: PackedScene) -> ChapterDef:
	if scene == null:
		return null
	var state := scene.get_state()
	var root_type := &""
	var root_script: Variant = null
	var root_chapter: Variant = null
	var found_script := false
	var found_chapter := false
	# Inherited scenes store only overrides. The first explicit property wins,
	# including explicit null; never search children for a plausible chapter.
	while state != null:
		if state.get_node_count() == 0 or state.get_node_path(0) != NodePath("."):
			return null
		if root_type == &"":
			root_type = state.get_node_type(0)
		for p in range(state.get_node_property_count(0)):
			var key := state.get_node_property_name(0, p)
			if key == &"script" and not found_script:
				root_script = state.get_node_property_value(0, p)
				found_script = true
			elif key == &"chapter" and not found_chapter:
				root_chapter = state.get_node_property_value(0, p)
				found_chapter = true
		state = state.get_base_scene_state()
	if root_type != &"Node2D" or not root_script is Script or not root_chapter is ChapterDef:
		return null
	var script := root_script as Script
	while script != null:
		if script.resource_path == "res://src/ui/battle_view.gd":
			return root_chapter as ChapterDef
		script = script.get_base_script()
	return null
