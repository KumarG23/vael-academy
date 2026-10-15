class_name ActiveDefensePilot
extends BattleView
## CP-9: local single incoming strike; no campaign/progression/save integration.
signal window_opened
signal judged(report: Dictionary)
signal trial_finished
var kai: Unit
var serra: Unit
var presentation: ActiveDefensePresentation
var trial: ActiveDefenseTrial
var last_base: StrikeResult
var last_result: CombatResult
var last_report: Dictionary = {}
var settings: Dictionary
var practice := true
var auto_block := false
var _cue_played := false
var _panel: Node2D
var _meter: Control
var _status: Label
var _forecast: Label
var _dodge_button: Button
var _block_button: Button
var _again_button: Button
var _practice_button: CheckButton
var _assist_button: CheckButton


func _ready() -> void:
	dialogue_enabled = false
	super._ready()
	_cursor.active = false
	_cursor.set_process(false)
	_debug_label.visible = false
	_objective_label.visible = false
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/proto/active_defense.json"))
	presentation = ActiveDefensePresentation.new()
	presentation.comparison_labels = false
	presentation.stage_title = "DEFENSE PRACTICE"
	add_child(presentation)
	# Local copy only: the production timing dictionary is untouched.
	presentation.presentation_data = presentation.presentation_data.duplicate(true)
	presentation.juice.presentation_data = presentation.presentation_data
	var defense := presentation.juice as ActiveDefenseJuice
	defense.window_opened.connect(func() -> void:
		_cue_played = false
		_status.text = "Watch the marker. Defend as it reaches the gold line."
		window_opened.emit())
	defense.judged.connect(_on_judged)
	_build_controls()


func _spawn_units() -> void:
	for spawn: UnitSpawn in chapter.player_spawns + chapter.enemy_spawns:
		var definition := spawn.unit.duplicate() as UnitDef
		definition.team = spawn.team_override if spawn.team_override >= 0 else definition.team
		var actor := add_unit(definition, spawn.cell)
		if definition.id == "kai":
			kai = actor
			_lord_unit = actor
		else:
			serra = actor


func _begin_battle() -> void:
	_phase = Phase.IDLE
	_cursor.active = false


func _check_objective() -> void:
	pass


func begin_trial() -> void:
	if _busy:
		return
	_busy = true
	for unit: Unit in [kai, serra]:
		unit.current_hp = unit.max_hp()
		unit.visible = true
		unit.queue_redraw()
	var profile: Dictionary = settings["practice" if practice else "normal"]
	trial = ActiveDefenseTrial.new(profile)
	var defense := presentation.juice as ActiveDefenseJuice
	defense.trial = trial
	defense.report = {}
	defense.block_fraction = float(settings["block_damage_fraction"])
	presentation.presentation_data["timing"]["windup"] = profile["windup"]
	# Native hit/crit/triangle/terrain calculation; retain ONLY the first incoming
	# strike. No stale precomputed counters after player-altered HP.
	var native := CombatResolver.resolve(_combatant_for(serra, serra.cell), _combatant_for(kai, kai.cell), 1, CombatRNG.new(0))
	last_base = native.strikes[0]
	assert(last_base.connected and not last_base.was_crit and last_base.defender_hp_after > 0)
	defense.base_strike = last_base
	last_result = CombatResult.new()
	last_result.attacker_name = native.attacker_name
	last_result.defender_name = native.defender_name
	last_result.attacker_hp_after = serra.current_hp
	last_result.defender_hp_after = last_base.defender_hp_after
	last_result.strikes.append(ActiveDefenseTrial.copy_strike(last_base))
	last_report = {}
	_status.modulate = Color.WHITE
	_forecast.text = "INCOMING %d  ·  DODGE 0  ·  BLOCK %d  ·  One strike / no counter" % [last_base.damage, ceili(last_base.damage * defense.block_fraction)]
	_status.text = "Serra is preparing a thrust…"
	await presentation.play_exchange(serra, kai, last_result, _ui_layer)
	_busy = false
	trial_finished.emit()


func attempt(action: String) -> bool:
	var defense := presentation.juice as ActiveDefenseJuice
	if not _busy or not defense._window or trial == null:
		return false
	if not trial.attempt(action):
		return false
	_status.text = "%s queued — one attempt per strike" % action.to_upper()
	return true


func _on_judged(report: Dictionary) -> void:
	last_report = report
	var strike: StrikeResult = report["strike"]
	last_result.defender_hp_after = strike.defender_hp_after
	var result: String = report["result"]
	var detail := ""
	if report["action"] != "":
		detail = " · %d ms %s" % [roundi(absf(float(report["offset"])) * 1000.0), "early" if report["offset"] < 0.0 else "late"]
	_status.text = {"dodge": "DODGED · 0 damage", "block": "BLOCKED · %d damage" % strike.damage, "no_input": "NO DEFENSE · %d damage" % strike.damage, "failed": "TIMING MISSED · %d damage" % strike.damage, "native_miss": "Serra missed"}[result] + (" · ASSIST" if report["assisted"] else detail)
	_status.modulate = Color("a3efc5") if result == "dodge" else (Color("f2d08c") if result == "block" else Color("ffb8a9"))
	if result == "dodge":
		AudioManager.play_sfx("defense_dodge")
	judged.emit(report)


func _process(delta: float) -> void:
	super._process(delta)
	if _panel == null:
		return
	_panel.scale = Vector2.ONE * minf(get_viewport_rect().size.x / 1280.0, get_viewport_rect().size.y / 720.0)
	var defense := presentation.juice as ActiveDefenseJuice
	if trial != null and defense._window:
		trial.advance(delta, auto_block)
		if not _cue_played and trial.elapsed >= float(trial.settings["cue"]):
			_cue_played = true
			AudioManager.play_sfx("defense_cue")
	_meter.visible = _busy
	_meter.queue_redraw()
	_dodge_button.disabled = not defense._window
	_block_button.disabled = not defense._window
	_again_button.disabled = _busy
	_practice_button.disabled = _busy
	_assist_button.disabled = _busy


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q: attempt("dodge")
		KEY_E: attempt("block")
		KEY_SPACE: begin_trial()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")
			return
		_: return
	get_viewport().set_input_as_handled()


func _button(text: String, x: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, 576)
	button.size = Vector2(115, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_panel.add_child(button)
	return button


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	_panel = Node2D.new()
	layer.add_child(_panel)
	_forecast = IllustratedCombatPresentation.label("SINGLE INCOMING STRIKE · Q dodge / E block · Space start / retry · Esc title", Vector2(210, 14), 17, Color("e9d4a4"))
	var background := ColorRect.new()
	background.position = Vector2(0, 0)
	background.size = Vector2(1280, 44)
	background.color = Color("101a25")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(background)
	_panel.add_child(_forecast)
	_status = IllustratedCombatPresentation.label("Press Space to practice. One input per strike; practice rules only.", Vector2(220, 174), 18, Color("f2d9a2"))
	_status.add_theme_color_override("font_outline_color", Color("101a25"))
	_status.add_theme_constant_override("outline_size", 6)
	_panel.add_child(_status)
	_meter = Control.new()
	_meter.position = Vector2(340, 130)
	_meter.size = Vector2(600, 32)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_meter)
	_meter.draw.connect(_draw_meter)
	var controls_back := ColorRect.new()
	controls_back.position = Vector2(455, 570)
	controls_back.size = Vector2(380, 120)
	controls_back.color = Color(0.035, 0.065, 0.10, 0.95)
	controls_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(controls_back)
	_dodge_button = _button("Q · Dodge", 470, func() -> void: attempt("dodge"))
	_block_button = _button("E · Block", 590, func() -> void: attempt("block"))
	_again_button = _button("Space · Again", 710, begin_trial)
	_dodge_button.add_theme_color_override("font_color", Color("a3efc5"))
	_block_button.add_theme_color_override("font_color", Color("f2d08c"))
	_practice_button = CheckButton.new()
	_practice_button.text = "Wide practice windows"
	_practice_button.button_pressed = true
	_practice_button.position = Vector2(465, 617)
	_practice_button.focus_mode = Control.FOCUS_NONE
	_practice_button.toggled.connect(func(enabled: bool) -> void: practice = enabled)
	_panel.add_child(_practice_button)
	_assist_button = CheckButton.new()
	_assist_button.text = "Auto-block assist"
	_assist_button.position = Vector2(465, 652)
	_assist_button.focus_mode = Control.FOCUS_NONE
	_assist_button.toggled.connect(func(enabled: bool) -> void: auto_block = enabled)
	_panel.add_child(_assist_button)


func _draw_meter() -> void:
	if trial == null:
		return
	var duration := float(trial.settings["windup"])
	var cue := float(trial.settings["cue"])
	_meter.draw_rect(Rect2(0, 0, 600, 32), Color("111b29"))
	for pair: Array in [["block", Color("b68c42")], ["dodge", Color("2e775c")]]:
		var width := float(trial.settings[str(pair[0]) + "_window"])
		var left := maxf(0.0, (cue - width) / duration) * 600.0
		var right := minf(1.0, (cue + width) / duration) * 600.0
		_meter.draw_rect(Rect2(left, 3, right - left, 26), pair[1])
	_meter.draw_line(Vector2(cue / duration * 600, 0), Vector2(cue / duration * 600, 32), Color("fff3c1"), 3)
	var cursor := clampf(trial.elapsed / duration, 0, 1) * 600
	_meter.draw_circle(Vector2(cursor, 16), 7, Color.WHITE)
