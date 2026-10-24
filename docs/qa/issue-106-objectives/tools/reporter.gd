extends Node
## Observer writes only QA output outside user://; never invokes game actions.

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var state := {"scene": str(scene.scene_file_path) if scene != null else "",
		"campaign": Campaign.to_dict(), "active": Campaign.active,
		"skip_reset": Campaign._skip_next_hub_reset,
		"next_prep": BattleView.next_prep,
		"viewport": [get_viewport().size.x, get_viewport().size.y]}
	if scene is CastleScene:
		var castle := scene as CastleScene
		state.merge({"room": castle.room.id, "busy": castle.busy(),
			"position": [castle._avatar.position.x, castle._avatar.position.y],
			"supports": castle._support_state.save_state(), "menu": castle._menu_context,
			"journal": castle._journal != null})
		if castle._journal != null:
			state["tab"] = castle._journal._tab
			if castle._journal._tab == 7:
				state["objectives"] = castle._journal.call("_objective_lines")
				state["layout"] = castle._journal.call("_objectives_layout", castle._journal._body_rect(), UITheme.font())
	var path := OS.get_environment("QA_OUT") + "/state.json"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
