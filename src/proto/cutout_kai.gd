extends Node2D
## Showcase for the on-map cut-out attack rig (battle direction v2). Drives the
## real CombatRig through all six weapon types — sword slash, lance thrust, axe
## chop, bow shot, tome bolt, staff heal — so the animations can be reviewed
## (rendered to GIFs for the claude.ai gallery). A dummy target sits to the
## right so ranged projectiles have somewhere to fly.

const SCALE := 5.0
const REACH := 90.0

var _rig: CombatRig
var _label: Label
var _t := 0.0
var _origin: Vector2

const SEQ := [
	[WeaponDef.WeaponType.SWORD, "SWORD — slash"],
	[WeaponDef.WeaponType.LANCE, "LANCE — thrust"],
	[WeaponDef.WeaponType.AXE, "AXE — overhead chop"],
	[WeaponDef.WeaponType.BOW, "BOW — arrow"],
	[WeaponDef.WeaponType.TOME, "TOME — magic bolt"],
	[WeaponDef.WeaponType.STAFF, "STAFF — heal bloom"],
]


func _ready() -> void:
	_origin = Vector2(get_viewport_rect().size.x * 0.42, get_viewport_rect().size.y * 0.62)
	_build_rig(WeaponDef.WeaponType.SWORD)
	# a faint dummy target to the right so ranged shots have a destination
	var dummy := Sprite2D.new()
	dummy.texture = _placeholder_target()
	dummy.position = _origin + Vector2(REACH * SCALE, -30)
	dummy.modulate = Color(1, 1, 1, 0.5)
	add_child(dummy)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(40, 28)
	add_child(_label)
	_loop()


func _build_rig(wt: int) -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = CombatRig.new()
	add_child(_rig)
	_rig.position = _origin
	_rig.setup("kai", true, SCALE)
	_rig.set_weapon(wt)


func _process(delta: float) -> void:
	_t += delta
	if _rig != null:
		_rig.position.y = _origin.y + sin(_t * 2.2) * 3.0


func _placeholder_target() -> Texture2D:
	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.55, 1.0))
	return ImageTexture.create_from_image(img)


func _loop() -> void:
	await get_tree().create_timer(0.6).timeout
	while true:
		for entry in SEQ:
			_build_rig(entry[0])
			_label.text = "Kai — " + entry[1]
			await get_tree().create_timer(0.35).timeout
			await _rig.play_attack(entry[0], _origin + Vector2(REACH * SCALE, -30))
			await get_tree().create_timer(0.6).timeout
