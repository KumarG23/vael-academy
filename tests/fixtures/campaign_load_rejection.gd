extends SceneTree
## Run UI load callbacks in a child process: a regressed deferred scene change
## must fail this probe without replacing GUT's own running scene.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# SceneTree scripts access autoloads after initialization through the root.
	var campaign: Node = root.get_node("Campaign")
	var battle_script: Script = load("res://src/ui/battle_view.gd")
	var castle_script: Script = load("res://src/castle/castle_scene.gd")
	var roster_script: Script = load("res://src/core/roster.gd")
	var route: String = OS.get_cmdline_user_args()[0]
	var saves: SaveSystem = SaveSystem.new("user://test_campaign_ui_rejection_%s" % route)
	for field: String in ["flags", "report_cards"]:
		campaign.reset_new_game(true, 17)
		campaign.set_house("tidemark")
		campaign.week = 3
		campaign.training_used = true
		campaign.set_unit_state("kai", {"level": 2, "xp": 17})
		battle_script.next_resume = {"existing_resume": true}
		battle_script.next_prep = true
		castle_script.next_room = "library"
		castle_script.next_spawn = Vector2i(2, 3)
		var before: Dictionary = campaign.to_dict()
		var saved: Dictionary = before.duplicate(true)
		saved["unit_states"] = {}
		saved["week"] = 8
		saved["house_id"] = "thornrook"
		saved[field] = [] if field == "flags" else {}
		if not saves.save_slot(0, {"campaign": saved}):
			quit(1)
			return
		var host := Node.new()
		root.add_child(host)
		current_scene = host
		var ui: Control
		if route == "title":
			ui = load("res://scenes/title/title.tscn").instantiate()
			ui._save_system = saves
			host.add_child(ui)
			ui._open_load()
			ui._choose_slot(0)
		else:
			ui = load("res://src/ui/academy_journal.gd").new()
			ui._save = saves
			host.add_child(ui)
			ui._tab = 4
			ui._sys_i = 3  # System -> Load Slot 1, through the real row activation
			ui._activate()
		# Give any queued production scene transition time to execute.
		await process_frame
		await process_frame
		await process_frame
		var checks: Dictionary = {
			"campaign": campaign.to_dict() == before,
			"house": roster_script.active_house == "tidemark",
			"active": campaign.active == false,
			"training_load": campaign._skip_next_hub_reset == false,
			"staged_battle": battle_script.next_resume == {"existing_resume": true},
			"preparations": battle_script.next_prep == true,
			"castle_room": castle_script.next_room == "library",
			"castle_spawn": castle_script.next_spawn == Vector2i(2, 3),
			"scene": is_instance_valid(host) and current_scene == host,
			"ui_open": is_instance_valid(ui) and ui.is_inside_tree(),
		}
		if is_instance_valid(ui) and route == "title":
			checks["load_menu"] = ui._context == "load" and ui._menu.visible
		for check: String in checks:
			if not checks[check]:
				printerr("Campaign UI rejection failed: %s / %s / %s" % [route, field, check])
				quit(1)
				return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
		current_scene = null
		host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))
	print("Campaign UI load rejection: %s passed" % route)
	quit(0)
