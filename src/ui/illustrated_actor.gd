class_name IllustratedActor
extends Node2D
## CP-2 persistent illustrated actor: walk frames + gentle breathing, with the
## same art/foot geometry as its temporary CombatRig. No gameplay ownership.

var kit: IllustratedArt
var body: Sprite2D
var feet := Vector2.ZERO
var height := 150.0
var walking := false
var face_right := true
var pose := "idle"
var _clock := 0.0
var _was_walking := false
var _walk_distance := 0.0
var _last_position := Vector2.ZERO
var west_head: Sprite2D
var _head_mask: ShaderMaterial


func setup(art: IllustratedArt, actor_feet: Vector2, actor_height: float) -> void:
	kit = art
	feet = actor_feet
	height = actor_height
	body = Sprite2D.new()
	add_child(body)
	_last_position = global_position
	if kit.textures.has("head_west"):
		west_head = Sprite2D.new()
		west_head.texture = kit.textures["head_west"]
		west_head.centered = false
		west_head.offset = Vector2(-64, -122)
		west_head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(west_head)
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform float head_cut_y; void fragment() { if (UV.y < head_cut_y) { COLOR.a = 0.0; } }"
		_head_mask = ShaderMaterial.new()
		_head_mask.shader = shader
	_refresh()


func _process(delta: float) -> void:
	if walking and not _was_walking:
		_walk_distance = 0.0
	if walking:
		_walk_distance += global_position.distance_to(_last_position)
	_last_position = global_position
	_was_walking = walking
	_clock += delta
	_refresh()


func _refresh() -> void:
	if kit == null or body == null:
		return
	var frame := pose
	if walking and not kit.walk_names.is_empty():
		var phase := _walk_distance / (height * kit.walk_stride_height)
		frame = kit.walk_names[int(phase * kit.walk_names.size()) % kit.walk_names.size()]
	kit.apply(body, frame, feet, height)
	body.scale.x *= 1.0 if face_right else -1.0
	if not walking and pose == "idle":
		body.position.y -= (sin(_clock * 2.2) + 1.0) * height * 0.003
	if west_head != null:
		west_head.visible = not face_right and kit.head_anchors.has(frame)
		body.material = _head_mask if west_head.visible else null
		if west_head.visible:
			var anchor: Vector2 = kit.head_anchors[frame]
			_head_mask.set_shader_parameter("head_cut_y", (anchor.y - 5.0) / float(body.texture.get_height()))
			west_head.position = body.position + (anchor - kit.foot_for(frame)) * body.scale
			# The separate head was drawn facing left, with the mark over its
			# anatomical left brow. Its texture never receives the body's flip.
			west_head.scale = Vector2.ONE * absf(body.scale.y)
