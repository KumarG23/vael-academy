class_name IllustratedCombatPresentation
extends CanvasLayer
## CP-6: result replay only. No resolver calls, RNG, XP, durability or saves.
## Call with existing Units + their already resolved CombatResult.
signal beat(name: String)
signal impact_applied(target: Unit, strike: StrikeResult)
const DATA := "res://data/presentation/illustrated_combat.json"
const SIZE := Vector2(1280, 720)
const GOLD := Color("d8bd80")
var presentation_data: Dictionary
var comparison_labels := true
var stage_title := "THE SUNLIT CLOISTER"
var busy := false
var world: Node2D
var juice: IllustratedCombatJuice
var effects: IllustratedCombatFX
var actors: Array[Unit] = []
var sources: Array[Unit] = []
var current_beat := "map"
var _stage: Node2D
var _backdrop: Sprite2D
var _veil: ColorRect
var _hud: Node2D
var _headline: Label
var _subhead: Label
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _shadows: Array[Polygon2D] = []
var _map_layer: CanvasLayer


func _ready() -> void:
	layer = 60
	presentation_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_stage = Node2D.new()
	add_child(_stage)
	world = Node2D.new()
	_stage.add_child(world)
	_backdrop = Sprite2D.new()
	_backdrop.texture = load("res://assets/art/illustrated_pilot/courtyard.png")
	_backdrop.position = SIZE * 0.5
	_backdrop.scale = Vector2.ONE * maxf(SIZE.x / _backdrop.texture.get_width(), SIZE.y / _backdrop.texture.get_height())
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.modulate = Color(1.0, 0.98, 0.94)
	world.add_child(_backdrop)
	# Shaded foreground and subtle letterbox keep silhouettes legible.
	_hud = Node2D.new()
	_stage.add_child(_hud)
	var shade := ColorRect.new()
	shade.size = SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/ui/illustrated_combat/stage_shade.gdshader")
	shade.material = material
	_hud.add_child(shade)
	for y: float in [0.0, 568.0]:
		var bar := ColorRect.new()
		bar.color = Color(0.025, 0.035, 0.055, 0.95)
		bar.position = Vector2(0, y)
		bar.size = Vector2(1280, 48 if y == 0 else 152)
		_hud.add_child(bar)
		var line := ColorRect.new()
		line.color = GOLD.darkened(0.5)
		line.position = Vector2(0, 48 if y == 0 else y)
		line.size = Vector2(1280, 1)
		_hud.add_child(line)
	_headline = label(stage_title.to_upper(), Vector2(240, 66), 24, GOLD)
	_headline.size.x = 800
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_headline)
	_subhead = label("", Vector2(320, 104), 16, Color(0.82, 0.85, 0.86))
	_subhead.size.x = 640
	_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_subhead)
	_hud.add_child(label("VAEL ACADEMY", Vector2(44, 14), 15, GOLD))
	_hud.add_child(label("B  /  ILLUSTRATED KEY POSES" if comparison_labels else "ILLUSTRATED COMBAT", Vector2(920, 14), 15, GOLD))
	var credits := label("Combat / Spell FX: heyheythere · CC BY 4.0   |   Particles: Kenney · CC0", Vector2(330, 695), 12, Color(0.60, 0.65, 0.70))
	_hud.add_child(credits)
	effects = IllustratedCombatFX.new()
	effects.z_index = 20
	world.add_child(effects)
	juice = _make_juice()
	juice.presentation_data = presentation_data
	juice.effects = effects
	juice.shake_layer = world
	var config := JuiceConfig.new()
	# Whole illustrations retain anatomy; reactions use pose + translation.
	config.squash = 0.0
	config.stagger_wobble = 0.0
	config.flinch_distance = 14.0
	config.stagger_distance = 32.0
	config.knockback_distance = 60.0
	config.splash_on_crit = false
	config.splash_on_kill = false
	config.number_rise = 42.0
	config.number_time = 0.55
	add_child(juice)
	juice.setup(config, null, effects, null)
	juice.beat.connect(_beat)
	juice.contact.connect(_contact)
	_veil = ColorRect.new()
	_veil.color = Color(0.015, 0.025, 0.035, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_stage.visible = false
	_resize()
	get_viewport().size_changed.connect(_resize)


func _make_juice() -> IllustratedCombatJuice:
	return IllustratedCombatJuice.new()


static func label(text: String, at: Vector2, size: int, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func supports_exchange(attacker: Unit, defender: Unit) -> bool:
	# One approved pairing, in its authored orientation. An axe, unapproved spell,
	# promoted design or another character must not borrow a misleading painting.
	var pair: Array[Unit] = []
	pair.assign([attacker, defender] if attacker.unit_id() == "kai" else [defender, attacker])
	if pair[0].unit_id() != "kai" or pair[1].unit_id() != "serra" or pair[0].team != 0 or pair[1].team != 1:
		return false
	for unit in pair:
		var record: Dictionary = presentation_data["characters"][unit.unit_id()]
		if unit.current_class() != unit.unit_def.char_class or unit.weapon() == null or unit.weapon().id not in record["weapons"]:
			return false
		var kit := IllustratedArt.from_directory(str(record["art"]))
		if kit == null:
			return false
		for pose: String in ["idle", "action", "parry_hit", "cast", "defeat"]:
			if not kit.textures.has(pose):
				return false
	return true


func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / SIZE.x, viewport_size.y / SIZE.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (viewport_size - SIZE * factor) * 0.5
	_veil.size = viewport_size


func _beat(name: String) -> void:
	current_beat = name
	beat.emit(name)


func _contact(target: Unit, strike: StrikeResult) -> void:
	var index := actors.find(target)
	if strike.connected:
		sources[index].set_hp(strike.defender_hp_after)
		var drain := create_tween()
		drain.tween_property(_hp_bars[index], "value", float(strike.defender_hp_after), 0.22)
		_hp_labels[index].text = "%02d / %02d" % [strike.defender_hp_after, target.max_hp()]
	impact_applied.emit(sources[index], strike)


func _make_actor(source: Unit, index: int) -> Unit:
	var record: Dictionary = presentation_data["characters"][source.unit_id()]
	var actor := Unit.new()
	var definition := source.unit_def.duplicate() as UnitDef
	definition.max_hp = source.max_hp()
	actor.setup(definition, Grid.new(1, 1, 32), Vector2i.ZERO)
	world.add_child(actor)
	actor.current_hp = source.current_hp
	actor.equip_weapon(source.weapon())
	actor.show_map_ui = false
	actor.set_illustrated_art(record["art"], float(record["height"]))
	actor.set_facing(index == 0)
	actor.position = Vector2(450 if index == 0 else 830, 520 - CombatRig.MAP_FOOT + 1.92)
	actor.z_index = 5 + index
	# Separate ground shadow: never deforms the artwork.
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for point in range(48):
		points.append(Vector2.from_angle(TAU * point / 48.0) * Vector2(60, 9))
	shadow.polygon = points
	shadow.color = Color(0.025, 0.02, 0.025, 0.28)
	shadow.position = Vector2(actor.position.x, 520)
	world.add_child(shadow)
	shadow.set_meta("actor_shadow", true)
	_shadows.append(shadow)
	return actor


func _build_plates() -> void:
	for index in range(2):
		var actor := actors[index]
		var x := 64.0 if index == 0 else 850.0
		var plate := Node2D.new()
		plate.set_meta("actor_plate", true)
		_hud.add_child(plate)
		plate.add_child(label(actor.unit_def.display_name.to_upper(), Vector2(x, 582), 27, GOLD))
		plate.add_child(label(actor.weapon().display_name, Vector2(x, 619), 15, Color(0.71, 0.76, 0.81)))
		var hp := ProgressBar.new()
		hp.position = Vector2(x, 652)
		hp.size = Vector2(280, 10)
		hp.max_value = actor.max_hp()
		hp.value = actor.current_hp
		hp.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("77c6a0") if index == 0 else Color("81b9db")
		var back := StyleBoxFlat.new()
		back.bg_color = Color("23303a")
		hp.add_theme_stylebox_override("fill", fill)
		hp.add_theme_stylebox_override("background", back)
		hp.size = Vector2(280, 8)
		plate.add_child(hp)
		_hp_bars.append(hp)
		var value := label("%02d / %02d" % [actor.current_hp, actor.max_hp()], Vector2(x + 290, 643), 18, Color.WHITE)
		plate.add_child(value)
		_hp_labels.append(value)


func play_exchange(attacker: Unit, defender: Unit, result: CombatResult, map_ui: CanvasLayer = null) -> void:
	if busy:
		return
	busy = true
	_map_layer = map_ui
	# Player remains left even for an enemy-initiated exchange; Kai never needs
	# an invented reverse-side face/Crown-mark view in this pilot.
	sources.assign([attacker, defender] if attacker.team == 0 else [defender, attacker])
	actors.clear()
	for index in range(2):
		actors.append(_make_actor(sources[index], index))
	_build_plates()
	_beat("enter")
	await _fade(1.0, 0.18)
	if _map_layer != null:
		_map_layer.visible = false
	_stage.visible = true
	await _fade(0.0, 0.18)
	_beat("establish")
	await get_tree().create_timer(0.28).timeout
	for strike: StrikeResult in result.strikes:
		var striker_source := defender if strike.is_counter else attacker
		var target_source := attacker if strike.is_counter else defender
		var striker := actors[sources.find(striker_source)]
		var target := actors[sources.find(target_source)]
		_subhead.text = striker.unit_def.display_name.to_upper() + "  /  " + striker.weapon().display_name.to_upper()
		if strike.was_crit:
			_subhead.text += "  /  CRITICAL"
		await juice.play_strike(striker, target, strike, strike.connected and strike.defender_hp_after <= 0)
		if not target.is_alive():
			await juice.play_death(target)
		await get_tree().create_timer(0.16).timeout
	_beat("settle")
	await get_tree().create_timer(0.32).timeout
	await _fade(1.0, 0.18)
	_stage.visible = false
	if _map_layer != null:
		_map_layer.visible = true
	for index in range(2):
		sources[index].visible = sources[index].is_alive()
	for actor in actors:
		actor.free()
	actors.clear()
	for child in world.get_children():
		if child.has_meta("actor_shadow"):
			child.free()
	for child in _hud.get_children():
		if child.has_meta("actor_plate"):
			child.free()
	_hp_bars.clear()
	_hp_labels.clear()
	_shadows.clear()
	for child in effects.get_children():
		child.queue_free()
	effects.rings.clear()
	await _fade(0.0, 0.18)
	_beat("map")
	busy = false


func _process(_delta: float) -> void:
	for index in range(actors.size()):
		var at := actors[index].position
		if actors[index] == juice.active_striker and is_instance_valid(juice.current_rig):
			at = juice.current_rig.position
		_shadows[index].position.x = at.x
		_shadows[index].modulate.a = actors[index].modulate.a


func _fade(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", alpha, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
