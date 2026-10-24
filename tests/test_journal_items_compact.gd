extends GutTest
## GH-114: existing Items hub content must remain measurable, readable and
## reachable in the production Journal SubViewport at supported compact sizes.

var _viewport: SubViewport
var _journal: AcademyJournal
var _keyboard_prefs_path := ""
var _test_keyboard_prefs_path := ""


func before_each() -> void:
	Campaign.reset_new_game(false)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = load("res://src/ui/academy_journal.gd").new()
	_journal._save = SaveSystem.new("user://test_journal_items_%d" % Time.get_ticks_usec())
	_journal._tab = 2
	_keyboard_prefs_path = KeyboardPreferences.prefs_path
	_test_keyboard_prefs_path = "user://test_journal_items_keys_%d.cfg" % Time.get_ticks_usec()
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.prefs_path = _test_keyboard_prefs_path
	_viewport.add_child(_journal)
	await wait_process_frames(1)


func after_each() -> void:
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.prefs_path = _keyboard_prefs_path
	KeyboardPreferences.load_preferences()
	for suffix in ["", ".tmp"]:
		var path := ProjectSettings.globalize_path(_test_keyboard_prefs_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Campaign.reset_new_game(false)


func _press_action(action: String, keycode := KEY_NONE) -> void:
	var binding: InputEventKey = null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (keycode == KEY_NONE or event.keycode == keycode or event.physical_keycode == keycode):
			binding = event.duplicate()
			break
	assert_not_null(binding, "%s has a keyboard binding" % action)
	if binding == null:
		return
	for pressed in [true, false]:
		binding.pressed = pressed
		binding.echo = false
		_viewport.push_input(binding.duplicate(), true)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _saved_inventory_signature(unit_state: Dictionary) -> Array[String]:
	var signature: Array[String] = []
	for item: Dictionary in unit_state.get("inventory", []):
		signature.append("%s@%d" % [str(item.get("id", "")), roundi(float(item.get("uses", 0)))])
	return signature


func _runtime_inventory_signature(inventory: Inventory) -> Array[String]:
	var signature: Array[String] = []
	for item: InventoryItem in inventory.items:
		signature.append("%s@%d" % [item.display_name(), roundi(float(item.uses))])
	return signature


func _same_file_state(path: String, expected_exists: bool, expected_bytes: PackedByteArray) -> bool:
	var exists := FileAccess.file_exists(path)
	if exists != expected_exists:
		return false
	return not exists or FileAccess.get_file_as_bytes(path) == expected_bytes


func test_production_item_geometry_fits_complete_labels_and_stage_instructions() -> void:
	var font := UITheme.font()
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = size
		await wait_process_frames(1)
		var body: Rect2 = _journal._body_rect()
		var layout: Dictionary = _journal._items_layout(body, font)
		var pack: Inventory = _journal._inv_units[0]["unit"].inventory
		for row: Dictionary in layout["pack_rows"]:
			var item: InventoryItem = pack.items[row["index"]]
			var label := item.display_name()
			if item == pack.equipped_weapon_item():
				label += "   (equipped)"
			var lines: Array = row["lines"]
			assert_eq(" ".join(lines).split(" ", false), label.split(" ", false),
				"complete pack name and equipped marker remain represented at %s" % size)
			var measured := font.get_multiline_string_size("\n".join(lines), HORIZONTAL_ALIGNMENT_LEFT,
				row["label_width"], 16)
			assert_lte(measured.x, row["label_width"], "active-font item line width fits at %s" % size)
			assert_lte(measured.y, row["rect"].size.y, "complete active-font item lines fit their row at %s" % size)
			assert_true(body.encloses(row["rect"]), "pack item row remains inside body at %s" % size)
		for mode in range(3):
			_journal._inv_mode = mode
			layout = _journal._items_layout(body, font)
			assert_eq(" ".join(layout["hint_lines"]).split(" ", false),
				_journal._items_hint().split(" ", false), "stage-%d instruction is complete at %s" % [mode, size])
			var hint_size := font.get_multiline_string_size("\n".join(layout["hint_lines"]),
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 14)
			assert_lte(hint_size.y, layout["hint_rect"].size.y,
				"stage-%d instruction glyphs fit at %s" % [mode, size])




func test_items_multiline_calls_keep_all_text_lines_enabled() -> void:
	assert_eq(AcademyJournal.MULTILINE_MAX_LINES, -1,
		"item labels, stage hints and inventory toasts must not request zero visible lines")


func test_production_student_and_recipient_rows_have_a_visible_window() -> void:
	var font := UITheme.font()
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = size
		await wait_process_frames(1)
		var body: Rect2 = _journal._body_rect()
		# The existing Up/Down state machine still reaches both ends, and the
		# selected identity is represented by the real live roster entry.
		_journal._inv_mode = 0
		_journal._inv_i = 0
		assert_eq(_journal._inv_i, 0, "the initial student remains the first current roster entry")
		var layout: Dictionary = _journal._items_layout(body, UITheme.font())
		assert_true(layout["visible_students"].has(0), "first student is visible at %s" % size)
		_journal._inv_move(-1)
		assert_eq(_journal._inv_i, _journal._inv_units.size() - 1,
			"Up wraps to the final student at %s" % size)
		layout = _journal._items_layout(body, UITheme.font())
		assert_true(layout["visible_students"].has(_journal._inv_i), "final selected student is visible at %s" % size)
		var selected_row: Dictionary = {}
		for row: Dictionary in layout["student_rows"]:
			if row["index"] == _journal._inv_i:
				selected_row = row
		var last_name: String = _journal._inv_units[_journal._inv_i]["name"]
		var last_glyphs: Vector2 = UITheme.font().get_string_size(last_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		var selected_glyphs := Rect2(selected_row["name_baseline"] - Vector2(0, UITheme.font().get_ascent(17)),
			Vector2(minf(last_glyphs.x, selected_row["name_width"]), UITheme.font().get_height(17)))
		assert_true(body.encloses(selected_glyphs), "the selected final student glyphs fit at %s" % size)
		_journal._inv_mode = 2
		_journal._inv_give_i = _journal._inv_i
		_journal._inv_move(-1)
		assert_ne(_journal._inv_give_i, _journal._inv_i,
			"recipient selection still skips the current giver at %s" % size)
		_journal._inv_give_i = _journal._inv_i
		_journal._inv_move(1)
		assert_eq(_journal._inv_give_i, 0, "first eligible recipient remains reachable at %s" % size)
		for _i in range(_journal._inv_units.size() - 2):
			_journal._inv_move(1)
		assert_eq(_journal._inv_give_i, _journal._inv_units.size() - 2,
			"final eligible recipient remains reachable at %s" % size)


func test_live_resize_in_both_directions_keeps_each_stage_selection_visible() -> void:
	var sizes := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360),
		Vector2i(800, 450), Vector2i(1280, 720)]
	var giver_index := 0
	var recipient_index := _journal._inv_units.size() - 1
	var item_count: int = _journal._inv_units[giver_index]["unit"].inventory.items.size()
	for mode in range(3):
		_journal._inv_mode = mode
		_journal._inv_i = giver_index
		_journal._inv_item_i = maxi(0, item_count - 1)
		_journal._inv_give_i = recipient_index
		for size in sizes:
			_viewport.size = size
			await wait_process_frames(1)
			var body: Rect2 = _journal._body_rect()
			var layout: Dictionary = _journal._items_layout(body, UITheme.font())
			var selected_student := recipient_index if mode == 2 else giver_index
			assert_true(layout["visible_students"].has(selected_student),
				"stage-%d selected student/recipient %d remains visible at %s" % [mode, selected_student, size])
			if mode == 2:
				assert_eq(layout["giver_name"], _journal._inv_units[giver_index]["name"],
					"current giver remains named while recipient list scrolls at %s" % size)
			if mode >= 1 and item_count > 0:
				assert_true(layout["visible_items"].has(_journal._inv_item_i),
					"stage-%d selected item remains visible at %s" % [mode, size])


func test_inventory_origin_refusal_feedback_fits_the_compact_viewport() -> void:
	var font := UITheme.font()
	_journal._show_toast("A very long authored item name is bound to the current student — magic can't change hands.")
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = size
		await wait_process_frames(1)
		var toast_layout: Dictionary = _journal._inventory_toast_layout(font)
		var toast: Rect2 = toast_layout["rect"]
		var text_bounds := Rect2(Vector2(toast_layout["baseline"].x,
			toast_layout["baseline"].y - font.get_ascent(16)),
			Vector2(toast_layout["text_width"], toast.size.y - 18.0))
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(toast),
			"refusal feedback background fits at %s" % size)
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(text_bounds),
			"complete refusal feedback glyphs fit at %s" % size)
		for line: String in toast_layout["lines"]:
			assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
				toast_layout["text_width"], "inventory refusal line fits its measured text pane at %s" % size)


func test_dispatched_default_and_custom_actions_preserve_three_stage_browse_state() -> void:
	var before := Campaign.to_dict()
	var save_path := _journal._save.slot_path(0)
	var settings_paths := [AudioManager.prefs_path, _keyboard_prefs_path]
	var settings_before: Array[Dictionary] = []
	for path: String in settings_paths:
		settings_before.append({"exists": FileAccess.file_exists(path),
			"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()})
	assert_false(FileAccess.file_exists(save_path), "browse starts without touching the isolated save slot")
	_press_action("cursor_confirm")
	assert_eq(_journal._inv_mode, 1, "shipped confirm opens the selected student's pack")
	assert_eq(KeyboardPreferences.assign("cursor_down", _key(KEY_N)), "",
		"a configured extra Down key is accepted")
	_press_action("cursor_down", KEY_N)
	assert_eq(_journal._inv_item_i, 1, "configured Down selects the next existing item")
	_press_action("cursor_confirm")
	assert_eq(_journal._inv_mode, 2, "shipped confirm enters recipient selection")
	var giver_id: String = _journal._inv_units[_journal._inv_i]["id"]
	var recipient_id: String = _journal._inv_units[_journal._inv_give_i]["id"]
	assert_ne(giver_id, recipient_id, "the default recipient is a different student")
	for _i in range(_journal._inv_units.size() - 2):
		_press_action("cursor_down", KEY_N)
	assert_eq(_journal._inv_units[_journal._inv_give_i]["id"], _journal._inv_units[-1]["id"],
		"configured Down reaches the final eligible recipient")
	_viewport.size = Vector2i(640, 360)
	var compact_layout: Dictionary = _journal._items_layout(_journal._body_rect(), UITheme.font())
	assert_true(compact_layout["visible_students"].has(_journal._inv_give_i),
		"the selected final recipient remains visible at compact size")
	_press_action("cursor_cancel")
	assert_eq(_journal._inv_mode, 1, "shipped cancel backs out to the item stage")
	_press_action("cursor_cancel")
	assert_eq(_journal._inv_mode, 0, "shipped cancel backs out to students")
	assert_true(_journal.visible, "backing out leaves Journal open")
	assert_eq(Campaign.to_dict(), before,
		"default/custom navigation leaves campaign, inventory, flags, progression and RNG unchanged")
	assert_false(FileAccess.file_exists(save_path), "browse/cancel does not write an isolated save")
	for i in range(settings_paths.size()):
		assert_true(_same_file_state(settings_paths[i], settings_before[i]["exists"], settings_before[i]["bytes"]),
			"browse/cancel preserves settings file presence and bytes")


func test_successful_transfer_still_round_trips_through_the_existing_campaign_save() -> void:
	var giver: Dictionary = _journal._inv_units[0]
	var recipient: Dictionary = _journal._inv_units[1]
	var before_campaign := Campaign.to_dict()
	var item_index := -1
	for i in range(giver["unit"].inventory.items.size()):
		if giver["unit"].inventory.is_tradeable(giver["unit"].inventory.items[i]):
			item_index = i
			break
	assert_gte(item_index, 0, "the existing giver has an ordinary tradeable item")
	if item_index < 0:
		return
	_journal._inv_i = 0
	_journal._inv_item_i = item_index
	_journal._inv_give_i = 1
	_journal._inv_mode = 2
	_journal._inv_transfer()
	var expected_campaign: Dictionary = before_campaign.duplicate(true)
	expected_campaign["unit_states"][giver["id"]] = Campaign.get_unit_state(giver["id"]).duplicate(true)
	expected_campaign["unit_states"][recipient["id"]] = Campaign.get_unit_state(recipient["id"]).duplicate(true)
	assert_eq(Campaign.to_dict(), expected_campaign,
		"successful transfer changes exactly the existing giver/recipient unit states")
	var expected_giver := _saved_inventory_signature(Campaign.get_unit_state(giver["id"]))
	var expected_recipient := _saved_inventory_signature(Campaign.get_unit_state(recipient["id"]))
	assert_true(Campaign.save_to_slot(0, _journal._save), "the existing Campaign save path writes")
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(0, _journal._save), "the existing Campaign load path restores")
	assert_eq(_saved_inventory_signature(Campaign.get_unit_state(giver["id"])), expected_giver,
		"giver inventory identity/order/uses persist exactly")
	assert_eq(_saved_inventory_signature(Campaign.get_unit_state(recipient["id"])), expected_recipient,
		"recipient inventory persists exactly")


func test_shipped_five_item_pack_and_empty_states_remain_safe() -> void:
	var unit: Unit = _journal._inv_units[0]["unit"]
	var inventory: Inventory = unit.inventory
	var original_items: Array = inventory.items.duplicate()
	inventory.items.clear()
	var fixture_names := ["sig_vesper", "sig_isolde", "sig_rina", "sig_osric", "sig_perrin"]
	for i in range(fixture_names.size()):
		var weapon: WeaponDef = load("res://data/weapons/%s.tres" % fixture_names[i])
		var item := InventoryItem.from_weapon(weapon)
		item.uses = 9 - i
		assert_true(inventory.add(item), "fixture weapon %s fits" % weapon.display_name)
	var font := UITheme.font()
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360),
		Vector2i(800, 450), Vector2i(1280, 720)]:
		_viewport.size = size
		await wait_process_frames(1)
		var body: Rect2 = _journal._body_rect()
		_journal._inv_mode = 1
		for i in range(inventory.items.size()):
			if i == 0:
				_journal._inv_item_i = 0
			else:
				_press_action("cursor_down")
			assert_eq(_journal._inv_item_i, i, "dispatched Down selects item %d at %s" % [i, size])
			var layout: Dictionary = _journal._items_layout(body, font)
			assert_true(layout["visible_items"].has(i), "selected five-pack item %d stays visible at %s" % [i, size])
			var row: Dictionary = {}
			for candidate: Dictionary in layout["pack_rows"]:
				if candidate["index"] == i:
					row = candidate
			assert_false(row.is_empty(), "five-pack item %d has a production row at %s" % [i, size])
			var full_label := inventory.items[i].display_name()
			if inventory.items[i] == inventory.equipped_weapon_item():
				full_label += "   (equipped)"
			assert_eq(" ".join(row["lines"]).split(" ", false), full_label.split(" ", false),
				"shipped name and equipped marker are complete at %s" % size)
			for line: String in row["lines"]:
				assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
					row["label_width"], "full-pack glyph line fits at %s" % size)
			var expected_uses := "∞" if inventory.items[i].uses >= 999 else "×%d" % inventory.items[i].uses
			assert_eq(row["uses"], expected_uses, "remaining uses/count stay exact at %s" % size)
			assert_true(body.encloses(row["rect"]), "five-pack row remains inside body at %s" % size)
		assert_eq(inventory.items.size(), Inventory.MAX_SLOTS, "fixture fills the existing five slots")
	# Empty pack/roster are existing states, not new mechanics.
	inventory.items.clear()
	_journal._inv_mode = 0
	_journal._inv_confirm()
	assert_eq(_journal._inv_mode, 0, "an empty pack does not enter item selection")
	var live_units: Array = _journal._inv_units
	_journal._inv_units = []
	_journal._inv_confirm()
	assert_eq(_journal._inv_i, 0, "an empty roster is a safe no-op")
	_journal._inv_units = live_units
	inventory.items.assign(original_items)


func test_actual_full_bound_and_tome_refusals_keep_feedback_inside_the_book() -> void:
	var original_campaign := Campaign.to_dict()
	var kai_index := -1
	for i in range(_journal._inv_units.size()):
		if _journal._inv_units[i]["id"] == "kai":
			kai_index = i
	assert_gte(kai_index, 0, "the earned roster contains Kai")
	if kai_index < 0:
		return
	var kai: Dictionary = _journal._inv_units[kai_index]
	var recipient_index := 0 if kai_index != 0 else 1
	var recipient: Dictionary = _journal._inv_units[recipient_index]
	var original_giver_items: Array = kai["unit"].inventory.items.duplicate()
	var original_recipient_items: Array = recipient["unit"].inventory.items.duplicate()
	var bound_index := -1
	for i in range(kai["unit"].inventory.items.size()):
		var weapon: WeaponDef = kai["unit"].inventory.items[i].weapon()
		if weapon != null and weapon.innate:
			bound_index = i
			break
	assert_gte(bound_index, 0, "Kai has the existing bound Crownspark")
	if bound_index >= 0:
		_journal._inv_i = kai_index
		_journal._inv_give_i = recipient_index
		_journal._inv_item_i = bound_index
		_journal._inv_mode = 2
		var before_bound := _runtime_inventory_signature(kai["unit"].inventory)
		var before_bound_recipient := _runtime_inventory_signature(recipient["unit"].inventory)
		_journal._inv_transfer()
		assert_eq(_runtime_inventory_signature(kai["unit"].inventory), before_bound,
			"bound item refusal leaves giver inventory intact")
		assert_eq(_runtime_inventory_signature(recipient["unit"].inventory), before_bound_recipient,
			"bound item refusal leaves recipient inventory intact")
		assert_true(_inventory_toast_is_readable(), "bound refusal message stays readable")
	var tome := WeaponDef.new()
	tome.id = "fixture_long_tome"
	tome.display_name = "A Long Fixture Spellbook Tome"
	tome.weapon_type = WeaponDef.WeaponType.TOME
	tome.max_uses = 10
	var tome_item := InventoryItem.from_weapon(tome)
	assert_true(kai["unit"].inventory.add(tome_item), "test-only tome fixture fits in Kai's pack")
	_journal._inv_i = kai_index
	_journal._inv_give_i = recipient_index
	_journal._inv_item_i = kai["unit"].inventory.items.size() - 1
	_journal._inv_mode = 2
	var before_tome := _runtime_inventory_signature(kai["unit"].inventory)
	var before_tome_recipient := _runtime_inventory_signature(recipient["unit"].inventory)
	_journal._inv_transfer()
	assert_eq(_runtime_inventory_signature(kai["unit"].inventory), before_tome,
		"tome refusal leaves giver inventory intact")
	assert_eq(_runtime_inventory_signature(recipient["unit"].inventory), before_tome_recipient,
		"tome refusal leaves recipient inventory intact")
	assert_true(_inventory_toast_is_readable(), "tome refusal message stays readable")
	while not recipient["unit"].inventory.is_full():
		recipient["unit"].inventory.add(InventoryItem.from_weapon(load("res://data/weapons/iron_sword.tres")))
	var tradeable_index := -1
	for i in range(kai["unit"].inventory.items.size()):
		if kai["unit"].inventory.is_tradeable(kai["unit"].inventory.items[i]):
			tradeable_index = i
			break
	assert_gte(tradeable_index, 0, "the full-pack refusal uses an ordinary tradeable item")
	if tradeable_index < 0:
		return
	_journal._inv_item_i = tradeable_index
	var before_full_giver := _runtime_inventory_signature(kai["unit"].inventory)
	var before_full_recipient := _runtime_inventory_signature(recipient["unit"].inventory)
	_journal._inv_transfer()
	assert_eq(_runtime_inventory_signature(kai["unit"].inventory), before_full_giver,
		"full-pack refusal leaves giver inventory intact")
	assert_eq(_runtime_inventory_signature(recipient["unit"].inventory), before_full_recipient,
		"full-pack refusal leaves recipient inventory intact")
	assert_true(_inventory_toast_is_readable(), "full-pack refusal message stays readable")
	assert_eq(Campaign.to_dict(), original_campaign,
		"all refusal attempts leave Campaign, progression and RNG unchanged")
	kai["unit"].inventory.items.assign(original_giver_items)
	recipient["unit"].inventory.items.assign(original_recipient_items)


func _inventory_toast_is_readable() -> bool:
	var font := UITheme.font()
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = size
		var layout: Dictionary = _journal._inventory_toast_layout(font)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
		if not viewport_rect.encloses(layout["rect"]):
			return false
		for line: String in layout["lines"]:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > layout["text_width"]:
				return false
	return true
