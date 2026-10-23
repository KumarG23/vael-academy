extends SceneTree
## Issue #83: verify the unchanged SUCCESS routes for the two load entry points
## in a child process, because their deferred scene changes must not replace
## GUT's own running scene. Failure feedback is covered in-process by
## tests/test_load_failure_feedback.gd.
##
## Routes:
##   title-campaign  — Title Load -> campaign -> house choice (prologue done)
##   journal-battle  — Journal System -> live-battle slot -> mock battle resume


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var route: String = OS.get_cmdline_user_args()[0]
	var saves: SaveSystem = SaveSystem.new("user://test_load_feedback_flow_%s_%d" % [
		route, Time.get_ticks_usec()])
	var campaign: Node = root.get_node("Campaign")
	campaign.reset_new_game(true, 17)
	campaign.set_house("emberwing")
	campaign.week = 2
	campaign.flags = {"prologue_done": true}
	campaign.house_locked = false
	var payload := {}
	if route == "journal-battle":
		# Build a real battle snapshot through the production scene, then let
		# the Title/Journal load route walk back into it.
		var view: Node2D = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
		view.dialogue_enabled = false
		root.add_child(view)
		await process_frame
		await process_frame
		payload = view.make_save_payload()
		view.queue_free()
		await process_frame
	else:
		payload = {"campaign": campaign.to_dict()}
	if not saves.save_slot(0, payload):
		printerr("Load feedback flow: could not seed slot")
		quit(1)
		return

	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var ui: Control
	if route.begins_with("title"):
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

	for _i in range(12):
		await process_frame
	var expected := "res://scenes/flow/house_choice.tscn" if route.ends_with("campaign") \
		else "res://scenes/battle/mock_battle.tscn"
	var actual := "" if current_scene == null else current_scene.scene_file_path
	if actual != expected:
		printerr("Load feedback flow: %s routed to %s, expected %s" % [route, actual, expected])
		quit(1)
		return
	if route == "journal-battle":
		var battle_script: Script = load("res://src/ui/battle_view.gd")
		if not (battle_script.next_resume as Dictionary).is_empty():
			printerr("Load feedback flow: resumed battle payload was not consumed")
			quit(1)
			return
	var dir := DirAccess.open(saves.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))
	print("Load feedback flow: %s passed" % route)
	quit(0)
