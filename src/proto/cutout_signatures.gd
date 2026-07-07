extends Node2D
## Showcase: each hero attacks with their own unique signature weapon (the rig
## now prefers assets/art/cutout/<id>/signature.png). One row of fighters, each
## striking a dummy to their right with their signature arm + its motion.

const SCALE := 4.0
const GAP := 150.0

# [unit, weapon_type, label]
const CAST := [
	["kael", WeaponDef.WeaponType.SWORD, "Kael"],
	["brenna", WeaponDef.WeaponType.LANCE, "Brenna"],
	["dain", WeaponDef.WeaponType.AXE, "Dain"],
	["liora", WeaponDef.WeaponType.TOME, "Liora"],
	["wren", WeaponDef.WeaponType.STAFF, "Wren"],
	["fenn", WeaponDef.WeaponType.BOW, "Fenn"],
	["corin", WeaponDef.WeaponType.BOW, "Corin"],
	["rurik", WeaponDef.WeaponType.AXE, "Rurik"],
]

var _rigs: Array = []
var _origins: Array = []
var _aims: Array = []


func _ready() -> void:
	var vw := get_viewport_rect().size.x
	var cols := 4
	var stepx := vw / (cols + 1)
	for i in CAST.size():
		var col := i % cols
		var row := i / cols
		var origin := Vector2(stepx * (col + 1), 150.0 + row * 200.0)
		_origins.append(origin)
		_aims.append(origin + Vector2(GAP, 0))
		var dummy := Sprite2D.new()
		dummy.texture = _target_tex()
		dummy.position = _aims[i]
		dummy.modulate = Color(1, 1, 1, 0.35)
		add_child(dummy)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
		label.position = origin + Vector2(-40, 90)
		label.text = CAST[i][2]
		add_child(label)
		_build(i)
	_loop()


func _build(i: int) -> void:
	if _rigs.size() > i and _rigs[i] != null:
		_rigs[i].queue_free()
	var rig := CombatRig.new()
	add_child(rig)
	rig.position = _origins[i]
	rig.setup(CAST[i][0], CombatRig.Facing.EAST, SCALE)
	rig.set_weapon(CAST[i][1])
	if _rigs.size() > i:
		_rigs[i] = rig
	else:
		_rigs.append(rig)


func _target_tex() -> Texture2D:
	var img := Image.create(20, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.5, 0.55, 1.0))
	return ImageTexture.create_from_image(img)


func _loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while true:
		for i in CAST.size():
			_build(i)
		await get_tree().create_timer(0.3).timeout
		for i in CAST.size():
			_rigs[i].play_attack(CAST[i][1], _aims[i])
		await get_tree().create_timer(1.1).timeout
