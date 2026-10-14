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
var _mark_material: ShaderMaterial


func setup(art: IllustratedArt, actor_feet: Vector2, actor_height: float) -> void:
	kit = art
	feet = actor_feet
	height = actor_height
	body = Sprite2D.new()
	add_child(body)
	_last_position = global_position
	if not kit.crown_marks.is_empty():
		_mark_material = ShaderMaterial.new()
		_mark_material.shader = preload("res://src/ui/illustrated_crown_facing.gdshader")
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
	body.material = _mark_material if not face_right and kit.crown_marks.has(frame) else null
	if body.material != null:
		var source: Rect2 = kit.crown_marks[frame]
		var target := Rect2(source.position + Vector2(-32, 3), source.size)
		_mark_material.set_shader_parameter("source_mark", Vector4(source.position.x, source.position.y, source.size.x, source.size.y))
		_mark_material.set_shader_parameter("target_mark", Vector4(target.position.x, target.position.y, target.size.x, target.size.y))
		_mark_material.set_shader_parameter("skin_sample", source.get_center() + Vector2(-14, 2))
