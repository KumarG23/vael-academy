extends GutTest
## WO-1.2: integration — a full player attack round with counter through battle_view,
## exercising forecast -> resolve -> HP update -> death -> EventBus on the test map.

var _view: Node2D
var _died: Array = []


func before_each() -> void:
	_died = []
	EventBus.unit_died.connect(_on_unit_died)
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0  # resolve strikes without wall-clock pauses
	_view.combat_seed = 12345  # deterministic combat rolls
	add_child_autofree(_view)
	await wait_physics_frames(2)


## Give a unit a sure-hit weapon so a specific strike/counter is guaranteed to land.
func _make_sure_hit(u: Unit) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.weight = cur.weight
	w.min_range = cur.min_range
	w.max_range = cur.max_range
	u.equip_weapon(w)


func after_each() -> void:
	if EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.disconnect(_on_unit_died)


func _on_unit_died(u: Unit) -> void:
	_died.append(u.unit_def.display_name)


func _wait_until_idle(max_frames := 240) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


## Move a unit to `dest`, wait for arrival, then pick a command-menu action by id.
func _move_and_pick(select: Vector2i, dest: Vector2i, action_id: String, mover: Unit) -> void:
	_view._on_cursor_confirmed(select)
	_view._handle_selected_confirm(dest)
	await _wait_until_idle()
	var guard := 0
	while mover.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	assert_eq(_view._phase, _view.Phase.MENU, "command menu opens after moving")
	var idx: int = _view._menu_actions.find(action_id)
	assert_true(idx >= 0, "menu offers '%s'" % action_id)
	await _view._on_menu_chosen(idx)


func test_full_player_attack_round_with_counter():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	assert_not_null(kael, "Kael present")
	assert_not_null(enemy, "enemy present")
	# Guarantee both the attack and the counter land, so the assertions aren't RNG-flaky.
	_make_sure_hit(kael)
	_make_sure_hit(enemy)
	var enemy_hp0 := enemy.current_hp
	var kael_hp0 := kael.current_hp

	# Select Kael, move adjacent to the enemy (land on (5,7)), choose Attack.
	await _move_and_pick(Vector2i(3, 7), Vector2i(5, 7), "attack", kael)
	assert_eq(kael.cell, Vector2i(5, 7), "Kael moved adjacent")
	assert_eq(_view._phase, _view.Phase.TARGETING, "attack -> targeting")
	assert_true(_view._targets.has(enemy), "enemy is targetable")

	# Confirm the attack on the enemy.
	_view._handle_targeting_confirm(Vector2i(6, 7))
	await _wait_until_idle()

	assert_lt(enemy.current_hp, enemy_hp0, "enemy took damage from Kael")
	# Enemy wields a lance and is at range 1 -> it counters (it survives Kael's hit:
	# 24 HP, sword can't one-round it here), so Kael should have taken counter damage.
	assert_true(enemy.is_alive(), "enemy survives one round (counter fires)")
	assert_lt(kael.current_hp, kael_hp0, "Kael took counter damage")
	assert_true(kael.has_acted, "Kael's action is spent")


func test_lethal_attack_removes_unit_and_emits_eventbus():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	# Weaken the enemy so Kael's strike is lethal; guarantee the strike lands.
	_make_sure_hit(kael)
	enemy.current_hp = 1

	await _move_and_pick(Vector2i(3, 7), Vector2i(5, 7), "attack", kael)
	_view._handle_targeting_confirm(Vector2i(6, 7))
	await _wait_until_idle()

	assert_null(_view.unit_at(Vector2i(6, 7)), "dead enemy removed from the board")
	assert_true(_died.has("Tidemark Soldier"), "EventBus.unit_died emitted")
	assert_eq(kael.current_hp, kael.max_hp(), "no counter from a slain enemy")
