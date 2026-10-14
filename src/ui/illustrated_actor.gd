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


func setup(art: IllustratedArt, actor_feet: Vector2, actor_height: float) -> void:
	kit = art
	feet = actor_feet
	height = actor_height
	body = Sprite2D.new()
	add_child(body)
	_refresh()


func _process(delta: float) -> void:
	if walking and not _was_walking:
		_clock = 0.0
	_was_walking = walking
	_clock += delta
	_refresh()


func _refresh() -> void:
	if kit == null or body == null:
		return
	var frame := pose
	if walking and not kit.walk_names.is_empty():
		frame = kit.walk_names[int(_clock * kit.walk_fps) % kit.walk_names.size()]
	kit.apply(body, frame, feet, height)
	body.scale.x *= 1.0 if face_right else -1.0
	if not walking and pose == "idle":
		body.position.y -= (sin(_clock * 2.2) + 1.0) * height * 0.003
