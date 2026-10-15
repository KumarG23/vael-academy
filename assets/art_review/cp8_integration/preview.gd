extends SceneTree
## Convenient local rehearsal of the REAL Mock Battle, not the CP-6 sandbox.
## Only start positions/seed and intro playback differ. Real menus/XP/uses/yield.


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func run() -> void:
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
