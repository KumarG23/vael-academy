extends GutTest
## WO-1.4: win/loss integration through battle_view — both outcomes reachable on
## the test map, plus lord-death defeat and rout/seize victory wiring.

var _view: Node2D
var _won := false


func before_each() -> void:
	_won = false
	EventBus.battle_won.connect(_on_battle_won)
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	add_child_autofree(_view)
	await wait_physics_frames(2)


func after_each() -> void:
	if EventBus.battle_won.is_connected(_on_battle_won):
		EventBus.battle_won.disconnect(_on_battle_won)


func _on_battle_won() -> void:
	_won = true


## Equip a sure-hit copy of the unit's weapon so a strike can't miss. Keeps the
## original might so only the 1-HP lord is a one-shot kill (inflating might would
## make everyone killable and change which target the AI prefers).
func _sure_hit(u: Unit) -> void:
	var cur := u.weapon()
	if cur == null:
		return
	var w := WeaponDef.new()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.weight = cur.weight
	w.min_range = cur.min_range
	w.max_range = cur.max_range
	u.equip_weapon(w)


func _wait_idle(max_frames := 4000) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func test_victory_by_seize_when_lord_reaches_the_tile():
	# Make the objective a nearby seize the lord can reach in one move.
	_view.chapter.objective = ChapterDef.Objective.SEIZE
	_view.chapter.seize_cell = Vector2i(2, 4)  # 3 north of Kai's (2,7)
	var kai: Unit = _view._lord_unit
	assert_true(kai.is_lord())
	assert_eq(kai.unit_id(), "kai", "Kai is the lord (§4, WO-4.1)")

	_view._on_cursor_confirmed(Vector2i(2, 7))    # select Kai
	_view._handle_selected_confirm(Vector2i(2, 4))  # move onto the seize tile
	await _wait_idle()
	var guard := 0
	while kai.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	# Finish the action via the command menu ("Wait"); the seize is checked then.
	var idx: int = _view._menu_actions.find("wait")
	await _view._on_menu_chosen(idx)

	assert_eq(kai.cell, Vector2i(2, 4))
	assert_true(_view._battle_over, "seizing ends the battle")
	assert_true(_won, "EventBus.battle_won emitted")
	assert_true(_view._result_screen.is_shown())


func test_victory_by_rout_when_all_enemies_fall():
	for enemy in _view._living_units_on_team(1).duplicate():
		_view._kill(enemy)
	_view._check_objective()
	assert_eq(_view._living_units_on_team(1).size(), 0)
	assert_true(_view._battle_over)
	assert_true(_won, "rout emits battle_won")


func test_defeat_when_the_lord_is_slain_in_the_enemy_phase():
	var kai: Unit = _view._lord_unit
	kai.current_hp = 1  # one counter/strike will finish him
	# Guarantee the blow lands despite any avoid bonus (support/camaraderie).
	for enemy in _view._living_units_on_team(1):
		_sure_hit(enemy)
	# Hand the turn to the enemy; the Aggressor prefers the guaranteed kill on the lord.
	_view._end_player_phase()
	await _wait_idle()

	assert_false(_view._lord_alive, "lord died")
	assert_true(_view._battle_over, "lord death is game over")
	assert_false(_won, "defeat does not emit battle_won")
	assert_true(_view._result_screen.is_shown())


func test_input_is_locked_after_the_battle_ends():
	for enemy in _view._living_units_on_team(1).duplicate():
		_view._kill(enemy)
	_view._check_objective()
	assert_true(_view._battle_over)
	# Selecting a unit should be ignored now.
	_view._on_cursor_confirmed(Vector2i(3, 7))
	assert_null(_view._selected, "no selection after the battle is over")
