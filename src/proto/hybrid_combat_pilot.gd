class_name HybridCombatPilot
extends BattleView
## CP-6 A/B sandbox. Reuses actual tactical selection/path/forecast.
## No Campaign overlay, completion, progression, saves or durability writes.
signal comparison_beat(mode: String, name: String)
var kai: Unit
var serra: Unit
var presentation: IllustratedCombatPresentation
var pixel: PixelCombatComparison
var mode := "B"
var comparison_running := false
var _exchange_attacker: Unit
var _exchange_defender: Unit
var _mode_button: Button
var last_result: CombatResult
var last_seed := 0
var _review_status: Label
var _review_buttons: Array[Button] = []
var _review_panel: PanelContainer


func _ready() -> void:
	dialogue_enabled = false
	combat_seed = 11
	super._ready()
	_debug_label.visible = false
	_objective_label.visible = false
	_hover_info.position.y = get_viewport_rect().size.y - 260
	presentation = IllustratedCombatPresentation.new()
	add_child(presentation)
	presentation.beat.connect(func(name: String) -> void: comparison_beat.emit("B", name))
	pixel = PixelCombatComparison.new()
	add_child(pixel)
	pixel.beat.connect(func(name: String) -> void: comparison_beat.emit("A", name))
	pixel.contact.connect(_pixel_contact)
	_build_review_ui()
	_review_status.text = "Select Kai, move, then Attack or Magic. Or choose a review exchange below."


func _spawn_units() -> void:
	# Fresh chapter actors, even if a campaign was active before opening the pilot.
	for spawn: UnitSpawn in chapter.player_spawns + chapter.enemy_spawns:
		var definition := spawn.unit.duplicate() as UnitDef
		if spawn.team_override >= 0:
			definition.team = spawn.team_override
		var actor := add_unit(definition, spawn.cell)
		if definition.id == "kai":
			kai = actor
			_lord_unit = actor
		else:
			serra = actor
			actor.set_facing(false)


func _begin_battle() -> void:
	_phase = Phase.IDLE
	_cursor.active = true


func _try_select(cell: Vector2i) -> void:
	# Empty tiles don't open the production field/save menu in this sandbox.
	if unit_at(cell) != null:
		super._try_select(cell)


func _finish_action() -> void:
	_forecast_panel.hide_panel()
	_deselect()
	kai.has_acted = false
	kai.queue_redraw()
	_check_objective()


func _check_objective() -> void:
	if _review_status != null and (not kai.is_alive() or not serra.is_alive()):
		_review_status.text = "Exchange complete. Reset the training field to play again."


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_A, KEY_B] and not _busy and not comparison_running:
		mode = "A" if event.keycode == KEY_A else "B"
		_update_mode()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_6 and not _busy and not comparison_running:
		get_viewport().set_input_as_handled()
		compare_all()
		return
	var action: String = {KEY_1: "sword", KEY_2: "critical", KEY_3: "miss", KEY_4: "magic", KEY_5: "defeat", KEY_R: "reset"}.get(event.keycode, "")
	if action != "" and not _busy and not comparison_running:
		get_viewport().set_input_as_handled()
		review(action)


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	_busy = true
	_cursor.active = false
	_forecast_panel.hide_panel()
	var distance := _manhattan(attacker.cell, defender.cell)
	last_result = CombatResolver.resolve(_combatant_for(attacker, attacker.cell), _combatant_for(defender, defender.cell), distance, _rng)
	await _present_result(attacker, defender, last_result)
	_busy = false
	_cursor.active = true
	_check_objective()


func reset_field() -> void:
	_menu.close()
	_stats_panel.visible = false
	_deselect()
	_turn.active_team = TurnManager.Team.PLAYER
	_turn.round_number = 1
	for actor: Unit in [kai, serra]:
		actor.current_hp = actor.max_hp()
		actor.visible = true
		actor.modulate = Color.WHITE
		actor.has_acted = false
		actor.cell = Vector2i(6, 4) if actor == kai else Vector2i(7, 4)
		actor.position = _grid.cell_center(actor.cell)
		actor.queue_redraw()
	kai.equip_weapon(load("res://data/weapons/sig_kai.tres"))
	serra.equip_weapon(load("res://data/weapons/iron_lance.tres"))
	_cursor.move_to(kai.cell)
	_cursor.active = true


func prepare_review(kind: String) -> CombatResult:
	reset_field()
	if kind == "magic":
		kai.equip_weapon(load("res://data/weapons/crownspark.tres"))
		kai.cell = Vector2i(5, 4)
		kai.position = _grid.cell_center(kai.cell)
	if kind == "defeat":
		# A wounded local opponent, not a fake lethal visual/result.
		serra.current_hp = 6
	var attacker := _combatant_for(kai, kai.cell)
	var defender := _combatant_for(serra, serra.cell)
	var distance := _manhattan(kai.cell, serra.cell)
	# Review fixtures use independent seeds; live attacks consume _rng once.
	for seed_value in range(10000):
		var candidate := CombatResolver.resolve(attacker, defender, distance, CombatRNG.new(seed_value))
		if candidate.strikes.is_empty():
			continue
		var first := candidate.strikes[0]
		var fits := first.connected and not first.was_crit
		if kind == "critical":
			fits = first.connected and first.was_crit
		elif kind == "miss":
			fits = not first.connected
		elif kind == "defeat":
			fits = fits and first.defender_hp_after == 0
		if fits:
			last_seed = seed_value
			last_result = candidate
			return candidate
	push_error("No native resolver fixture for " + kind)
	return null


func review(kind: String) -> void:
	if _busy:
		return
	if kind == "reset":
		reset_field()
		_review_status.text = "Training field reset. Select Kai to move and attack."
		return
	var result := prepare_review(kind)
	if result == null:
		return
	_review_status.text = {"sword": "Sword thrust", "critical": "Critical exchange", "miss": "Miss and evasion", "magic": "Crown-light", "defeat": "Wounded opponent / defeat"}[kind]
	_busy = true
	_cursor.active = false
	await get_tree().create_timer(0.22).timeout
	await _present_result(kai, serra, result)
	_busy = false
	_cursor.active = true
	_check_objective()


func _process(delta: float) -> void:
	super._process(delta)
	for button: Button in _review_buttons:
		button.disabled = _busy or comparison_running
	if _mode_button != null:
		_mode_button.disabled = _busy or comparison_running


func _build_review_ui() -> void:
	var viewport_size := get_viewport_rect().size
	var header := ColorRect.new()
	header.color = Color("101a25")
	header.size = Vector2(viewport_size.x, 92)
	_ui_layer.add_child(header)
	_ui_layer.add_child(IllustratedCombatPresentation.label("VAEL ACADEMY", Vector2(38, 16), 25, IllustratedCombatPresentation.GOLD))
	_ui_layer.add_child(IllustratedCombatPresentation.label("BATTLE ART COMPARISON  /  SAME KAI & SERRA EXCHANGES", Vector2(38, 51), 14, Color("adb9c5")))
	_mode_button = Button.new()
	_mode_button.position = Vector2(viewport_size.x - 280, 18)
	_mode_button.size = Vector2(240, 42)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.pressed.connect(func() -> void:
		mode = "B" if mode == "A" else "A"
		_update_mode())
	_ui_layer.add_child(_mode_button)
	_update_mode()
	_review_panel = PanelContainer.new()
	_review_panel.position = Vector2(24, viewport_size.y - 110)
	_review_panel.size = Vector2(viewport_size.x - 48, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a25")
	style.border_color = IllustratedCombatPresentation.GOLD.darkened(0.4)
	style.border_width_top = 1
	style.set_content_margin_all(16)
	_review_panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(_review_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_review_panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for entry in [["1 Sword", "sword"], ["2 Critical", "critical"], ["3 Miss", "miss"], ["4 Magic*", "magic"], ["5 Defeat", "defeat"], ["6 A/B reel", "compare"], ["Reset", "reset"], ["Credits", "credits"], ["Title", "title"]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("1c2a39")
		normal.border_color = Color("53616d")
		normal.set_border_width_all(1)
		normal.content_margin_left = 10
		normal.content_margin_right = 10
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("344352")
		hover.border_color = IllustratedCombatPresentation.GOLD
		button.add_theme_stylebox_override("hover", hover)
		if entry[1] == "title":
			button.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn"))
		elif entry[1] == "credits":
			button.pressed.connect(_show_credits)
		elif entry[1] == "compare":
			button.pressed.connect(compare_all)
		else:
			button.pressed.connect(review.bind(entry[1]))
		row.add_child(button)
		_review_buttons.append(button)
	_review_status = IllustratedCombatPresentation.label("", Vector2.ZERO, 15, Color("bac4cf"))
	column.add_child(_review_status)


func _update_mode() -> void:
	_mode_button.text = "A · PixelLab   [A / B]" if mode == "A" else "B · Illustrated   [A / B]"
	if _review_status != null:
		_review_status.text = "Same resolver cases in A or B. *A magic uses a placeholder sword gesture."


func _pixel_contact(strike: StrikeResult) -> void:
	var target := _exchange_attacker if strike.is_counter else _exchange_defender
	if strike.connected:
		target.set_hp(strike.defender_hp_after)


func _present_result(attacker: Unit, defender: Unit, result: CombatResult) -> void:
	if mode == "B":
		await presentation.play_exchange(attacker, defender, result, _ui_layer)
		return
	_exchange_attacker = attacker
	_exchange_defender = defender
	var distance := _manhattan(attacker.cell, defender.cell)
	var forecast := CombatForecast.exchange(_combatant_for(attacker, attacker.cell), _combatant_for(defender, defender.cell), distance)
	pixel.stage_terrain = chapter.get_terrain(defender.cell.x, defender.cell.y)
	_ui_layer.visible = false
	await pixel.play_exchange(attacker, defender, result.strikes, forecast, null, distance)
	for actor: Unit in [attacker, defender]:
		actor.visible = actor.is_alive()
	_ui_layer.visible = true
	comparison_beat.emit("A", "map")


func compare_all() -> void:
	if _busy or comparison_running:
		return
	comparison_running = true
	for kind: String in ["sword", "critical", "miss", "magic", "defeat"]:
		for variant: String in ["A", "B"]:
			mode = variant
			_update_mode()
			await review(kind)
			await get_tree().create_timer(0.45).timeout
	comparison_running = false


func _show_credits() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Vael Academy — combat study credits"
	dialog.dialog_text = "Character poses and courtyard: existing Vael Academy / Gemini artwork.\n\nCombat FX Free by heyheythere\nhttps://heyheythere.itch.io/combat-fx-free — CC BY 4.0\n\nSpell FX Free by heyheythere\nhttps://heyheythere.itch.io/spell-fx-free — CC BY 4.0\nLicense: https://creativecommons.org/licenses/by/4.0/\nSelected HD sheets tinted/scaled in Godot; pixels unchanged.\n\nParticle Pack by Kenney — CC0\nhttps://kenney.nl/assets/particle-pack\nhttps://creativecommons.org/publicdomain/zero/1.0/\n\nFull provenance, licenses and evaluation: assets/source/hybrid_combat_fx/"
	_ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
