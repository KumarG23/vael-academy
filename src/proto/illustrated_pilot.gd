class_name IllustratedPilot
extends Node2D
## CP-2 taste test: real Units / resolver / combat juice, isolated presentation.
## No campaign advancement, inventory writes, or authored story dialogue.

const ART_ROOT := "res://assets/art/illustrated_pilot"
const GOLD := Color(0.90, 0.80, 0.53)
const INK := Color(0.055, 0.075, 0.12, 0.94)
const CELL := 112

var kai: Unit
var serra: Unit
var juice: JuiceController
var grid := Grid.new(8, 2, CELL)
var busy := false
var autoplay := false
var _actors: Node2D
var _background: Sprite2D
var _ui: CanvasLayer
var _status: Label
var _kai_info: Label
var _serra_info: Label
var _buttons: Array[Button] = []
var _action := "walk"
var _elapsed := 0.0
var _home_kai := Vector2.ZERO
var _home_serra := Vector2.ZERO
var _backdrop: Texture2D


func _ready() -> void:
	AudioManager.stop_music()
	_backdrop = load(ART_ROOT + "/courtyard.png")
	_background = Sprite2D.new()
	_background.texture = _backdrop
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_background)
	_actors = Node2D.new()
	add_child(_actors)
	kai = _make_unit("kai", Vector2i(2, 1), 0)
	serra = _make_unit("serra_prologue", Vector2i(5, 1), 1)
	kai.set_illustrated_art(ART_ROOT + "/kai", 68.0)
	serra.set_illustrated_art(ART_ROOT + "/serra", 68.0)
	kai.show_map_ui = false
	serra.show_map_ui = false
	kai.move_speed_px = 210.0
	serra.move_speed_px = 210.0
	serra.set_facing(false)
	_home_kai = kai.position
	_home_serra = serra.position
	juice = JuiceController.new()
	add_child(juice)
	var config := JuiceConfig.new()
	config.splash_on_crit = false  # keep contact visible; the pilot uses a compact cue
	config.splash_on_kill = false
	var numbers := Node2D.new()
	numbers.z_index = 20
	_actors.add_child(numbers)
	juice.setup(config, null, numbers, null)
	_build_ui()
	_resize()
	get_viewport().size_changed.connect(_resize)
	_status.text = "Walk the terrace, then try a strike."
	if autoplay:
		_demo.call_deferred()


func _make_unit(id: String, cell: Vector2i, team: int) -> Unit:
	var definition: UnitDef = (load("res://data/units/%s.tres" % id) as UnitDef).duplicate()
	# External resources remain shared even through UnitDef.duplicate(true).
	# Copy each spell and replace the array; never weaken the campaign asset.
	var preview_spells: Array[WeaponDef] = []
	for spell: WeaponDef in definition.extra_weapons:
		var local_spell := spell.duplicate() as WeaponDef
		local_spell.required_story_flag = ""
		preview_spells.append(local_spell)
	definition.extra_weapons = preview_spells
	definition.team = team
	var actor := Unit.new()
	actor.setup(definition, grid, cell)
	_actors.add_child(actor)
	return actor


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var top := VBoxContainer.new()
	top.position = Vector2(36, 26)
	top.add_theme_constant_override("separation", 6)
	_ui.add_child(top)
	top.add_child(_label("VAEL  /  THE SUNLIT CLOISTER", 15, GOLD))
	top.add_child(_label("An illustrated academy", 32))
	top.add_child(_label("Kai & Serra  ·  Moving art pilot", 16, Color(0.85, 0.86, 0.88)))
	_status = _label("", 18, GOLD)
	_status.position = Vector2(36, 138)
	_ui.add_child(_status)
	_kai_info = _label("", 18)
	_serra_info = _label("", 18)
	_ui.add_child(_kai_info)
	_ui.add_child(_serra_info)
	var panel := PanelContainer.new()
	panel.name = "Controls"
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = GOLD.darkened(0.35)
	style.border_width_top = 1
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	panel.add_child(contents)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	contents.add_child(row)
	for entry in [["Walk", "walk"], ["Hit", "hit"], ["Critical", "crit"], ["Miss", "miss"], ["Crown-light", "cast"], ["Defeat", "kill"], ["Spar", "spar"], ["Dialogue", "dialogue"], ["Reset", "reset"]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE  # movement keys belong to the terrace
		button.custom_minimum_size = Vector2(90, 38)
		button.add_theme_font_size_override("font_size", 16)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.10, 0.14, 0.21)
		normal.border_color = GOLD.darkened(0.45)
		normal.set_border_width_all(1)
		normal.content_margin_left = 12
		normal.content_margin_right = 12
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.23, 0.27, 0.32)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.pressed.connect(_act.bind(str(entry[1])))
		row.add_child(button)
		_buttons.append(button)
	contents.add_child(_label("Arrows / WASD: walk  ·  1–5: strikes  ·  6: walk cycle  ·  Space: spar  ·  F: dialogue  ·  R: reset  ·  Esc: title", 14, Color(0.73, 0.77, 0.83)))
	panel.set_meta("row", row)


func _resize() -> void:
	var vp := get_viewport_rect().size
	var cover := maxf(vp.x / _backdrop.get_width(), vp.y / _backdrop.get_height())
	_background.scale = Vector2.ONE * cover
	_background.position = vp * 0.5
	_actors.position = Vector2((vp.x - 8 * CELL) * 0.5, vp.y * 0.73 - 1.5 * CELL)
	_kai_info.position = Vector2(36, vp.y - 152)
	_serra_info.position = Vector2(vp.x - 260, vp.y - 152)
	var panel := _ui.get_node("Controls") as PanelContainer
	panel.position = Vector2(24, vp.y - 112)
	panel.size = Vector2(vp.x - 48, 100)


func _process(delta: float) -> void:
	_elapsed += delta
	_kai_info.text = "KAI   %d / %d" % [kai.current_hp, kai.max_hp()]
	_serra_info.text = "SERRA   %d / %d" % [serra.current_hp, serra.max_hp()]
	for button in _buttons:
		button.disabled = busy
	if busy or autoplay:
		return
	var horizontal := Input.get_axis("cursor_left", "cursor_right")
	var vertical := Input.get_axis("cursor_up", "cursor_down")
	var direction := Vector2(horizontal, vertical)
	if direction != Vector2.ZERO:
		var destination := kai.cell + Vector2i(int(direction.x), int(direction.y))
		if grid.in_bounds(destination) and destination != serra.cell:
			_walk_to(destination)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")
		return
	var action: String = {KEY_1: "hit", KEY_2: "crit", KEY_3: "miss", KEY_4: "cast", KEY_5: "kill", KEY_6: "walk", KEY_SPACE: "spar", KEY_F: "dialogue", KEY_R: "reset"}.get(event.keycode, "")
	if action != "":
		get_viewport().set_input_as_handled()
		_act(action)


func _walk_to(destination: Vector2i) -> void:
	busy = true
	_status.text = "A walk through the cloister"
	await kai.move_along_path([kai.cell, destination])
	busy = false


func reset_actors() -> void:
	kai.cell = Vector2i(2, 1)
	serra.cell = Vector2i(5, 1)
	for pair in [[kai, _home_kai], [serra, _home_serra]]:
		var actor: Unit = pair[0]
		actor.position = pair[1]
		actor.scale = Vector2.ONE
		actor.rotation = 0.0
		actor.modulate = Color.WHITE
		actor.visible = true
		actor.current_hp = actor.max_hp()
		actor.set_illustrated_pose("idle")
	kai.set_facing(true)
	serra.set_facing(false)


func _act(action: String) -> void:
	if busy:
		return
	_action = action
	if action == "reset":
		reset_actors()
		_status.text = "Ready for another pass."
		return
	if action == "dialogue":
		_show_dialogue()
		return
	busy = true
	reset_actors()
	if action == "walk":
		_status.text = "A walk through the cloister"
		await kai.move_along_path([Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
		await get_tree().create_timer(0.25).timeout
		await kai.move_along_path([Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1)])
		busy = false
		return
	# A readable sparring distance; movement and cell state remain real.
	var approach: Array = [Vector2i(2, 1), Vector2i(3, 1)]
	if action != "cast":
		approach.append(Vector2i(4, 1))
	await kai.move_along_path(approach)
	if action == "spar":
		_status.text = "Sparring  /  resolved combat"
		var result := CombatResolver.resolve(kai.to_combatant(0, 0), serra.to_combatant(0, 0), 1, CombatRNG.new(11))
		for strike in result.strikes:
			var actor: Unit = serra if strike.is_counter else kai
			var target: Unit = kai if strike.is_counter else serra
			await juice.play_strike(actor, target, strike, strike.connected and strike.defender_hp_after <= 0)
			if not target.is_alive():
				await juice.play_death(target)
	else:
		_status.text = {"hit": "Steel meets the guard", "crit": "Critical  /  a decisive strike", "miss": "A sidestep, and a missed blade", "cast": "Crown-light  /  the Ward", "kill": "Defeat  /  the final impact"}.get(action, "Strike")
		var strike := StrikeResult.new()
		strike.connected = action != "miss"
		strike.was_crit = action == "crit"
		strike.damage = serra.current_hp if action == "kill" else (CombatMath.crit_damage(5) if action == "crit" else 5)
		strike.defender_hp_before = serra.current_hp
		strike.defender_hp_after = maxi(0, serra.current_hp - strike.damage) if strike.connected else serra.current_hp
		var original_weapon := kai.weapon()
		if action == "cast":
			kai.equip_weapon(kai.unit_def.extra_weapons[0])
		await juice.play_strike(kai, serra, strike, action == "kill")
		if action == "cast":
			kai.equip_weapon(original_weapon)
		if action == "kill":
			await juice.play_death(serra)
	busy = false


func _show_dialogue() -> void:
	busy = true
	var overlay := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	overlay.add_theme_stylebox_override("panel", style)
	var vp := get_viewport_rect().size
	overlay.position = Vector2(48, vp.y * 0.5)
	overlay.size = Vector2(vp.x - 96, 150)
	_ui.add_child(overlay)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	overlay.add_child(column)
	# Reuse an existing authored line; this presentation WO authors no canon.
	var lines: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/serra_battle_quote.json"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/portraits/portrait_serra.png")
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.custom_minimum_size = Vector2(110, 110)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(_label("SERRA", 18, GOLD))
	var line := _label(str(lines[0].get("text", "")), 22)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(line)
	var close := Button.new()
	close.text = "Return to the terrace"
	close.pressed.connect(func() -> void:
		overlay.queue_free()
		busy = false)
	column.add_child(close)
	close.grab_focus()


func _demo() -> void:
	await get_tree().create_timer(0.6).timeout
	for action in ["walk", "hit", "crit", "miss", "cast", "kill", "spar"]:
		await _act(action)
		await get_tree().create_timer(0.8).timeout
