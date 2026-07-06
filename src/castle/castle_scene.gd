class_name CastleScene
extends Node2D
## WO-6.1: the walkable castle shell (§4 — the game's main attraction).
## Side-view painted rooms; the player walks Kai between them, doors carry
## room to room, and interaction spots trigger dialogues (6.2a wires the
## room FUNCTIONS — training, deploy, save — onto these hooks).

signal room_changed(room_id: String)
signal spot_activated(spot_id: String)

const ROOM_DIR := "res://data/castle"
const START_ROOM := "entrance"
const AVATAR_SCALE := 3.5
const WALK_SPEED := 300.0
const CLIMB_SPEED := 150.0
const PROMPT_RANGE := 0.06  # fraction of screen width

## Set by the hub (or tests) before entering; falls back to START_ROOM.
static var next_room: String = ""
static var next_spawn_x: float = -1.0

var room: RoomDef
var _rooms: Dictionary = {}
var _backdrop: TextureRect
var _avatar: AnimatedSprite2D
var _avatar_pos: Vector2
var _prompt: Label
var _dialogue: DialogueScene = null
var _nearest: Resource = null  # RoomExit or RoomSpot in range


func _ready() -> void:
	_load_rooms()
	_backdrop = TextureRect.new()
	# Controls under a Node2D have no parent rect — size explicitly.
	_backdrop.size = get_viewport_rect().size
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_backdrop)
	_avatar = AnimatedSprite2D.new()
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar.scale = Vector2.ONE * AVATAR_SCALE
	_avatar.sprite_frames = _build_walk_frames("kai")
	add_child(_avatar)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_prompt.add_theme_constant_override("outline_size", 6)
	add_child(_prompt)
	var target := next_room if next_room != "" else START_ROOM
	var spawn := next_spawn_x if next_spawn_x >= 0.0 else 0.5
	next_room = ""
	next_spawn_x = -1.0
	enter_room(target, spawn)


func _load_rooms() -> void:
	var dir := DirAccess.open(ROOM_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r: RoomDef = load("%s/%s" % [ROOM_DIR, f])
			if r != null and r.id != "":
				_rooms[r.id] = r


## Kai walks his map sprite here (convention-based like everything else).
func _build_walk_frames(unit_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 10.0)
	var dir := "res://assets/sprites/units/%s" % unit_id
	var i := 1
	while ResourceLoader.exists("%s/walk_f%d.png" % [dir, i]):
		frames.add_frame("walk", load("%s/walk_f%d.png" % [dir, i]))
		i += 1
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	var idle_frames := Unit.idle_frame_indices(i - 1)
	for idx in idle_frames:
		frames.add_frame("idle", load("%s/walk_f%d.png" % [dir, idx]))
	return frames


func enter_room(room_id: String, spawn_x := 0.5) -> void:
	if not _rooms.has(room_id):
		return
	room = _rooms[room_id]
	_backdrop.texture = room.backdrop
	var vp := get_viewport_rect().size
	_avatar_pos = Vector2(vp.x * spawn_x, vp.y * (room.floor_top + room.floor_bottom) * 0.5)
	_avatar.position = _avatar_pos
	room_changed.emit(room_id)


func _process(delta: float) -> void:
	if room == null or _dialogue != null:
		return
	var vp := get_viewport_rect().size
	var move := Vector2.ZERO
	move.x = Input.get_axis("ui_left", "ui_right")
	move.y = Input.get_axis("ui_up", "ui_down")
	if move != Vector2.ZERO:
		_avatar_pos.x += move.x * WALK_SPEED * delta
		_avatar_pos.y += move.y * CLIMB_SPEED * delta
		_avatar_pos.x = clampf(_avatar_pos.x, 30.0, vp.x - 30.0)
		_avatar_pos.y = clampf(_avatar_pos.y, vp.y * room.floor_top, vp.y * room.floor_bottom)
		if move.x != 0.0:
			_avatar.flip_h = move.x < 0.0
		if _avatar.animation != "walk":
			_avatar.play("walk")
	elif _avatar.animation != "idle":
		_avatar.play("idle")
	_avatar.position = _avatar_pos
	_update_prompt(vp)


func _update_prompt(vp: Vector2) -> void:
	_nearest = null
	var best := PROMPT_RANGE * vp.x
	for e in room.exits:
		var d: float = absf(_avatar_pos.x - e.x * vp.x)
		if d < best:
			best = d
			_nearest = e
	for s in room.spots:
		var d2: float = absf(_avatar_pos.x - s.x * vp.x)
		if d2 < best:
			best = d2
			_nearest = s
	if _nearest == null:
		_prompt.visible = false
		return
	_prompt.visible = true
	var txt: String = _nearest.label
	if _nearest is RoomExit and txt == "":
		txt = "To " + str(_rooms[_nearest.to_room].display_name) if _rooms.has(_nearest.to_room) else _nearest.to_room
	_prompt.text = "▶ " + txt
	_prompt.position = Vector2(_avatar_pos.x - 60.0, _avatar_pos.y - 110.0)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue != null or room == null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cursor_confirm"):
		activate_nearest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_leave_castle()


func activate_nearest() -> void:
	if _nearest is RoomExit:
		enter_room(_nearest.to_room, _nearest.spawn_x)
	elif _nearest is RoomSpot:
		var spot: RoomSpot = _nearest
		spot_activated.emit(spot.id)
		if spot.dialogue != "" and FileAccess.file_exists(spot.dialogue):
			_play_dialogue(spot.dialogue)


func _play_dialogue(path: String) -> void:
	_dialogue = DialogueScene.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func():
		_dialogue.queue_free()
		_dialogue = null)
	_dialogue.play(DialogueScript.from_file(path))


func _leave_castle() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
