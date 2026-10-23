extends SceneTree
## GH-81: fresh-process Title/Journal callbacks must load visits and enter campus.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign: Node = root.get_node("Campaign")
	var route: String = OS.get_cmdline_user_args()[0]
	var saves := SaveSystem.new("user://academy_visit_callbacks_" + route)
	campaign.reset_new_game(false, 81)
	campaign.week = 2
	campaign.house_locked = true
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var castle: Node = load("res://scenes/castle/castle.tscn").instantiate()
	host.add_child(castle)
	castle.enter_room("entrance")
	if campaign.academy_visits != ["campus", "entrance"] or not campaign.save_to_slot(0, saves):
		quit(1)
		return
	var bytes := FileAccess.get_file_as_bytes(saves.slot_path(0))
	castle.free()
	campaign.reset_new_game(false)
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
		ui._sys_i = 3
		ui._activate()
	await process_frame
	await process_frame
	await process_frame
	if current_scene == null or current_scene.get_script() != load("res://src/castle/castle_scene.gd") \
			or current_scene.room.id != "campus" or campaign.academy_visits != ["campus", "entrance"] \
			or bytes != FileAccess.get_file_as_bytes(saves.slot_path(0)):
		printerr("Academy visit callback failed: " + route)
		quit(1)
		return
	DirAccess.remove_absolute(saves.slot_path(0))
	DirAccess.remove_absolute(saves.save_dir)
	print("Academy visit callback: %s passed" % route)
	quit(0)
