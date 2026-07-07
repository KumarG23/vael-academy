extends Node2D
## Directional validation for the on-map rig: one attacker per cardinal/diagonal
## direction, each lunging at a dummy target placed that way. Confirms the rig
## drives toward the real tile (up/down/diagonal) and doesn't spin around to hit
## empty space. Rendered to frames for review.

const SCALE := 4.0
const GAP := 128.0   # one "tile" at cell_size 128

# label, direction (unit) toward the target
const DIRS := [
	["E", Vector2(1, 0)],
	["N", Vector2(0, -1)],
	["S", Vector2(0, 1)],
	["W", Vector2(-1, 0)],
]
const UNIT := "kai"
const WEAPON := WeaponDef.WeaponType.SWORD

var _rigs: Array = []
var _origins: Array = []
var _aims: Array = []


func _ready() -> void:
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	var step := vw / (DIRS.size() + 1)
	for i in DIRS.size():
		var origin := Vector2(step * (i + 1), vh * 0.5)
		_origins.append(origin)
		var aim: Vector2 = origin + (DIRS[i][1] as Vector2) * GAP
		_aims.append(aim)
		var dummy := Sprite2D.new()
		dummy.texture = _target_tex()
		dummy.position = aim
		dummy.modulate = Color(1, 0.6, 0.6, 0.55)
		add_child(dummy)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
		label.position = origin + Vector2(-16, 150)
		label.text = DIRS[i][0]
		add_child(label)
		_build(i)
	_loop()


func _build(i: int) -> void:
	if _rigs.size() > i and _rigs[i] != null:
		_rigs[i].queue_free()
	var rig := CombatRig.new()
	add_child(rig)
	rig.position = _origins[i]
	# 4-way facing like the live path
	var d: Vector2 = _aims[i] - _origins[i]
	var facing: int
	if absf(d.x) >= absf(d.y):
		facing = CombatRig.Facing.EAST if d.x > 0.0 else CombatRig.Facing.WEST
	else:
		facing = CombatRig.Facing.NORTH if d.y < 0.0 else CombatRig.Facing.SOUTH
	rig.setup(UNIT, facing, SCALE)
	rig.set_weapon(WEAPON)
	if _rigs.size() > i:
		_rigs[i] = rig
	else:
		_rigs.append(rig)


func _target_tex() -> Texture2D:
	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.7, 0.4, 0.4, 1.0))
	return ImageTexture.create_from_image(img)


func _loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while true:
		for i in DIRS.size():
			_build(i)
		await get_tree().create_timer(0.3).timeout
		for i in DIRS.size():
			_rigs[i].play_attack(WEAPON, _aims[i])
		await get_tree().create_timer(1.0).timeout
