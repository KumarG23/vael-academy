class_name CombatFX
extends AnimatedSprite2D
## One Combat FX sheet played once as an AnimatedSprite2D, read from sheets/effects.json.
##
##     CombatFX.spawn(self, "red_slash", enemy.global_position)
##     CombatFX.spawn(self, "white_thrust", enemy.global_position, (enemy.position - position).angle())
##
## Each frees itself when done. `angle` turns it: thrusts drive to the right and blocks face a hit
## from the left at angle 0. `sheet_set` is "256", "128" or "pixel" (drawn with nearest
## filtering); CombatFX.default_set picks it for every spawn. The anchor in effects.json (the
## point of a thrust, the hit on a block, the centre of the rest) sits on the node's position.

## Where sheets/ is: found in this folder, or at res://sheets/ as the zip has it. Set it if the
## sheets are elsewhere.
static var sheets_dir := ""
static var default_set := "256"
static var _data: Dictionary = {}
static var _frames: Dictionary = {}

var effect := ""
var sheet_set := ""


## The effect names in the installed sheets, e.g. "red_slash".
static func effects() -> PackedStringArray:
	return PackedStringArray(_effects().keys())


static func info(fx_name: String) -> Dictionary:
	return _effects()[fx_name]


## Adds `fx_name` to `parent` at the global position `at`, turned by `angle`, and plays it.
static func spawn(parent: Node, fx_name: String, at: Vector2, angle := 0.0, set_name := "") -> CombatFX:
	var fx := CombatFX.new()
	fx.setup(fx_name, set_name)
	parent.add_child(fx)
	fx.global_position = at
	fx.global_rotation = angle
	fx.play()
	return fx


## The effect's frames, made once per sheet set and shared.
static func frames_for(fx_name: String, set_name := "") -> SpriteFrames:
	set_name = set_name if set_name else default_set
	var key := set_name + "/" + fx_name
	if key in _frames:
		return _frames[key]
	var e: Dictionary = _effects()[fx_name]
	var sheet: Texture2D = load(sheets_dir.path_join(set_name).path_join(e.file))
	var cell := Vector2(e.cell[set_name][0], e.cell[set_name][1])
	var cols: int = e.columns
	var sf := SpriteFrames.new()
	sf.set_animation_loop(&"default", e.loop)
	sf.set_animation_speed(&"default", e.fps)
	for i in int(e.frames):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(i % cols, floorf(i / float(cols))) * cell, cell)
		sf.add_frame(&"default", atlas)
	_frames[key] = sf
	return sf


static func _effects() -> Dictionary:
	if _data.is_empty():
		if sheets_dir.is_empty():
			var here := "res://addons/combat_fx/sheets/"
			sheets_dir = here if ResourceLoader.exists(here + "effects.json") else "res://sheets/"
		var json: JSON = load(sheets_dir.path_join("effects.json"))
		for e: Dictionary in json.data.effects:
			_data[e.name] = e
	return _data


func setup(fx_name: String, set_name := "") -> void:
	if fx_name not in _effects():
		push_error("CombatFX: no effect %s in %s" % [fx_name, sheets_dir])
		return
	effect = fx_name
	sheet_set = set_name if set_name else default_set
	sprite_frames = frames_for(fx_name, sheet_set)
	var e: Dictionary = _effects()[fx_name]
	var cell := Vector2(e.cell[sheet_set][0], e.cell[sheet_set][1])
	centered = true
	offset = (Vector2(0.5, 0.5) - Vector2(e.anchor[0], e.anchor[1])) * cell
	texture_filter = TEXTURE_FILTER_NEAREST if sheet_set == "pixel" else TEXTURE_FILTER_LINEAR
	if not animation_finished.is_connected(queue_free):
		animation_finished.connect(queue_free)
