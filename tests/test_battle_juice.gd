extends GutTest
## WO-2.5: the juice path runs end-to-end — a crit fires the clash splash and a
## kill dissolves the unit. Durations are shrunk so the timed path stays fast.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.01   # > 0 -> juice path active
	_view.battle_popups_enabled = false  # WO-4.9: this suite tests the map-strike juice path
	_view.combat_seed = 3
	add_child_autofree(_view)
	await wait_physics_frames(2)
	# Make every juice duration tiny so the real-time timed path finishes quickly.
	var c: JuiceConfig = _view._juice_config
	for f in ["lunge_time", "recoil_time", "hitstop_hit", "hitstop_crit", "hitstop_kill",
			"splash_in", "splash_hold", "splash_out", "dissolve_time", "number_time"]:
		c.set(f, 0.01)


func _wait_idle(max_frames := 1200) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1
	# Time scale must always be restored to 1 after any hit-stop.
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "hit-stop restored time_scale")


func _sure(u: Unit, crit: int) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.crit = crit
	w.weight = cur.weight
	w.min_range = 1
	w.max_range = 1
	u.equip_weapon(w)


func _move_attack(mover: Unit, dest: Vector2i, target_cell: Vector2i) -> void:
	_view._on_cursor_confirmed(mover.cell)
	_view._handle_selected_confirm(dest)
	await _wait_idle()
	var guard := 0
	while mover.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	await _view._on_menu_chosen(_view._menu_actions.find("attack"))
	# AW-26: Kael carries two physical weapons, so Attack opens a weapon picker;
	# the equipped weapon is index 0.
	if _view._menu_context in ["attack_weapon", "magic_spell"]:
		await _view._on_menu_chosen(0)
	_view._handle_targeting_confirm(target_cell)
	await _wait_idle()


func test_crit_fires_the_clash_splash():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	_sure(kael, 999)  # guaranteed crit
	assert_eq(_view._splash.plays, 0)
	await _move_attack(kael, Vector2i(5, 7), Vector2i(6, 7))
	assert_gt(_view._splash.plays, 0, "a crit slammed in the clash splash")


func test_kill_dissolves_and_removes_the_unit():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	_sure(kael, 0)
	enemy.current_hp = 1  # a single hit is lethal
	await _move_attack(kael, Vector2i(5, 7), Vector2i(6, 7))
	assert_null(_view.unit_at(Vector2i(6, 7)), "killed unit dissolved and was removed")
