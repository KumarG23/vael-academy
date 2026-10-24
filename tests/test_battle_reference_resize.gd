extends GutTest
## GH-112: exercise the production CanvasLayer under actual viewport resizing.
var vp: SubViewport
var view: BattleView

func before_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.handle_input_locally = true
	add_child_autofree(vp)
	view = load("res://scenes/battle/battle.tscn").instantiate()
	view.strike_delay = 0.0
	view.combat_seed = 3
	vp.add_child(view)
	await wait_physics_frames(3)

func after_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false

func _inside(control: Control, extent: Vector2 = Vector2.ZERO) -> void:
	var rect := Rect2(control.position, extent if extent != Vector2.ZERO else control.size)
	assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(rect), "%s inside %s: %s" % [control.name, vp.size, rect])

func _resize(dim: Vector2i) -> void:
	vp.size = dim
	await wait_physics_frames(3)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	vp.push_input(ev, true)
	await wait_physics_frames(2)

func test_hover_forecast_live_shrink_and_restore_preserves_state() -> void:
	var kael := view.unit_by_id("kael")
	var foe := view.unit_at(Vector2i(6, 7))
	view._cursor.move_to(foe.cell)
	view._selected = kael
	view._show_forecast_for(foe)
	var payload := view.make_save_payload()
	var campaign := Campaign.to_dict().duplicate(true)
	var active := Campaign.active
	var skipped := Campaign._skip_next_hub_reset
	var cursor := view._cursor.cell
	for dim in [Vector2i(1280,720), Vector2i(800,450), Vector2i(640,360), Vector2i(800,450), Vector2i(1280,720)]:
		await _resize(dim)
		_inside(view._objective_label)
		_inside(view._debug_label)
		_inside(view._hover_info)
		_inside(view._forecast_panel)
		assert_false(view._hover_info.get_global_rect().intersects(view._forecast_panel.get_global_rect()), "hover and forecast clear one another")
		assert_eq(view.make_save_payload(), payload, "resize preserves full snapshot")
		assert_eq(view._cursor.cell, cursor)
		assert_eq(view._selected, kael)
		assert_eq(Campaign.to_dict(), campaign)
		assert_eq(Campaign.active, active)
		assert_eq(Campaign._skip_next_hub_reset, skipped)
		assert_eq(BattleView.next_resume, {})
		assert_false(BattleView.next_prep)

func test_stats_live_shrink_with_hover_and_real_dismissal() -> void:
	var foe := view.unit_at(Vector2i(6,7))
	view._cursor.move_to(foe.cell)
	view._try_select(foe.cell)
	view._try_select(foe.cell)
	var payload := view.make_save_payload()
	for dim in [Vector2i(800,450), Vector2i(640,360), Vector2i(1280,720)]:
		await _resize(dim)
		_inside(view._stats_panel)
		_inside(view._hover_info)
		_inside(view._objective_label)
		assert_false(view._stats_panel.get_global_rect().intersects(view._hover_info.get_global_rect()), "inspection clears hover")
		assert_eq(view.make_save_payload(), payload)
	await _key(KEY_Q)
	assert_false(view._stats_panel.is_shown(), "ordinary any-key dismissal")
	assert_true(view._cursor.active)


func _paragraphs_fit(panel: Control) -> void:
	var rects: Array[Rect2] = []
	for row: Dictionary in panel.get("_text_rows"):
		var paragraph: TextParagraph = row.paragraph
		var rect := Rect2(row.at, paragraph.get_size())
		assert_true(Rect2(Vector2.ZERO, panel.size).grow(-16).encloses(rect), "complete field inside panel: " + row.text)
		for i in paragraph.get_line_count():
			assert_lte(paragraph.get_line_size(i).x, paragraph.width + 1, "active-font line fits: " + row.text)
		for other in rects:
			assert_false(rect.intersects(other), "required fields do not cover each other: " + row.text)
		rects.append(rect)


func _references_clear(panel: Control) -> void:
	_inside(panel)
	_inside(view._hover_info)
	_inside(view._objective_label)
	_inside(view._debug_label)
	for other: Control in [view._hover_info, view._objective_label, view._debug_label]:
		assert_false(panel.get_global_rect().intersects(other.get_global_rect()), "%s clear of %s: %s vs %s" % [panel.get("_title"), other.name, panel.get_global_rect(), other.get_global_rect()])
	assert_false(view._objective_label.get_global_rect().intersects(view._debug_label.get_global_rect()), "header and objective clear")
	for header: Control in [view._objective_label, view._debug_label]:
		assert_false(header.get_global_rect().intersects(view._hover_info.get_global_rect()), "header clears hover")


func test_all_shipped_inspection_fields_and_role_hints_fit_compact() -> void:
	await _resize(Vector2i(640,360))
	var payload := view.make_save_payload()
	for filename in DirAccess.get_files_at("res://data/units"):
		if not filename.ends_with(".tres"):
			continue
		var def: UnitDef = load("res://data/units/" + filename)
		if def == null:
			continue
		var unit := Unit.new()
		add_child_autofree(unit)
		unit.setup(def, view._grid, Vector2i.ZERO)
		assert_lte(UITheme.font().get_string_size(def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, 206.0, "shipped hover name fits active font")
		assert_lte(UITheme.font().get_string_size("%s   Lv %d" % [def.char_class.display_name, unit.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 206.0, "shipped hover class/level fits")
		view._stats_panel.show_unit(unit)
		await wait_physics_frames(1)
		_references_clear(view._stats_panel)
		_paragraphs_fit(view._stats_panel)
		var fields: Array[String] = []
		for row: Dictionary in view._stats_panel._text_rows:
			fields.append(row.text)
		for line in UnitStatsPanel._build_lines(unit):
			assert_has(fields, line, "complete shipped weapon/role/stats field")
		assert_eq(view.make_save_payload(), payload, "inspection/resize remains read only")
	view._stats_panel.close()


func test_initial_compact_and_both_forecast_columns_long_names_no_counter_doubling() -> void:
	for dim in [Vector2i(800,450), Vector2i(640,360)]:
		view.free()
		vp.size = dim
		view = load("res://scenes/battle/battle.tscn").instantiate()
		vp.add_child(view)
		await wait_physics_frames(3)
		var attacker := view.unit_by_id("kael")
		var defender := view.unit_at(Vector2i(6,7))
		# Shipped long labels, with independent snapshot speed to exercise x2.
		var a := attacker.to_combatant(0,0)
		var b := defender.to_combatant(0,0)
		a.speed = 30
		b.speed = 0
		for distance in [1,2]:
			var ex := CombatForecast.exchange(a,b,distance)
			view._forecast_panel.show_forecast(defender,defender,ex)
			await wait_physics_frames(2)
			_references_clear(view._forecast_panel)
			_paragraphs_fit(view._forecast_panel)
			var fields: Array[String] = []
			for row: Dictionary in view._forecast_panel._text_rows:
				fields.append(row.text)
			assert_eq(fields.count(defender.unit_def.display_name), 2, "both complete long names retained")
			if distance == 1:
				assert_true(" ".join(fields).contains("x2"), "doubling marker retained")
				assert_eq(" ".join(fields).count("Hit"), 2, "both hit fields")
				assert_eq(" ".join(fields).count("Crit"), 2, "both crit fields")
			else:
				assert_has(fields,"no counter", "out-of-range counter information retained")

		view._forecast_panel.hide_panel()
		view._open_stats_for(view.unit_by_id("wren"))
		await wait_physics_frames(3)
		_references_clear(view._stats_panel)
		_paragraphs_fit(view._stats_panel)
		view._stats_panel.close()


func test_compact_stats_pointer_dismiss_and_input_hint_clear_hover() -> void:
	await _resize(Vector2i(640,360))
	_inside(view._input_hint)
	assert_false(view._input_hint.get_global_rect().intersects(view._hover_info.get_global_rect()), "idle input hints clear hover")
	var foe := view.unit_at(Vector2i(6,7))
	view._cursor.move_to(foe.cell)
	view._try_select(foe.cell)
	view._try_select(foe.cell)
	await wait_physics_frames(2)
	var payload := view.make_save_payload()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = view._stats_panel.get_global_rect().get_center()
	ev.global_position = ev.position
	vp.push_input(ev,true)
	await wait_physics_frames(2)
	assert_false(view._stats_panel.is_shown(), "click dismisses resized actual sheet")
	assert_eq(view.make_save_payload(),payload, "dismissal spends nothing")
	assert_true(view._cursor.active)


func _wait_menu() -> void:
	for i in 600:
		if view._menu.visible and view._phase == view.Phase.MENU:
			return
		await wait_physics_frames(1)
	fail_test("ordinary move did not return to the command menu")


func _choose_attack() -> void:
	await _wait_menu()
	for i in view._menu_actions.find("attack"):
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	if view._menu_context == "attack_weapon":
		await _key(KEY_ENTER)
	assert_true(view._forecast_panel.visible)
	assert_eq(view._phase,view.Phase.TARGETING)


func _confirm_after_resize(resize_live: bool) -> Dictionary:
	view.free()
	Campaign.reset_new_game(false)
	vp.size = Vector2i(1280,720)
	view = load("res://scenes/battle/battle.tscn").instantiate()
	view.strike_delay = 0.0
	view.combat_seed = 3
	vp.add_child(view)
	await wait_physics_frames(3)
	var kael := view.unit_by_id("kael")
	view._cursor.move_to(kael.cell)
	await _key(KEY_ENTER)
	view._cursor.move_to(Vector2i(5,7))
	await _key(KEY_ENTER)
	await _choose_attack()
	var saved := view.make_save_payload()
	var origin := view._move_origin
	var cursor := view._cursor.cell
	if resize_live:
		for dim in [Vector2i(640,360), Vector2i(1280,720), Vector2i(640,360)]:
			await _resize(dim)
			assert_eq(view.make_save_payload(), saved)
			assert_eq(view._move_origin,origin)
			assert_eq(view._cursor.cell,cursor)
			assert_eq(view._selected,kael)
			assert_eq(view._phase,view.Phase.TARGETING)
	await _key(KEY_ESCAPE)
	assert_eq(view._phase,view.Phase.MENU,"real forecast cancel returns to command menu")
	assert_eq(view.make_save_payload(),saved,"cancel spends nothing")
	await _choose_attack()
	await _key(KEY_ENTER)
	for i in 600:
		if not view._busy:
			break
		await wait_physics_frames(1)
	assert_false(view._busy)
	assert_true(kael.has_acted,"confirm spends the ordinary action")
	assert_false(view._forecast_panel.visible)
	return view.make_save_payload()


func test_real_forecast_cancel_and_confirm_after_resize_match_native_resolution() -> void:
	var unresized := await _confirm_after_resize(false)
	var resized := await _confirm_after_resize(true)
	assert_eq(resized,unresized,"entire resolver/RNG/progression/support/action result matches without resizing")


func test_compact_inspection_full_shipped_pack_and_promoted_role() -> void:
	await _resize(Vector2i(640,360))
	for id in ["osric", "tm_armor", "brenna", "wren"]:
		var unit := Unit.new()
		add_child_autofree(unit)
		unit.setup(load("res://data/units/%s.tres" % id), view._grid, Vector2i.ZERO)
		if unit.unit_def.promotion_class != null:
			unit._class_override = unit.unit_def.promotion_class
		unit.inventory = Inventory.new()
		for weapon_id in ["sig_bertram", "sig_brenna", "sig_fenn", "sig_rurik", "sig_osric"]:
			unit.inventory.add(InventoryItem.from_weapon(load("res://data/weapons/%s.tres" % weapon_id)))
		view._stats_panel.show_unit(unit)
		await wait_physics_frames(3)
		_references_clear(view._stats_panel)
		_paragraphs_fit(view._stats_panel)
		assert_string_contains(" ".join(view._stats_panel._lines), "Also carries:", "full pack is represented")
		assert_eq(view._stats_panel._lines, UnitStatsPanel._build_lines(unit), "no inspection fields discarded")


func test_shipped_objective_wording_and_header_fit_at_all_reference_sizes() -> void:
	var reference := preload("res://src/ui/mission_reference.gd")
	for chapter_name in ["prologue", "indoor_demo", "mock_battle"]:
		var chapter: ChapterDef = load("res://data/chapters/%s.tres" % chapter_name)
		var wording := reference.objective_text(chapter)
		view._objective_label.text = wording
		for dim in [Vector2i(1280,720),Vector2i(800,450),Vector2i(640,360),Vector2i(1280,720)]:
			await _resize(dim)
			assert_eq(view._objective_label.text, wording,"objective wording unchanged")
			_inside(view._objective_label)
			_inside(view._debug_label)
			assert_false(view._objective_label.get_global_rect().intersects(view._debug_label.get_global_rect()))
			var label := view._objective_label
			var font := label.get_theme_font("font")
			var required := font.get_multiline_string_size(wording,HORIZONTAL_ALIGNMENT_LEFT,label.size.x,label.get_theme_font_size("font_size"))
			assert_lte(required.y,label.size.y,"active-font objective text fits vertically")
