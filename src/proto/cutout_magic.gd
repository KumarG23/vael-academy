extends Node2D
const SCALE := 4.0
const GAP := 130.0
const CAST := [
	["liora", WeaponDef.WeaponType.TOME, "Liora — flame"],
	["isolde", WeaponDef.WeaponType.TOME, "Isolde — reason"],
	["corvin", WeaponDef.WeaponType.TOME, "Corvin — nature"],
	["wren", WeaponDef.WeaponType.STAFF, "Wren — amber"],
	["elowen", WeaponDef.WeaponType.STAFF, "Elowen — tide"],
	["vesper", WeaponDef.WeaponType.STAFF, "Vesper — green"],
]
var _rigs: Array = []
var _origins: Array = []
var _aims: Array = []
func _ready() -> void:
	var vw := get_viewport_rect().size.x
	var cols := 3
	var stepx := vw / (cols + 1)
	for i in CAST.size():
		var origin := Vector2(stepx * (i % cols + 1), 150.0 + (i / cols) * 210.0)
		_origins.append(origin); _aims.append(origin + Vector2(GAP, 0))
		var d := Sprite2D.new(); d.texture = _tt(); d.position = _aims[i]; d.modulate = Color(1,1,1,0.35); add_child(d)
		var l := Label.new(); l.add_theme_font_size_override("font_size", 18); l.add_theme_color_override("font_color", Color(0.98,0.92,0.6)); l.position = origin + Vector2(-46, 92); l.text = CAST[i][2]; add_child(l)
		_build(i)
	_loop()
func _build(i: int) -> void:
	if _rigs.size() > i and _rigs[i] != null: _rigs[i].queue_free()
	var r := CombatRig.new(); add_child(r); r.position = _origins[i]
	r.setup(CAST[i][0], CombatRig.Facing.EAST, SCALE); r.set_weapon(CAST[i][1])
	if _rigs.size() > i: _rigs[i] = r
	else: _rigs.append(r)
func _tt() -> Texture2D:
	var img := Image.create(20, 36, false, Image.FORMAT_RGBA8); img.fill(Color(0.5,0.5,0.55,1)); return ImageTexture.create_from_image(img)
func _loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while true:
		for i in CAST.size(): _build(i)
		await get_tree().create_timer(0.3).timeout
		for i in CAST.size(): _rigs[i].play_attack(CAST[i][1], _aims[i])
		await get_tree().create_timer(1.2).timeout
