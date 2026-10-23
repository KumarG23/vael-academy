extends GutTest
## Issue #83: an occupied save slot the existing loader rejects must report a
## readable failure in the Title Load menu and the Journal System tab, without
## replacing live state, closing the UI or changing scenes.
##
## Every failure case below drives real key events through a SubViewport into
## the production TitleScreen/ChoiceMenu and AcademyJournal input paths. The
## success-routing checks run in a child process because their deferred scene
## change must not replace GUT's own running scene.

const TITLE_SCENE := "res://scenes/title/title.tscn"
const FLOW_FIXTURE := "res://tests/fixtures/load_feedback_flow.gd"


## Issue #83: test-only title that records the successful campaign handoff
## instead of changing the parent GUT scene. Everything else is production.
class TitleProbe extends TitleScreen:
	var entered := 0

	func _enter_campaign() -> void:
		entered += 1


var _viewport: SubViewport
var _saves: SaveSystem
var _title
var _journal


func before_each() -> void:
	_saves = SaveSystem.new("user://test_load_feedback_%d" % Time.get_ticks_usec())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_seed_live()


func after_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_remove_save_dir()


func _remove_save_dir() -> void:
	var dir := DirAccess.open(_saves.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.save_dir))


func _seed_live() -> void:
	Campaign.reset_new_game(true, 17)
	Campaign.set_house("tidemark")
	Campaign.house_locked = true
	Campaign.week = 3
	Campaign.flags = {"gold": 37, "prologue_done": true}
	Campaign.fish_log = {"Lakeperch": 2}
	Campaign.support_save = {"points": {"kai_kael": 20}}
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
	Campaign.training_used = true
	Campaign.grade_samples["quiz_scores"] = [75]
	Campaign.report_cards = [{"semester": 1}]
	Campaign.active = false
	Campaign._skip_next_hub_reset = false
	BattleView.next_resume = {"existing_resume": true}
	BattleView.next_prep = true
	CastleScene.next_room = "library"
	CastleScene.next_spawn = Vector2i(2, 3)


func _write_slot(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_saves.save_dir))
	var file := FileAccess.open(_saves.slot_path(slot), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _invalid_campaign_text() -> String:
	return JSON.stringify({"campaign": {
		"week": 2, "house_id": "emberwing", "flags": [],
	}})


func _valid_campaign_text() -> String:
	var saved := Campaign.to_dict()
	saved["week"] = 8
	saved["house_id"] = "thornrook"
	saved["flags"] = {"saved_flag": true}
	return JSON.stringify({"campaign": saved})


func _file_bytes(slot: int) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(_saves.slot_path(slot))


func _snapshot_state() -> Dictionary:
	return {
		"campaign": Campaign.to_dict(),
		"active": Campaign.active,
		"house": Roster.active_house,
		"skip_reset": Campaign._skip_next_hub_reset,
		"resume": BattleView.next_resume.duplicate(true),
		"prep": BattleView.next_prep,
		"room": CastleScene.next_room,
		"spawn": CastleScene.next_spawn,
	}


func _assert_state_unchanged(before: Dictionary, label: String) -> void:
	assert_eq(Campaign.to_dict(), before["campaign"], "%s: campaign and RNG unchanged" % label)
	assert_eq(Campaign.active, before["active"], "%s: campaign activity unchanged" % label)
	assert_eq(Roster.active_house, before["house"], "%s: house unchanged" % label)
	assert_eq(Campaign._skip_next_hub_reset, before["skip_reset"], "%s: load flag unchanged" % label)
	assert_eq(BattleView.next_resume, before["resume"], "%s: staged battle unchanged" % label)
	assert_eq(BattleView.next_prep, before["prep"], "%s: preparations unchanged" % label)
	assert_eq(CastleScene.next_room, before["room"], "%s: staged room unchanged" % label)
	assert_eq(CastleScene.next_spawn, before["spawn"], "%s: staged spawn unchanged" % label)


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_viewport.push_input(event, true)


func _open_title() -> TitleScreen:
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	_title._save_system = _saves
	_viewport.add_child(_title)
	await wait_frames(1)
	return _title

func _open_load_menu() -> void:
	_press(KEY_DOWN)  # main: New Game -> Load Game
	_press(KEY_ENTER)
	assert_eq(_title._context, "load", "the real main menu opens Load Game")
	assert_true(_title._menu.visible, "the Load menu is visible")


func _open_journal() -> AcademyJournal:
	_journal = (load("res://src/ui/academy_journal.gd") as Script).new()
	_journal._save = _saves
	_viewport.add_child(_journal)
	await wait_frames(1)
	for _i in range(4):
		_press(KEY_RIGHT)  # Roster -> Calendar -> Inventory -> Grades -> System
	assert_eq(_journal._tab, 4, "real input reaches the System tab")
	return _journal


func _select_system_row(row: int) -> void:
	assert_eq(_journal._tab, 4, "the System tab owns this selection")
	while _journal._sys_i != row:
		_press(KEY_DOWN)
	_press(KEY_ENTER)


# --- Title ------------------------------------------------------------------

func test_title_rejects_occupied_invalid_slots_and_keeps_the_menu_usable() -> void:
	_write_slot(0, "{broken")
	_write_slot(1, _invalid_campaign_text())
	var bytes := [_file_bytes(0), _file_bytes(1)]
	var before := _snapshot_state()
	await _open_title()
	await _open_load_menu()
	assert_eq(_title._slots.size(), 2, "both occupied files are listed")

	_press(KEY_ENTER)  # Slot 0
	assert_eq(_title._status, "Slot 0 couldn't be loaded — choose another slot.")
	assert_eq(_title._context, "load", "the Load menu stays open")
	assert_true(_title._menu.visible, "the menu is still usable")
	assert_eq(_title._slots.size(), 2, "the listing is unchanged")
	_assert_state_unchanged(before, "invalid JSON")
	await wait_frames(2)
	assert_true(is_instance_valid(_title) and _title.is_inside_tree(), "no scene change")
	assert_eq(_file_bytes(0), bytes[0], "the rejected file is untouched")
	assert_eq(_file_bytes(1), bytes[1], "the neighbor is untouched")

	_press(KEY_ENTER)  # retry the same slot
	assert_eq(_title._status, "Slot 0 couldn't be loaded — choose another slot.")
	assert_true(_title._menu.visible, "retry leaves the menu usable")

	_press(KEY_DOWN)
	_press(KEY_ENTER)  # Slot 1
	assert_eq(_title._status, "Slot 1 couldn't be loaded — choose another slot.")
	_assert_state_unchanged(before, "invalid campaign types")
	assert_eq(_file_bytes(0), bytes[0])
	assert_eq(_file_bytes(1), bytes[1])

	_press(KEY_ESCAPE)  # cancel back to the main menu
	assert_eq(_title._context, "main")
	assert_eq(_title._status, "", "ordinary navigation clears the stale failure")
	assert_true(_title._menu.visible, "the title remains usable")
	assert_true(_title.is_inside_tree(), "cancelling never changes scenes")


func test_title_reports_a_slot_that_disappears_after_listing() -> void:
	_write_slot(2, _valid_campaign_text())
	await _open_title()
	await _open_load_menu()
	assert_eq(int(_title._slots[0]["slot"]), 2, "the third physical slot is listed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.slot_path(2)))
	_press(KEY_ENTER)
	assert_eq(_title._status, "Slot 2 is empty.", "a vanished slot is reported truthfully")
	assert_eq(_title._context, "load")
	assert_true(_title._menu.visible)
	assert_true(_title.is_inside_tree())


func test_title_retry_after_repair_loads_and_clears_feedback() -> void:
	_write_slot(0, "{}")
	var title := TitleProbe.new()
	title._save_system = _saves
	_viewport.add_child(title)
	await wait_frames(1)
	title._open_load()
	title._choose_slot(0)
	assert_eq(title._status, "Slot 0 couldn't be loaded — choose another slot.")
	assert_eq(title.entered, 0, "a rejected load never enters the campaign")

	_write_slot(0, _valid_campaign_text())
	var bytes := _file_bytes(0)
	title._choose_slot(0)
	assert_eq(title.entered, 1, "the repaired slot takes the existing success route")
	assert_eq(title._status, "", "success clears the failure feedback")
	assert_eq(Campaign.week, 8, "the repaired campaign is live")
	assert_eq(Roster.active_house, "thornrook")
	assert_eq(_file_bytes(0), bytes, "loading never rewrites the source file")


func test_title_failure_feedback_fits_default_and_compact_layouts() -> void:
	_write_slot(0, "{broken")
	await _open_title()
	await _open_load_menu()
	_press(KEY_ENTER)
	var font := UITheme.font()
	_assert_title_status_readable(font, "1280×720")
	_viewport.size = Vector2i(640, 360)
	await wait_frames(1)
	_assert_title_status_readable(font, "640×360")


func _assert_title_status_readable(font: Font, label: String) -> void:
	var vp: Vector2 = _title.get_viewport_rect().size
	var rect: Rect2 = _title.status_rect()
	assert_true(rect.position.x >= 0.0 and rect.end.x <= vp.x,
		"%s: feedback %s stays inside the viewport width %s" % [label, rect, vp])
	assert_true(rect.position.y >= 0.0 and rect.end.y <= vp.y,
		"%s: feedback %s stays inside the viewport height %s" % [label, rect, vp])
	var measured := font.get_string_size(_title._status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	assert_lte(measured.x, rect.size.x - 32.0 + 0.5,
		"%s: measured text %.1f fits the feedback box %.1f" % [label, measured.x, rect.size.x])
	assert_false(rect.intersects(_title._menu.get_global_rect()),
		"%s: feedback %s does not cover the Load menu %s" % [label, rect, _title._menu.get_global_rect()])


# --- Journal ----------------------------------------------------------------

func test_journal_rejects_occupied_invalid_slots_and_stays_open() -> void:
	_write_slot(0, "{broken")
	_write_slot(1, _invalid_campaign_text())
	var bytes := [_file_bytes(0), _file_bytes(1)]
	var before := _snapshot_state()
	await _open_journal()

	_select_system_row(3)  # Load — Slot 1
	assert_eq(_journal._toast, "Slot 1 couldn't be loaded — choose another slot.")
	assert_eq(_journal._tab, 4, "the book stays on System")
	assert_true(_journal.is_inside_tree(), "the Journal stays open")
	_assert_state_unchanged(before, "Journal invalid JSON")
	assert_eq(_file_bytes(0), bytes[0], "the rejected file is untouched")
	assert_eq(_file_bytes(1), bytes[1], "the neighbor is untouched")

	_press(KEY_ENTER)  # retry the same row
	assert_eq(_journal._toast, "Slot 1 couldn't be loaded — choose another slot.")
	assert_true(_journal.is_inside_tree(), "retry leaves the book open")

	_press(KEY_DOWN)
	_press(KEY_ENTER)  # Load — Slot 2
	assert_eq(_journal._toast, "Slot 2 couldn't be loaded — choose another slot.")
	_assert_state_unchanged(before, "Journal invalid campaign types")
	assert_eq(_file_bytes(0), bytes[0])
	assert_eq(_file_bytes(1), bytes[1])

	_press(KEY_RIGHT)  # ordinary navigation to another tab
	assert_eq(_journal._tab, 5)
	assert_eq(_journal._toast, "", "stale rejection feedback is cleared on navigation")
	assert_true(_journal.is_inside_tree())

	_press(KEY_ESCAPE)  # cancel the book
	await wait_frames(1)
	assert_false(is_instance_valid(_journal) and _journal.is_inside_tree(),
		"Escape closes the Journal without a scene change")
	assert_eq(Campaign.to_dict(), before["campaign"])


func test_journal_reports_empty_invalid_and_missing_slots_truthfully() -> void:
	_write_slot(0, "{}")
	_write_slot(1, _valid_campaign_text())
	await _open_journal()
	_select_system_row(3)  # Load — Slot 1, an occupied file with no campaign
	assert_eq(_journal._toast, "Slot 1 couldn't be loaded — choose another slot.")
	assert_true(_journal.is_inside_tree())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.slot_path(1)))
	_select_system_row(4)  # Load — Slot 2, vanished after it was listed
	assert_eq(_journal._toast, "Slot 2 is empty", "missing slots keep their truthful message")
	assert_true(_journal.is_inside_tree())


func test_journal_live_battle_slot_with_invalid_campaign_is_rejected() -> void:
	var payload := {
		"campaign": {"week": 2, "house_id": "emberwing", "flags": []},
		"battle": {"chapter_id": "mock_battle", "battle_over": false},
		"roster": [],
	}
	_write_slot(0, JSON.stringify(payload))
	var before := _snapshot_state()
	await _open_journal()
	_select_system_row(3)
	assert_eq(_journal._toast, "Slot 1 couldn't be loaded — choose another slot.")
	assert_true(_journal.is_inside_tree())
	_assert_state_unchanged(before, "live-battle invalid campaign")
	assert_true(BattleView.next_resume.has("existing_resume"),
		"a rejected resume keeps the previously staged battle")


func test_journal_failure_feedback_fits_default_and_compact_books() -> void:
	_write_slot(0, "{broken")
	await _open_journal()
	_select_system_row(3)
	var font := UITheme.font()
	_assert_journal_toast_readable(font, "1280×720")
	_viewport.size = Vector2i(640, 360)
	await wait_frames(1)
	_assert_journal_toast_readable(font, "640×360")


func _assert_journal_toast_readable(font: Font, label: String) -> void:
	var vp: Vector2 = _journal.get_viewport_rect().size
	var rect: Rect2 = _journal._toast_rect()
	assert_true(rect.position.x >= 0.0 and rect.end.x <= vp.x,
		"%s: toast %s stays inside the viewport width %s" % [label, rect, vp])
	assert_true(rect.position.y >= 0.0 and rect.end.y <= vp.y,
		"%s: toast %s stays inside the viewport height %s" % [label, rect, vp])
	var measured := font.get_string_size(_journal._toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	assert_lte(measured.x, rect.size.x - 32.0 + 0.5,
		"%s: measured text %.1f fits the toast box %.1f" % [label, measured.x, rect.size.x])


# --- Success routing (child process, real deferred scene changes) -----------

func _check_flow(route: String) -> void:
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", FLOW_FIXTURE, "--", route,
	]), output, true)
	assert_eq(result, 0, "%s must keep the existing success route: %s" % [route, output])
	assert_string_contains(str(output), "Load feedback flow: %s passed" % route)
	assert_false(str(output).contains("SCRIPT ERROR"), "no runtime errors: %s" % output)


func test_successful_campaign_load_still_enters_the_campaign() -> void:
	_check_flow("title-campaign")


func test_live_battle_slot_still_resumes_into_the_battle() -> void:
	_check_flow("journal-battle")
