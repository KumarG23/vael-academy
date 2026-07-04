extends GutTest
## WO-3.2: battle integration for support accrual, rank-up notification, support
## menu listing, and support-aware forecast numbers.

var _view: Node2D
var _rankups: Array = []


func before_each() -> void:
	_rankups = []
	EventBus.support_rank_up.connect(_on_support_rank_up)
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 97531
	add_child_autofree(_view)
	await wait_physics_frames(2)


func after_each() -> void:
	if EventBus.support_rank_up.is_connected(_on_support_rank_up):
		EventBus.support_rank_up.disconnect(_on_support_rank_up)


func _on_support_rank_up(pair_id: String, new_rank: String) -> void:
	_rankups.append("%s:%s" % [pair_id, new_rank])


func _wait_idle(max_frames := 400) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func _wait_action_at(cell: Vector2i) -> void:
	var unit: Unit = _view.unit_at(cell)
	assert_not_null(unit, "unit exists at %s" % cell)
	_view._on_cursor_confirmed(cell)
	_view._handle_selected_confirm(cell)
	await _wait_idle()
	var idx: int = _view._menu_actions.find("wait")
	assert_true(idx >= 0, "wait is offered")
	await _view._on_menu_chosen(idx)
	await _wait_idle()


func _unlock_kai_kael_c() -> void:
	await _wait_action_at(Vector2i(3, 7))  # Kael ends beside Kai: +10
	await _wait_action_at(Vector2i(2, 7))  # Kai ends beside Kael: +10 -> C


func test_kai_kael_reach_c_and_support_menu_lists_conversation():
	var kai: Unit = _view.unit_at(Vector2i(2, 7))
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	assert_not_null(kai, "Kai present for support fixture")
	assert_not_null(kael, "Kael present for support fixture")

	await _unlock_kai_kael_c()

	assert_eq(_view._support_state.rank_for_units("kai", "kael"), "C")
	assert_true(_rankups.has("kai_kael:C"), "rank-up signal emitted")

	kael.has_acted = false
	_view._on_cursor_confirmed(Vector2i(3, 7))
	_view._handle_selected_confirm(Vector2i(3, 7))
	await _wait_idle()
	assert_true(_view._menu_actions.has("supports"), "support command is listed after a conversation unlocks")


func test_c_rank_bonus_visibly_changes_forecast():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	assert_not_null(kael)
	assert_not_null(enemy)

	# Bring the test enemy adjacent so the forecast panel has real attack/counter values.
	enemy.cell = Vector2i(4, 7)
	enemy.position = _view._grid.cell_center(enemy.cell)

	_view._selected = kael
	_view._show_forecast_for(enemy)
	var base_hit := int(_view._forecast_panel._atk["hit"])
	var base_counter_hit := int(_view._forecast_panel._def["hit"])

	await _unlock_kai_kael_c()

	kael.has_acted = false
	_view._selected = kael
	_view._show_forecast_for(enemy)
	var boosted_hit := int(_view._forecast_panel._atk["hit"])
	var boosted_counter_hit := int(_view._forecast_panel._def["hit"])

	assert_eq(boosted_hit, base_hit + 5, "Kael's C support gives +5 hit")
	assert_eq(boosted_counter_hit, base_counter_hit - 5, "Kael's C support avoid lowers enemy counter hit")
