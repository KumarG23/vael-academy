extends SceneTree
## GH-54: allow real deferred result transitions outside GUT's own scene.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign: Node = root.get_node("Campaign")
	var victory := OS.get_cmdline_user_args()[0] == "victory"
	campaign.reset_new_game(false)
	campaign.house_locked = true
	campaign.week = 6
	campaign.semester = 2
	campaign.flags["feast_seen"] = true  # Isolate result return from unrelated year-end dialogue.
	campaign.deploy()
	var view: Node = load("res://scenes/battle/closing_rite_emberwing.tscn").instantiate()
	view.dialogue_enabled = false
	root.add_child(view)
	current_scene = view
	view._end_battle(victory)
	var expected: Dictionary = campaign.to_dict().duplicate(true)
	view._end_battle(victory)
	# Actual result input callback, twice in the same frame; the second is inert.
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	view._result_screen._unhandled_key_input(key)
	view._result_screen._unhandled_key_input(key)
	await process_frame
	await process_frame
	await process_frame
	var target := "res://scenes/castle/castle.tscn" if victory else "res://scenes/title/title.tscn"
	if current_scene == null or current_scene.scene_file_path != target:
		push_error("Result route did not reach " + target)
		quit(1)
		return
	# GH-81: this fixture has never entered the academy before. Victory now
	# earns campus on actual entry; every other captured field must stay exact.
	if victory:
		expected["academy_visits"] = ["campus"]
	if campaign.to_dict() != expected:
		push_error("Result dismissal changed captured campaign/grades")
		quit(1)
		return
	if victory:
		if campaign.report_cards != [{"semester": 2, "rank": "B", "rank_name": "Accomplished", "score": 74}] or not campaign.grade_samples.battle_scores.is_empty():
			push_error("Closing result lost or duplicated its score")
			quit(1)
			return
	else:
		if campaign.week != 6 or campaign.semester != 2 or campaign.grade_samples.battle_scores != [30]:
			push_error("Defeat result lost score or advanced")
			quit(1)
			return
	print("Battle grade result: %s passed" % OS.get_cmdline_user_args()[0])
	quit(0)
