extends SceneTree
## GH-85: a separate process consumes the existing checkpoint via Title input.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign: Node = root.get_node("Campaign")
	var saves := SaveSystem.new(OS.get_cmdline_user_args()[0])
	var expected := saves.load_autosave().get("campaign", {}) as Dictionary
	var bytes := FileAccess.get_file_as_bytes(saves.autosave_path())
	campaign.reset_new_game(true, 999)
	var title: Control = load("res://scenes/title/title.tscn").instantiate()
	title._save_system = saves
	root.add_child(title)
	current_scene = title
	title._open_load()
	# Last occupied entry is Autosave, regardless of sparse manual files.
	title._menu._index = title._slots.size() - 1
	var confirm := InputEventAction.new()
	confirm.action = "cursor_confirm"
	confirm.pressed = true
	title._menu._unhandled_input(confirm)
	await process_frame
	await process_frame
	await process_frame
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	if current_scene == null or current_scene.get_script() != load("res://src/castle/castle_scene.gd") \
			or normalized != expected or FileAccess.get_file_as_bytes(saves.autosave_path()) != bytes:
		printerr("Fresh Title autosave restore failed")
		quit(1)
		return
	# Continue through an ordinary room visit, which must not rewrite recovery.
	current_scene.enter_room("common_hall")
	if FileAccess.get_file_as_bytes(saves.autosave_path()) != bytes:
		quit(1)
		return
	print("Fresh Title autosave restore passed")
	quit(0)
