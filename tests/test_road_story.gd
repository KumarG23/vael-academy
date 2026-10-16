extends GutTest
## VS-1B: real chapter VN → unchanged battle → bread aftermath → oath routing.

var _view: BattleView


func before_each() -> void:
	Campaign.reset_new_game(false)
	Campaign.active = true
	Campaign.flags = {"opening_started": true, "opening_complete": true, "kai_awakened": true}
	BattleView.next_resume = {}
	BattleView.next_prep = false
	_view = load("res://scenes/battle/prologue.tscn").instantiate()
	_view.strike_delay = 0.0
	add_child_autofree(_view)


func after_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}


func _dialogue(view: BattleView) -> DialogueScene:
	for node: Node in view.find_children("*", "", true, false):
		if node is DialogueScene and not node.is_finished():
			return node
	return null


func _read(view: BattleView) -> Array[String]:
	var d := _dialogue(view)
	var lines: Array[String] = []
	var guard: int = 0
	while d != null and not d.is_finished() and guard < 100:
		lines.append(d.current_line().text)
		d.skip_reveal()
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		d._unhandled_key_input(key)
		guard += 1
	assert_lt(guard, 100, "chapter dialogue finishes through its real input handler")
	return lines


func _win() -> void:
	var chief := _view.unit_by_id("bandit_boss")
	chief.set_hp(0)
	_view._kill(chief)
	_view._check_objective()


func test_rescue_finishes_before_player_controls_without_granting_magic():
	assert_true(_view._dialogue_playing)
	assert_false(_view._cursor.active)
	assert_false(Campaign.flags.has("road_intro_seen"))
	var e := InputEventAction.new()
	e.action = "cursor_confirm"
	e.pressed = true
	_view._cursor._unhandled_input(e)
	assert_null(_view._selected, "the opening cannot also select a map unit")
	var lines := _read(_view)
	assert_eq(lines.size(), DialogueScript.from_file(_view.chapter.intro_dialogue).size())
	assert_string_contains(lines[0], "hamlet well")
	assert_string_contains(lines[-1], "The child is safe")
	assert_true(Campaign.flags.get("road_intro_seen", false))
	assert_false(_view._dialogue_playing)
	assert_true(_view._cursor.active)
	assert_eq(Campaign.week, 1)
	assert_true(Campaign.flags.get("kai_awakened", false))
	assert_false(Campaign.flags.has("crownspark_unlocked"))
	assert_false(_view.unit_by_id("kai").can_use_weapon(load("res://data/weapons/crownspark.tres")))
	assert_false(Campaign.house_locked)
	assert_eq(_view._living_units_on_team(0).size(), 4, "escort is evacuating, not an extra fighter")


func test_bread_aftermath_plays_before_result_and_saved_result_continues_to_oath():
	_read(_view)
	_win()
	assert_true(_view._battle_victory)
	assert_true(_view._dialogue_playing)
	assert_false(_view._result_screen.is_shown(), "cannot dismiss result over the aftermath")
	assert_false(Campaign.flags.has("road_aftermath_seen"))
	var lines := _read(_view)
	assert_eq(lines.size(), DialogueScript.from_file(_view.chapter.outro_dialogue).size())
	assert_string_contains(lines[8], "Essa pressed into his hands")
	assert_string_contains(lines[11], "My mother would be furious")
	assert_string_contains(lines[24], "I’m Kai")
	assert_true(Campaign.flags.get("road_aftermath_seen", false))
	assert_true(_view._result_screen.is_shown())
	assert_eq(Campaign.week, 1)
	assert_false(Campaign.flags.has("crownspark_unlocked"))
	var sys := SaveSystem.new("user://test_road_story_%d" % Time.get_ticks_usec())
	_view._save_system = sys
	assert_true(_view.save_to_slot(0))
	Campaign.reset_new_game(false)
	var title := TitleScreen.new()
	autofree(title)
	assert_true(title.prepare_load(0, sys))
	assert_eq(title.next_campaign_scene(), TitleScreen.HOUSE_CHOICE_SCENE,
		"a completed-road result save must not replay the fight or bread")
	assert_eq(Campaign.week, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sys.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sys.save_dir))


func test_midroad_resume_skips_intro_keeps_flags_and_locks_old_equipped_magic():
	_read(_view)
	var kai := _view.unit_by_id("kai")
	# Simulate an old save's equipment order without granting story permission.
	for item: InventoryItem in kai.inventory.items:
		if item.is_weapon() and item.weapon().id == "crownspark":
			kai.inventory.equip(item)
			break
	kai.current_hp = 13
	var payload := _view.make_save_payload()
	assert_eq(Resume.stage(payload), TitleScreen.PROLOGUE_SCENE)
	var resumed: BattleView = load(TitleScreen.PROLOGUE_SCENE).instantiate()
	resumed.strike_delay = 0.0
	add_child_autofree(resumed)
	assert_false(resumed._dialogue_playing, "mid-battle load never repeats Hesta/rescue")
	assert_true(Campaign.flags.get("road_intro_seen", false))
	assert_false(Campaign.flags.has("road_aftermath_seen"))
	assert_false(Campaign.flags.has("crownspark_unlocked"))
	assert_eq(resumed.unit_by_id("kai").current_hp, 13)
	assert_eq(resumed.unit_by_id("kai").weapon().id, "sig_kai")
	assert_eq(resumed._rng.state_value(), _view._rng.state_value())
	assert_eq(BattleView.next_resume, {}, "one-time resume staging")


func test_defeat_does_not_play_success_aftermath_or_open_oath_route():
	_read(_view)
	var kai := _view.unit_by_id("kai")
	kai.set_hp(0)
	_view._kill(kai)
	_view._check_objective()
	assert_false(_view._battle_victory)
	assert_false(_view._dialogue_playing)
	assert_true(_view._result_screen.is_shown())
	assert_false(Campaign.flags.has("road_aftermath_seen"))
	assert_false(Campaign.flags.has("prologue_done"))
	assert_eq(Campaign.week, 1)


func test_clear_backdrop_restores_map_after_a_painted_still_or_black():
	var d := _dialogue(_view)
	d._set_backdrop("res://assets/art/vn/painted/forest_path.png")
	assert_not_null(d._backdrop_tex)
	d._set_backdrop("clear")
	assert_null(d._backdrop_tex)
	assert_eq(d._backdrop_flat.a, 0.0)


func test_optional_painted_hooks_parse_and_fall_back_without_missing_art_errors():
	var intro := DialogueScript.from_file(_view.chapter.intro_dialogue)
	var outro := DialogueScript.from_file(_view.chapter.outro_dialogue)
	assert_string_contains(intro.get_step(0).backdrop, "road_raid_well.png")
	assert_eq(intro.get_step(0).backdrop_fallback, "black")
	assert_string_contains(outro.get_step(8).backdrop, "road_bread_gift.png")
	assert_eq(outro.get_step(0).backdrop_fallback, "black")
	var d := _dialogue(_view)
	d._set_backdrop("res://missing_optional_painting.png", "clear")
	assert_null(d._backdrop_tex)
	assert_eq(d._backdrop_flat.a, 0.0, "live map remains usable until a still is supplied")
	d._set_backdrop("res://missing_optional_painting.png", "black")
	assert_eq(d._backdrop_flat.a, 1.0, "quiet bread beat has an intentional black stage")
