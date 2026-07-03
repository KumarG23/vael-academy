extends GutTest
## WO-2.3: Sentinel / Boss AI and the threat overlay, through battle_view.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 111
	add_child_autofree(_view)
	await wait_physics_frames(2)
	# Keep everyone alive so the battle doesn't end mid-test.
	for u in _view._units:
		u.unit_def.max_hp = 9999
		u.current_hp = 9999


func _wait_idle(max_frames := 2000) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func test_boss_never_leaves_the_fort():
	var boss: Unit = _view.unit_at(Vector2i(16, 4))
	assert_not_null(boss, "boss on the fort")
	assert_eq(boss.ai_behavior(), AIBrain.Behavior.BOSS)
	for i in range(3):
		_view._end_player_phase()
		await _wait_idle()
	assert_eq(boss.cell, Vector2i(16, 4), "boss held the fort across three enemy phases")


func test_sentinel_sleeps_until_a_player_enters_its_threat():
	var sentinel: Unit = _view.unit_at(Vector2i(11, 8))
	assert_not_null(sentinel, "sentinel present")
	assert_eq(sentinel.ai_behavior(), AIBrain.Behavior.SENTINEL)
	assert_false(sentinel.ai_awake, "starts asleep")
	var start := sentinel.cell

	# No player is near it -> it holds and stays asleep.
	_view._end_player_phase()
	await _wait_idle()
	assert_eq(sentinel.cell, start, "asleep sentinel does not move")
	assert_false(sentinel.ai_awake)

	# Put the lord inside its threat range, then run another enemy phase.
	_view._lord_unit.cell = Vector2i(11, 11)
	_view._end_player_phase()
	await _wait_idle()
	assert_true(sentinel.ai_awake, "sentinel woke when a player entered its threat")
	assert_ne(sentinel.cell, start, "woken sentinel acts (moves in) like an aggressor")


func test_threat_overlay_toggles_and_populates_tiles():
	assert_false(_view._threat_overlay.is_shown(), "off by default")
	_view._toggle_threat_overlay()
	assert_true(_view._threat_overlay.is_shown())
	assert_gt(_view._threat_overlay._tiles.size(), 0, "shows some threatened tiles")
	_view._toggle_threat_overlay()
	assert_false(_view._threat_overlay.is_shown(), "toggles back off")
