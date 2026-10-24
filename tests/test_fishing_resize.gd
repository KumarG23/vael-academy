extends GutTest
## GH-127: the production fishing cast remains visible through live viewport
## resizing without changing its state, timing, RNG, result, or castle cleanup.

var _viewport: SubViewport
var _game: FishingGame
var _scratch_saves: SaveSystem


func before_each() -> void:
	Campaign.reset_new_game(false, 127)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_game = FishingGame.new(127)
	_viewport.add_child(_game)
	await wait_process_frames(2)
	_game.set_process(false) # resize assertions isolate layout from normal cast time


func after_each() -> void:
	Campaign.reset_new_game(false)
	if _scratch_saves != null:
		for path in [_scratch_saves.slot_path(0), _scratch_saves.autosave_path()]:
			var absolute := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(absolute)
			if FileAccess.file_exists(path + ".tmp"):
				DirAccess.remove_absolute(absolute + ".tmp")
		var saves_dir := ProjectSettings.globalize_path(_scratch_saves.save_dir)
		if DirAccess.dir_exists_absolute(saves_dir):
			DirAccess.remove_absolute(saves_dir)
		_scratch_saves = null


func _resize(size: Vector2i) -> void:
	_viewport.size = size
	await wait_process_frames(2)


func _assert_visible_geometry(label: String) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var bob := _game._bobber_position()
	var line_start := Vector2(_game._bob_x - 90.0, _game._water_y - 120.0)
	assert_true(view.has_point(line_start), "%s: fishing line starts inside viewport" % label)
	assert_true(view.has_point(bob + Vector2(-7.0, -7.0)) and view.has_point(bob + Vector2(7.0, 7.0)),
		"%s: complete bobber stays inside viewport" % label)
	assert_true(view.has_point(bob), "%s: fishing line reaches its visible bobber" % label)
	var hint_rect := _game._hint.get_global_rect()
	var hint_inset := float(_game._hint.get_theme_constant("outline_size")) + 2.0
	assert_true(Rect2(view.position + Vector2(hint_inset, hint_inset),
		view.size - Vector2(hint_inset * 2.0, hint_inset * 2.0)).encloses(hint_rect),
		"%s: complete strike hint control and outline stay inside viewport" % label)
	assert_eq(_game._hint.text, FishingGame.STRIKE_HINT, "%s: exact existing hint remains" % label)
	assert_eq(_game._hint.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"%s: hint remains click-through" % label)
	var hint_font := _game._hint.get_theme_font("font")
	assert_lte(hint_font.get_string_size(_game._hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_game._hint.get_theme_font_size("font_size")).x, _game._hint.size.x + 0.5,
		"%s: complete strike hint text fits its active font bounds" % label)
	if _game.phase == FishingGame.Phase.BITE:
		var marker_rect := _game._label.get_global_rect()
		var marker_inset := float(_game._label.get_theme_constant("outline_size")) + 2.0
		assert_true(Rect2(view.position + Vector2(marker_inset, marker_inset),
			view.size - Vector2(marker_inset * 2.0, marker_inset * 2.0)).encloses(marker_rect),
			"%s: complete bite marker control and outline stay inside viewport" % label)
		assert_eq(_game._label.position, bob + FishingGame.MARKER_OFFSET,
			"%s: marker remains pinned to current bobber sway" % label)
		assert_eq(_game._label.text, "!", "%s: existing bite marker remains" % label)
		assert_eq(_game._label.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s: marker remains click-through" % label)
	assert_true(_game._hint.visible, "%s: hint remains visible during active cast" % label)


func _snapshot() -> Dictionary:
	return {
		"phase": _game.phase,
		"timer": _game._timer,
		"elapsed": _game._elapsed,
		"bite_at": _game._bite_at,
		"rng": _game._rng.state,
		"campaign": Campaign.to_dict().duplicate(true),
	}


func test_initial_and_live_resize_geometry_while_waiting_and_biting():
	var finished_count := [0]
	_game.finished.connect(func(_result: Dictionary) -> void: finished_count[0] += 1)
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		await _resize(size)
		_assert_visible_geometry("WAITING at %s" % size)
		assert_eq(finished_count[0], 0, "WAITING resize never emits completion")
	_game.tick(_game._bite_at)
	assert_eq(_game.phase, FishingGame.Phase.BITE, "deterministic fixture enters the real BITE phase")
	for size in [Vector2i(640, 360), Vector2i(800, 450), Vector2i(1280, 720), Vector2i(640, 360)]:
		await _resize(size)
		_assert_visible_geometry("BITE at %s" % size)
		assert_eq(finished_count[0], 0, "BITE resize never emits completion")
		var before := _game._elapsed
		_game.tick(0.05)
		assert_almost_eq(_game._elapsed - before, 0.05, 0.0001,
			"resize does not reset or extend the cast clock")
		assert_eq(_game.phase, FishingGame.Phase.BITE, "resize preserves the active bite window")


func test_resize_preserves_waiting_and_bite_state_and_local_rng():
	var waiting_before := _snapshot()
	await _resize(Vector2i(640, 360))
	assert_eq(_snapshot(), waiting_before, "WAITING resize preserves complete campaign, timer and RNG state")
	_game.tick(_game._bite_at * 0.5)
	var midway_waiting := _snapshot()
	await _resize(Vector2i(800, 450))
	assert_eq(_snapshot(), midway_waiting, "mid-cast resize preserves bite schedule and elapsed time")
	_game.tick(_game._bite_at - _game._timer)
	assert_eq(_game.phase, FishingGame.Phase.BITE)
	var bite_before := _snapshot()
	await _resize(Vector2i(1280, 720))
	assert_eq(_snapshot(), bite_before, "BITE resize preserves complete campaign, timer and RNG state")


func test_same_seed_has_same_result_with_and_without_resize_and_no_later_mutation():
	var baseline := FishingGame.new(8127)
	add_child_autofree(baseline)
	var baseline_results: Array[Dictionary] = []
	baseline.finished.connect(func(result: Dictionary) -> void: baseline_results.append(result))
	baseline.tick(5.0)
	baseline.tick(0.2)
	baseline.strike()
	var baseline_result := baseline._rng.state
	var baseline_log := Campaign.fish_log.duplicate(true)
	Campaign.fish_log = {}
	_game.queue_free()
	_game = FishingGame.new(8127)
	_viewport.add_child(_game)
	await wait_process_frames(1)
	_game.set_process(false)
	var resized_results: Array[Dictionary] = []
	_game.finished.connect(func(result: Dictionary) -> void: resized_results.append(result))
	_game.tick(5.0)
	_game.tick(0.2)
	await _resize(Vector2i(640, 360))
	await _resize(Vector2i(1280, 720))
	_game.strike()
	assert_eq(resized_results, baseline_results, "same seed and cast timing produce the same result")
	assert_eq(_game._rng.state, baseline_result, "resize does not consume catch-table RNG")
	assert_eq(Campaign.fish_log, baseline_log, "same seed yields the same one-catch result")
	var catch_count := 0
	for count in Campaign.fish_log.values():
		catch_count += int(count)
	assert_eq(catch_count, 1, "one successful cast increments the fish log exactly once")
	var done_state := _snapshot()
	_game.tick(10.0)
	assert_eq(_snapshot(), done_state, "finished cast cannot mutate state or award a second catch")


func test_resize_preserves_early_miss_and_the_existing_expiry_boundary():
	var early_results: Array[Dictionary] = []
	_game.finished.connect(func(result: Dictionary) -> void: early_results.append(result))
	_game.strike()
	assert_eq(early_results.size(), 1, "early strike resolves exactly once")
	assert_false(early_results[0].caught, "early strike remains a miss")
	var fish_after_early_miss := Campaign.fish_log.duplicate(true)
	await _resize(Vector2i(640, 360))
	_game.tick(5.0)
	assert_eq(early_results.size(), 1, "a finished early miss cannot emit again after resize")
	assert_eq(Campaign.fish_log, fish_after_early_miss, "early miss cannot grant a catch")

	_game = FishingGame.new(128)
	_viewport.add_child(_game)
	await wait_process_frames(1)
	_game.set_process(false)
	var expiry_results: Array[Dictionary] = []
	_game.finished.connect(func(result: Dictionary) -> void: expiry_results.append(result))
	_game.tick(_game._bite_at)
	_game.tick(FishingGame.BITE_WINDOW)
	assert_eq(_game.phase, FishingGame.Phase.BITE,
		"the pre-existing strict greater-than bite expiry boundary remains unchanged")
	var bite_timer := _game._timer
	var rng_state := _game._rng.state
	await _resize(Vector2i(800, 450))
	assert_eq(_game._timer, bite_timer, "resize leaves time remaining in the bite unchanged")
	assert_eq(_game._rng.state, rng_state, "resize does not consume local RNG")
	_game.tick(0.001)
	assert_eq(_game.phase, FishingGame.Phase.DONE, "the same bite expires just after 0.55 seconds")
	assert_eq(expiry_results.size(), 1, "expired bite emits one miss result")
	assert_false(expiry_results[0].caught, "expired bite remains a miss")


func test_resize_does_not_change_manual_autosave_or_settings_bytes():
	_scratch_saves = SaveSystem.new("user://gh127_fishing_resize_%d" % Time.get_ticks_usec())
	assert_true(_scratch_saves.save_slot(0, {"campaign": Campaign.to_dict()}), "seed disposable manual save")
	assert_true(_scratch_saves.save_autosave({"campaign": Campaign.to_dict()}), "seed disposable autosave")
	var paths := [
		_scratch_saves.slot_path(0), _scratch_saves.autosave_path(), AudioManager.prefs_path,
		DialoguePreferences.prefs_path, KeyboardPreferences.prefs_path,
	]
	var before := {}
	for path: String in paths:
		before[path] = _file_state(path)
	await _resize(Vector2i(640, 360))
	await _resize(Vector2i(800, 450))
	await _resize(Vector2i(1280, 720))
	for path: String in paths:
		assert_eq(_file_state(path), before[path], "%s bytes/presence remain unchanged by resize" % path.get_file())


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func test_dispatched_confirm_finishes_cast_and_castle_recovers_controls():
	var castle_viewport := SubViewport.new()
	castle_viewport.size = Vector2i(640, 360)
	castle_viewport.handle_input_locally = true
	add_child_autofree(castle_viewport)
	var castle := (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	castle_viewport.add_child(castle)
	await wait_process_frames(2)
	castle._start_fishing()
	var fishing: FishingGame = castle._fishing
	fishing.tick(fishing._bite_at)
	castle_viewport.size = Vector2i(1280, 720)
	await wait_process_frames(2)
	_tap_confirm_to(castle_viewport)
	assert_eq(fishing.phase, FishingGame.Phase.DONE, "existing confirm action resolves the bite")
	assert_true(fishing.is_queued_for_deletion(), "castle removes the finished fishing activity")
	assert_null(castle._fishing, "castle clears the active fishing reference")
	assert_false(castle.busy(), "castle restores exploration input after the ordinary result")


func _tap_confirm_to(viewport: SubViewport) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = pressed
		viewport.push_input(event, true)
