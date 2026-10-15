class_name SpellFX
extends AnimatedSprite2D
## One Spell FX sheet played as an AnimatedSprite2D, read from sheets/effects.json.
##
##     SpellFX.spawn(self, "fire_impact", enemy.global_position)
##     var aura := SpellFX.spawn(player, "holy_aura", player.global_position)  # loops until finish()
##     SpellFX.fly(self, "ice", $Wand.global_position, target.global_position)  # bolt, then impact
##
## One-shots free themselves when done. `sheet_set` is "256", "128" or "pixel" (drawn with
## nearest filtering); SpellFX.default_set picks it for every spawn. The anchor in effects.json
## (feet for auras and pillars, the head for bolts) sits on the node's position.

## Where sheets/ is: found in this folder, or at res://sheets/ as the zip has it. Set it if the
## sheets are elsewhere.
static var sheets_dir := ""
static var default_set := "256"
static var _data: Dictionary = {}
static var _frames: Dictionary = {}

var effect := ""
var sheet_set := ""
var _fading: Tween


## The effect names in the installed sheets, e.g. "fire_bolt".
static func effects() -> PackedStringArray:
	return PackedStringArray(_effects().keys())


## Adds `fx_name` to `parent` at the global position `at` and plays it.
static func spawn(parent: Node, fx_name: String, at: Vector2, set_name := "") -> SpellFX:
	var fx := SpellFX.new()
	fx.setup(fx_name, set_name)
	parent.add_child(fx)
	fx.global_position = at
	fx.play()
	return fx


## Sends `<element>_bolt` from `from` to `to` at `speed` pixels a second and plays
## `<element>_impact` where it lands. Returns the bolt.
static func fly(parent: Node, element: String, from: Vector2, to: Vector2, speed := 700.0,
		set_name := "") -> SpellFX:
	var bolt := spawn(parent, element + "_bolt", from, set_name)
	bolt.global_rotation = (to - from).angle()
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", to, from.distance_to(to) / speed)
	tween.finished.connect(func() -> void:
		if (element + "_impact") in _effects():
			spawn(parent, element + "_impact", to, bolt.sheet_set)
		bolt.queue_free())
	return bolt


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


static func info(fx_name: String) -> Dictionary:
	return _effects()[fx_name]


static func _effects() -> Dictionary:
	if _data.is_empty():
		if sheets_dir.is_empty():
			var here := "res://addons/spell_fx/sheets/"
			sheets_dir = here if ResourceLoader.exists(here + "effects.json") else "res://sheets/"
		var json: JSON = load(sheets_dir.path_join("effects.json"))
		for e: Dictionary in json.data.effects:
			_data[e.name] = e
	return _data


func setup(fx_name: String, set_name := "") -> void:
	if fx_name not in _effects():
		push_error("SpellFX: no effect %s in %s" % [fx_name, sheets_dir])
		return
	effect = fx_name
	sheet_set = set_name if set_name else default_set
	sprite_frames = frames_for(fx_name, sheet_set)
	var e: Dictionary = _effects()[fx_name]
	var cell := Vector2(e.cell[sheet_set][0], e.cell[sheet_set][1])
	centered = true
	offset = (Vector2(0.5, 0.5) - Vector2(e.anchor[0], e.anchor[1])) * cell
	texture_filter = TEXTURE_FILTER_NEAREST if sheet_set == "pixel" else TEXTURE_FILTER_LINEAR
	if not e.loop and not animation_finished.is_connected(queue_free):
		animation_finished.connect(queue_free)


func is_loop() -> bool:
	return bool(_effects()[effect].loop)


## Fades out over `fade` seconds and frees the node: how loops end.
func finish(fade := 0.25) -> void:
	if _fading or not is_inside_tree():
		return
	_fading = create_tween()
	_fading.tween_property(self, "modulate:a", 0.0, fade)
	_fading.finished.connect(queue_free)
