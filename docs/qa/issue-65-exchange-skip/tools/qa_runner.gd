extends SceneTree
## GH-65 QA entry. QA_MODE=title: the ordinary Title scene (load a save normally).
## QA_MODE=illustrated: CP-8's documented rehearsal (assets/art_review/
## cp8_integration/preview.gd): the REAL Mock Battle with only Kai/Serra start
## cells (adjacent) and seed 1 changed; real menus, quote, XP, uses and yield.
## QA_MODE=popup: declared pixel-popup fixture (see below).
## All modes add the read-only reporter. Everything else is real input.


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func run() -> void:
	var reporter: Node = load("res://docs/qa/issue-65-exchange-skip/tools/qa_reporter.gd").new()
	reporter.out_path = OS.get_environment("QA_OUT")
	root.add_child(reporter)
	if OS.get_environment("QA_MODE") == "popup":
		# FIXTURE: no production scene opts into the pixel popup
		# (battle_popups_enabled defaults off). Real Mock Battle with the existing
		# export on and Kael/Osric (both kitted) adjacent; everything else real.
		var pview: Node = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
		pview.dialogue_enabled = false
		pview.combat_seed = 1
		pview.battle_popups_enabled = true
		root.add_child(pview)
		current_scene = pview
		for pair in [["kael", Vector2i(8, 10)], ["osric", Vector2i(9, 10)]]:
			var unit: Node = pview.unit_by_id(pair[0])
			unit.cell = pair[1]
			unit.position = pview._grid.cell_center(pair[1])
		pview._focus_player_start()
	elif OS.get_environment("QA_MODE") == "illustrated":
		var view: Node = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
		view.dialogue_enabled = false
		view.combat_seed = 1
		root.add_child(view)
		current_scene = view
		view.dialogue_enabled = true
		var kai: Node = view.unit_by_id("kai")
		var serra: Node = view._boss_unit
		kai.cell = Vector2i(8, 12)
		serra.cell = Vector2i(9, 12)
		kai.position = view._grid.cell_center(kai.cell)
		serra.position = view._grid.cell_center(serra.cell)
		view._focus_player_start()
	else:
		change_scene_to_file("res://scenes/title/title.tscn")
