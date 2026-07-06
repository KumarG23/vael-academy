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
# WO-6.2a: room functions run on the same menu widget the hub used
var _menu: ChoiceMenu
var _menu_context := ""
var _roster_defs: Array[UnitDef] = []
var _support_state: SupportState
var _hall_entries: Array = []


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
	# WO-6.2a: the castle IS the between-battle home now (the menu hub is
	# retired from the flow) — it owns the hub-visit lifecycle.
	Campaign.begin_hub_visit()
	_roster_defs = Roster.player_units()
	_support_state = SupportRegistry.build_state()
	_support_state.apply_save_state(Campaign.support_save)
	_menu = ChoiceMenu.new()
	var house: HouseDef = load("res://data/houses/%s.tres" % Campaign.house_id)
	if house != null:
		_menu.accent = house.secondary_color
	_menu.chosen.connect(_on_menu_chosen)
	_menu.cancelled.connect(_close_menu)
	add_child(_menu)
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
	_spawn_npcs(vp)
	room_changed.emit(room_id)


## WO-6.3: housemates stand at their spots (idle loop from their map frames).
func _spawn_npcs(vp: Vector2) -> void:
	for n in _npc_sprites:
		n.queue_free()
	_npc_sprites.clear()
	for spot in room.spots:
		if spot.npc_unit == "":
			continue
		var npc := AnimatedSprite2D.new()
		npc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		npc.scale = Vector2.ONE * AVATAR_SCALE
		npc.sprite_frames = _build_walk_frames(spot.npc_unit)
		npc.play("idle")
		npc.position = Vector2(vp.x * spot.x, vp.y * (room.floor_top + room.floor_bottom) * 0.5)
		add_child(npc)
		_npc_sprites.append(npc)


func _process(delta: float) -> void:
	if room == null or _dialogue != null or menu_busy():
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
	if _dialogue != null or room == null or menu_busy():
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cursor_confirm"):
		activate_nearest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_open_system_menu()


func activate_nearest() -> void:
	if _nearest is RoomExit:
		enter_room(_nearest.to_room, _nearest.spawn_x)
	elif _nearest is RoomSpot:
		var spot: RoomSpot = _nearest
		spot_activated.emit(spot.id)
		if spot.id.begins_with("fn_"):
			_open_function(spot.id)
		elif spot.dialogue != "" and FileAccess.file_exists(spot.dialogue):
			_play_dialogue(spot.dialogue)


# --- room functions (WO-6.2a): the hub's systems, in their rooms ---------------

func _menu_pos() -> Vector2:
	return Vector2(60, 110)


func menu_busy() -> bool:
	return _menu_context != ""


func _close_menu() -> void:
	_menu_context = ""
	_menu.close()
	if _stats_panel != null:
		_stats_panel.visible = false


func _open_function(fn: String) -> void:
	match fn:
		"fn_train":
			_open_training()
		"fn_deploy":
			_open_mission()
		"fn_supports":
			_open_hall_archive()
		"fn_save":
			Campaign.save_to_slot(0)
			_toast("Game saved.")
		"fn_roster":
			_open_quartermaster()
		"fn_house":
			_open_house_choice()


# --- 6.2b: Quartermaster inspect + the house oath ------------------------------

var _stats_panel: UnitStatsPanel = null
var _npc_sprites: Array = []  # WO-6.3: standing housemates, rebuilt per room


func _open_quartermaster() -> void:
	_menu_context = "quarter"
	var labels: Array = []
	for def in _roster_defs:
		labels.append("%s   %s" % [def.display_name, _level_xp_text(def.id)])
	_menu.open("Quartermaster — Roster", labels, _menu_pos())


func _inspect_unit(index: int) -> void:
	var def := _roster_defs[index]
	var scratch := Unit.new()
	scratch.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	if Campaign.has_unit_state(def.id):
		scratch.apply_progression_state(Campaign.get_unit_state(def.id))
	if _stats_panel == null:
		_stats_panel = UnitStatsPanel.new()
		add_child(_stats_panel)
	_stats_panel.show_unit(scratch)
	scratch.free()


func _open_house_choice() -> void:
	_menu_context = "house"
	var labels: Array = []
	for id in ["emberwing", "tidemark", "thornrook"]:
		var house: HouseDef = load("res://data/houses/%s.tres" % id)
		var mark := "  *" if id == Campaign.house_id else ""
		labels.append("%s — the %s%s" % [house.display_name, house.banner_animal, mark])
	_menu.open("Swear to a House", labels, _menu_pos())


func _choose_house(index: int) -> void:
	Campaign.set_house(["emberwing", "tidemark", "thornrook"][index])
	_roster_defs = Roster.player_units()
	_close_menu()
	_toast("Sworn to House %s." % Campaign.house_id.capitalize())


func _toast(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true


func _level_xp_text(id: String) -> String:
	var st := Campaign.get_unit_state(id)
	return "Lv %d  %d xp" % [int(st.get("level", 1)), int(st.get("xp", 0))]


func _open_training() -> void:
	_menu_context = "training"
	var labels: Array = []
	for def in _roster_defs:
		labels.append("%s   %s" % [def.display_name, _level_xp_text(def.id)])
	_menu.open("Training Grounds", labels, _menu_pos())


func _do_train(index: int) -> void:
	var def := _roster_defs[index]
	if not Campaign.can_train():
		_toast("Already trained this visit.")
		_close_menu()
		return
	Campaign.train_unit(def.id)
	_toast("%s trained: +%d XP" % [def.display_name, CampaignState.TRAINING_XP])
	_close_menu()


func _open_mission() -> void:
	_menu_context = "mission"
	_menu.open("War Room — Mission", ["Deploy to the Mock Battle", "Stand down"], _menu_pos())


func _do_mission(index: int) -> void:
	_close_menu()
	if index == 0:
		Campaign.deploy()
		get_tree().change_scene_to_file(
			HubScene.BATTLE_SCENE_FOR_HOUSE.get(Campaign.house_id, HubScene.BATTLE_SCENE))


func _open_hall_archive() -> void:
	_menu_context = "hall"
	_hall_entries = _support_state.unlocked_conversations_for_unit("kai")
	if _hall_entries.is_empty():
		_toast("No bonds strong enough yet — fight beside your housemates.")
		return
	var labels: Array = []
	for c in _hall_entries:
		labels.append(str(c["label"]) + ("   ✓" if bool(c.get("viewed", false)) else ""))
	_menu.open("Common Hall — Bonds", labels, _menu_pos())


func _view_hall_entry(index: int) -> void:
	var entry: Dictionary = _hall_entries[index]
	_close_menu()
	var path := str(entry.get("path", ""))
	if path != "" and FileAccess.file_exists(path):
		_play_dialogue(path)
		_support_state.mark_viewed(str(entry["pair_id"]), str(entry["rank"]))
		Campaign.support_save = _support_state.save_state()


func _on_menu_chosen(index: int) -> void:
	match _menu_context:
		"training":
			_do_train(index)
		"mission":
			_do_mission(index)
		"hall":
			_view_hall_entry(index)
		"quarter":
			_inspect_unit(index)
		"house":
			_choose_house(index)
		"system":
			_do_system(index)


func _open_system_menu() -> void:
	_menu_context = "system"
	_menu.open("Vael Academy", ["Save Game", "Return to Title", "Back"], _menu_pos())


func _do_system(index: int) -> void:
	_close_menu()
	match index:
		0:
			Campaign.save_to_slot(0)
			_toast("Game saved.")
		1:
			get_tree().change_scene_to_file("res://scenes/title/title.tscn")


func _play_dialogue(path: String) -> void:
	_dialogue = DialogueScene.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func():
		_dialogue.queue_free()
		_dialogue = null)
	_dialogue.play(DialogueScript.from_file(path))



