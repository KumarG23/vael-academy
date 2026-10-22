extends GutTest
## Opening callbacks must be inert after completion or failed preflight.

const HOME := "res://data/dialogue/prologue_home_morning.json"
const MISSING := "res://data/dialogue/missing_opening_lifecycle.json"


func before_each() -> void:
	Campaign.reset_new_game(true)
	Campaign.active = true
	Campaign.flags["existing_progress"] = true
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_completed_opening_ignores_late_event_and_finished_signals() -> void:
	var vn: PrologueVN = load("res://scenes/flow/opening.tscn").instantiate()
	vn.exit_scene = ""
	add_child_autofree(vn)
	vn._dialogue.typewriter_speed = 0.0
	var order: Array[int] = []
	var guard: int = 0
	while not vn._ended and guard < 400:
		if order.is_empty() or order[-1] != vn._i:
			order.append(vn._i)
		vn._dialogue.advance()
		guard += 1
	assert_lt(guard, 400, "authored playback completes without stalling")
	assert_eq(order, [0, 1, 2, 3, 4, 5, 6] as Array[int])
	assert_true(vn._ended)
	assert_true(Campaign.flags.get("kai_awakened", false))
	assert_true(Campaign.flags.get("opening_complete", false))
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	var script_index: int = vn._i
	var dialogue_index: int = vn._dialogue._index
	for _repeat in range(2):
		vn._dialogue.event_triggered.emit("set_flag", {"flag": "late_opening_callback"})
		vn._dialogue.finished.emit()
	assert_eq(Campaign.to_dict(), before, "late callbacks cannot change completed progress")
	assert_eq(Campaign.active, was_active)
	assert_eq(vn._i, script_index, "late completion cannot advance the sequence")
	assert_eq(vn._dialogue._index, dialogue_index, "late callbacks cannot move playback")
	assert_true(vn._ended)


func test_missing_first_script_callbacks_cannot_complete_opening() -> void:
	_assert_failed_preflight_ignores_callbacks([MISSING] as Array[String])


func test_missing_later_script_callbacks_cannot_start_partial_playback() -> void:
	_assert_failed_preflight_ignores_callbacks([HOME, MISSING] as Array[String])


func _assert_failed_preflight_ignores_callbacks(paths: Array[String]) -> void:
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	var vn := PrologueVN.new()
	vn.campaign_opening = true
	vn.exit_scene = ""
	vn.scripts = paths
	add_child_autofree(vn)
	assert_string_contains(vn.load_error, MISSING)
	assert_eq(vn._i, -1, "preflight fails before any playback")
	assert_null(vn._dialogue)
	assert_eq(Campaign.to_dict(), before, "preflight cannot write progress")
	var script_index: int = vn._i
	var ended: bool = vn._ended
	for _repeat in range(2):
		vn._on_dialogue_event("set_flag", {"flag": "failed_opening_callback"})
		vn._next_script()
	assert_eq(Campaign.to_dict(), before, "failed preflight makes all callbacks inert")
	assert_eq(Campaign.active, was_active)
	assert_eq(vn._i, script_index, "callbacks cannot advance a failed opening")
	assert_eq(vn._ended, ended, "callbacks cannot complete a failed opening")
	assert_null(vn._dialogue, "callbacks cannot start partial playback")
