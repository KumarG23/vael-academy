extends Node2D
## Roster validation for the weaponless-body pass (battle direction v2). Drives
## three freshly-stripped Emberwing map sprites through the real CombatRig with
## their weapons — dain axe-chop, kael sword-slash, brenna lance-stab — side by
## side, so the weaponless body_map.png files + weapon grips can be reviewed in
## the actual rig (rendered to a GIF for the claude.ai gallery).

const SCALE := 5.0
const REACH := 88.0

# [unit_id, weapon_type, label]
const ROSTER := [
	["dain", WeaponDef.WeaponType.AXE, "Dain — axe"],
	["kael", WeaponDef.WeaponType.SWORD, "Kael — sword"],
	["brenna", WeaponDef.WeaponType.LANCE, "Brenna — lance"],
]

var _rigs: Array = []
var _origins: Array = []
var _t := 0.0


func _ready() -> void:
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	var step := vw / (ROSTER.size() + 1)
	for i in ROSTER.size():
		var entry: Array = ROSTER[i]
		var origin := Vector2(step * (i + 1), vh * 0.6)
		_origins.append(origin)
		# a faint dummy target to the right of each so the strike has a direction
		var dummy := Sprite2D.new()
		dummy.texture = _target_tex()
		dummy.position = origin + Vector2(REACH * 0.9, -30)
		dummy.modulate = Color(1, 1, 1, 0.4)
		add_child(dummy)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		label.add_theme_constant_override("outline_size", 5)
		label.position = origin + Vector2(-90, 150)
		label.text = entry[2]
		add_child(label)
		_build_rig(i)
	_loop()


func _build_rig(i: int) -> void:
	var entry: Array = ROSTER[i]
	if _rigs.size() > i and _rigs[i] != null:
		_rigs[i].queue_free()
	var rig := CombatRig.new()
	add_child(rig)
	rig.position = _origins[i]
	rig.setup(entry[0], true, SCALE)
	rig.set_weapon(entry[1])
	if _rigs.size() > i:
		_rigs[i] = rig
	else:
		_rigs.append(rig)


func _process(delta: float) -> void:
	_t += delta
	for i in _rigs.size():
		if _rigs[i] != null:
			_rigs[i].position.y = _origins[i].y + sin(_t * 2.2 + i) * 3.0


func _target_tex() -> Texture2D:
	var img := Image.create(22, 38, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.55, 1.0))
	return ImageTexture.create_from_image(img)


func _loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while true:
		for i in ROSTER.size():
			_build_rig(i)
		await get_tree().create_timer(0.3).timeout
		for i in ROSTER.size():
			await _rigs[i].play_attack(ROSTER[i][1], _origins[i] + Vector2(REACH * 0.9, -30))
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.5).timeout
