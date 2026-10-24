extends GutTest
## GH-118: the production BattleView hover row follows Unit.current_class(),
## including a promoted class restored through the existing battle snapshot.

const PROMOTED_IDS := ["kai", "kael", "brenna", "wren", "dain", "liora", "perrin", "serra_prologue", "rina"]

var _vp: SubViewport
var _view: BattleView
var _previous_save_override: SaveSystem
var _previous_audio_path: String
var _test_save_system: SaveSystem
var _test_settings_path: String


func before_each() -> void:
	_previous_save_override = Campaign.save_system_override
	_previous_audio_path = AudioManager.prefs_path
	_test_save_system = SaveSystem.new("user://gh118_saves_%d" % Time.get_ticks_usec())
	Campaign.save_system_override = _test_save_system
	_test_settings_path = "user://gh118_settings_%d.cfg" % Time.get_ticks_usec()
	AudioManager.prefs_path = _test_settings_path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_save_system.save_dir))
	var save_file := FileAccess.open(_test_save_system.autosave_path(), FileAccess.WRITE)
	save_file.store_buffer(PackedByteArray([71, 72, 49, 49, 56]))
	save_file.close()
	var settings_file := FileAccess.open(_test_settings_path, FileAccess.WRITE)
	settings_file.store_buffer(PackedByteArray([83, 69, 84, 84, 73, 78, 71, 83]))
	settings_file.close()
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.handle_input_locally = true
	add_child_autofree(_vp)
	_view = load("res://scenes/battle/battle.tscn").instantiate()
	_view.strike_delay = 0.0
	_vp.add_child(_view)
	await wait_physics_frames(3)


func after_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	Campaign.save_system_override = _previous_save_override
	AudioManager.prefs_path = _previous_audio_path
	for path in [_test_save_system.autosave_path(), _test_settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save_system.save_dir))


func _hover_text(unit: Unit) -> String:
	_view._update_hover_info(unit.cell)
	return _view._hover_class_level_text(_view._hover_unit)


func test_base_and_promoted_brenna_hover_use_live_class_and_match_stats() -> void:
	var brenna: Unit = _view.unit_by_id("brenna")
	assert_eq(_hover_text(brenna), "Knight   Lv 1", "base-class hover string consumed by renderer")
	assert_eq(brenna.current_class().display_name, "Knight")

	brenna.level = Promotion.MIN_LEVEL
	var promotion := brenna.promote()
	assert_eq(promotion.get("class_name"), "Bastion", "supplementary fixture uses the existing promotion API")
	_view._stats_panel.show_unit(brenna)
	assert_true(_view._stats_panel._subtitle.begins_with("Bastion   Lv 1"), "existing Stats sheet displays promoted class")
	assert_eq(_hover_text(brenna), "Bastion   Lv 1", "promoted class/level string consumed by hover renderer")


func test_promoted_brenna_battle_snapshot_restores_hover_class_and_inspection_read_only() -> void:
	var brenna: Unit = _view.unit_by_id("brenna")
	brenna.level = Promotion.MIN_LEVEL
	brenna.promote()
	var snapshot := _view.make_save_payload()
	var campaign_before := Campaign.to_dict().duplicate(true)
	var autosave_before := FileAccess.get_file_as_bytes(_test_save_system.autosave_path())
	var settings_before := FileAccess.get_file_as_bytes(_test_settings_path)
	var restored_view: BattleView = load("res://scenes/battle/battle.tscn").instantiate()
	_vp.add_child(restored_view)
	await wait_physics_frames(3)
	assert_true(restored_view.apply_save_payload(snapshot), "existing battle snapshot path restores the fixture")
	var restored: Unit = restored_view.unit_by_id("brenna")
	assert_not_null(restored)
	assert_eq(restored.current_class().display_name, "Bastion")
	restored_view._update_hover_info(restored.cell)
	assert_eq(restored_view._hover_class_level_text(restored_view._hover_unit), "Bastion   Lv 1",
		"restored promoted class/level string consumed by production hover renderer")
	restored_view._stats_panel.show_unit(restored)
	assert_true(restored_view._stats_panel._subtitle.begins_with("Bastion   Lv 1"))
	assert_eq(restored_view.make_save_payload(), snapshot, "hover/inspection preserve the complete battle payload")
	assert_eq(Campaign.to_dict(), campaign_before, "hover/inspection preserve campaign progression/support state")
	assert_eq(FileAccess.get_file_as_bytes(_test_save_system.autosave_path()), autosave_before, "hover/inspection preserve isolated autosave bytes")
	assert_eq(FileAccess.get_file_as_bytes(_test_settings_path), settings_before, "hover/inspection preserve isolated settings bytes")


func test_all_shipped_promoted_class_level_strings_fit_hover_at_reference_sizes_and_live_resize() -> void:
	var font := UITheme.font()
	for dim in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_vp.size = dim
		await wait_physics_frames(3)
		for id in PROMOTED_IDS:
			var def: UnitDef = load("res://data/units/%s.tres" % id)
			var unit := Unit.new()
			unit.unit_def = def
			unit.level = 20
			unit._class_override = def.promotion_class
			var text: String = _view._hover_class_level_text(unit)
			assert_lte(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 206.0,
				"active-font class/level row fits the 206px hover text column: %s at %s" % [text, dim])
			assert_true(Rect2(Vector2.ZERO, Vector2(dim)).encloses(_view._hover_info.get_global_rect()),
				"hover remains in viewport after resize: %s" % dim)
			unit.free()


func test_missing_current_class_keeps_existing_safe_empty_name() -> void:
	var unit := Unit.new()
	unit.unit_def = null
	assert_eq(_view._hover_class_level_text(unit), "   Lv 1")
	unit.free()
