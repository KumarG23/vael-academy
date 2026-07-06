class_name CastleScene
extends Node2D
## WO-9.1 (castle v2, from Neal's first playtest): the castle is TOP-DOWN
## walkable space now — Chrono Trigger / FE3H / P5 register. Rooms are tiled
## maps bigger than the screen (the battle terrain family renders them), the
## camera follows, movement is free 8-direction with terrain collision, doors
## are VISIBLE glowing arches you simply walk into, and NPCs stand at cells.
## Room functions (training, mission, bonds, cooking, fishing, oath, rest)
## carried over from v1 on the same handler names.

signal room_changed(room_id: String)
signal spot_activated(spot_id: String)

const ROOM_DIR := "res://data/castle_v2"
const START_ROOM := "campus"
const AVATAR_SCALE := 3.0
const WALK_SPEED := 520.0          # world px/s (cells are 128 world px)
const INTERACT_RADIUS := 1.4       # cells
const TARGET_CELL_PX := 76.0       # on-screen cell size (camera zoom)

## Set by flows (or tests) before entering; falls back to START_ROOM.
static var next_room: String = ""
static var next_spawn: Vector2i = Vector2i(-1, -1)

var room: CastleRoomDef
var _rooms: Dictionary = {}
var _grid: Grid
var _terrain_db := TerrainDB.create_default()
var _tiles: TerrainTiles
var _avatar: AnimatedSprite2D
var _npc_sprites: Array = []
var _camera: Camera2D
var _ui: CanvasLayer
var _prompt: Label
var _date_label: Label
var _dialogue: DialogueScene = null
var _nearest_point: CastlePoint = null
var _door_pulse := 0.0

# room functions (v1 handlers, unchanged names — tests ride on these)
var _menu: ChoiceMenu
var _menu_context := ""
var _roster_defs: Array[UnitDef] = []
var _support_state: SupportState
var _hall_entries: Array = []
var _stats_panel: UnitStatsPanel = null
var _fishing: FishingGame = null


func _ready() -> void:
	_load_rooms()
	Campaign.begin_hub_visit()
	_roster_defs = Roster.player_units()
	_support_state = SupportRegistry.build_state()
	_support_state.apply_save_state(Campaign.support_save)
	_tiles = TerrainTiles.new()
	_tiles.show_behind_parent = true  # castle draws walls/door markers above
	add_child(_tiles)
	_avatar = AnimatedSprite2D.new()
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar.scale = Vector2.ONE * AVATAR_SCALE
	_avatar.sprite_frames = _build_avatar_frames("kai")
	add_child(_avatar)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	_ui.add_child(_prompt)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 18)
	_date_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	_date_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_date_label.add_theme_constant_override("outline_size", 5)
	_date_label.position = Vector2(get_viewport_rect().size.x - 430, 12)
	_ui.add_child(_date_label)
	_menu = ChoiceMenu.new()
	var house: HouseDef = load("res://data/houses/%s.tres" % Campaign.house_id)
	if house != null:
		_menu.accent = house.secondary_color
	_menu.chosen.connect(_on_menu_chosen)
	_menu.cancelled.connect(_close_menu)
	_ui.add_child(_menu)
	var target := next_room if next_room != "" else START_ROOM
	var spawn := next_spawn
	next_room = ""
	next_spawn = Vector2i(-1, -1)
	enter_room(target, spawn)
	_refresh_date()


func _load_rooms() -> void:
	var dir := DirAccess.open(ROOM_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r: CastleRoomDef = load("%s/%s" % [ROOM_DIR, f])
			if r != null and r.id != "":
				_rooms[r.id] = r


## 4-direction avatar (WO-9.2): walk_f* = east (flip for west), walk_s_f*/
## walk_n_f* per the WO-4.7 sprite convention. Missing sets fall back east.
func _build_avatar_frames(unit_id: String) -> SpriteFrames:
	var dir := "res://assets/sprites/units/%s" % unit_id
	var sets := Unit.scan_walk_frames(dir)
	var frames := SpriteFrames.new()
	for anim in ["walk", "walk_n", "walk_s"]:
		var paths: Array = sets.get(anim, [])
		if paths.is_empty():
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		for p in paths:
			frames.add_frame(anim, load(p))
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	var east: Array = sets.get("walk", [])
	for idx in Unit.idle_frame_indices(east.size()):
		frames.add_frame("idle", load(east[idx - 1]))
	return frames


func enter_room(room_id: String, spawn := Vector2i(-1, -1)) -> void:
	if not _rooms.has(room_id):
		return
	room = _rooms[room_id]
	_grid = room.chapter.make_grid()
	_tiles.setup(_grid, room.chapter)
	var cell := spawn
	if cell == Vector2i(-1, -1):
		cell = Vector2i(room.chapter.width / 2, room.chapter.height / 2)
	_avatar.position = _grid.cell_center(cell)
	_spawn_npcs()
	_setup_camera()
	queue_redraw()
	room_changed.emit(room_id)


func _setup_camera() -> void:
	var map := _grid.pixel_size()
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / map.x, vp.y / map.y) * 0.98
	var z := maxf(fit, TARGET_CELL_PX / float(_grid.cell_size))
	_camera.zoom = Vector2(z, z)
	_camera.position = _camera_clamp(_avatar.position)
	_camera.reset_smoothing()


func _camera_clamp(focus: Vector2) -> Vector2:
	var map := _grid.pixel_size()
	var half := get_viewport_rect().size * 0.5 / _camera.zoom.x
	var out := focus
	out.x = clampf(focus.x, half.x, map.x - half.x) if map.x > half.x * 2.0 else map.x * 0.5
	out.y = clampf(focus.y, half.y, map.y - half.y) if map.y > half.y * 2.0 else map.y * 0.5
	return out


func _spawn_npcs() -> void:
	for n in _npc_sprites:
		n.queue_free()
	_npc_sprites.clear()
	for p in room.points:
		if p.npc_unit == "" or not _point_available(p):
			continue
		var npc := AnimatedSprite2D.new()
		npc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		npc.scale = Vector2.ONE * AVATAR_SCALE
		npc.sprite_frames = _build_avatar_frames(p.npc_unit)
		npc.play("idle")
		npc.position = _grid.cell_center(p.cell)
		add_child(npc)
		_npc_sprites.append(npc)


func _point_available(p: CastlePoint) -> bool:
	return p.requires_flag == "" or bool(Campaign.flags.get(p.requires_flag, false))


func busy() -> bool:
	return _dialogue != null or _menu_context != "" or _fishing != null


func _process(delta: float) -> void:
	_door_pulse += delta
	queue_redraw()  # door markers pulse
	if room == null or busy():
		return
	var move := Vector2(Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if move.length() > 0.1:
		move = move.normalized()
		var next := _avatar.position + move * WALK_SPEED * delta
		if _walkable(Vector2(next.x, _avatar.position.y)):
			_avatar.position.x = next.x
		if _walkable(Vector2(_avatar.position.x, next.y)):
			_avatar.position.y = next.y
		_face(move)
		_check_door()
	elif _avatar.animation != "idle":
		_avatar.play("idle")
	_camera.position = _camera.position.lerp(_camera_clamp(_avatar.position),
		minf(1.0, delta * 10.0))
	_update_prompt()


func _walkable(world: Vector2) -> bool:
	var cell := _grid.world_to_cell(world)
	if not room.chapter.in_bounds(cell.x, cell.y):
		return false
	return not _terrain_db.is_impassable(room.chapter.get_terrain(cell.x, cell.y))


## 8-direction movement on a 4-direction sheet: verticals get their own sets,
## horizontals/diagonals use east (flipped for west) — the CT readback.
func _face(move: Vector2) -> void:
	var anim := "walk"
	if absf(move.y) > absf(move.x) * 1.2:
		anim = "walk_s" if move.y > 0 else "walk_n"
		if not _avatar.sprite_frames.has_animation(anim):
			anim = "walk"
	if anim == "walk":
		if absf(move.x) > 0.05:
			_avatar.flip_h = move.x < 0.0
	else:
		_avatar.flip_h = false
	if _avatar.animation != anim or not _avatar.is_playing():
		_avatar.play(anim)


func _check_door() -> void:
	var cell := _grid.world_to_cell(_avatar.position)
	for d in room.doors:
		if d.cell == cell and _rooms.has(d.to_room):
			enter_room(d.to_room, d.spawn_cell)
			return


func _update_prompt() -> void:
	_nearest_point = null
	var best := INTERACT_RADIUS * float(_grid.cell_size)
	for p in room.points:
		if not _point_available(p):
			continue
		var d := _avatar.position.distance_to(_grid.cell_center(p.cell))
		if d < best:
			best = d
			_nearest_point = p
	if _nearest_point == null:
		_prompt.visible = false
		return
	_prompt.text = "▶ " + _nearest_point.label
	var screen := (get_viewport().get_canvas_transform() * _avatar.position)
	_prompt.position = screen + Vector2(-60, -120)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if busy() or room == null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cursor_confirm"):
		activate_nearest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_open_system_menu()


func activate_nearest() -> void:
	if _nearest_point == null:
		return
	var p := _nearest_point
	spot_activated.emit(p.id)
	if p.id.begins_with("fn_"):
		_open_function(p.id)
	elif p.dialogue != "" and FileAccess.file_exists(p.dialogue):
		_play_dialogue(p.dialogue)


## Door arches glow so nobody hunts walls (Neal's playtest note). Indoor WALL
## cells are drawn here too (no indoor wall atlas yet — the tileset service
## kept failing on it; flat stone reads fine at CT fidelity).
func _draw() -> void:
	if room == null or _grid == null:
		return
	var cs := float(_grid.cell_size)
	if room.chapter.base_terrain == Terrain.Type.FLOOR:
		for y in range(room.chapter.height):
			for x in range(room.chapter.width):
				if room.chapter.get_terrain(x, y) == Terrain.Type.WALL:
					var r := Rect2(x * cs, y * cs, cs, cs)
					draw_rect(r, Color(0.23, 0.20, 0.26), true)
					var below_open: bool = room.chapter.in_bounds(x, y + 1) \
						and room.chapter.get_terrain(x, y + 1) != Terrain.Type.WALL
					if below_open:
						draw_rect(Rect2(r.position.x, r.position.y + cs * 0.72,
							cs, cs * 0.28), Color(0.33, 0.29, 0.36), true)
					var above_open: bool = y == 0 or room.chapter.get_terrain(x, y - 1) != Terrain.Type.WALL
					if above_open:
						draw_rect(Rect2(r.position.x, r.position.y, cs, cs * 0.10),
							Color(0.40, 0.36, 0.44), true)
	var pulse := 0.5 + 0.3 * sin(_door_pulse * 3.2)
	for d in room.doors:
		var c := Vector2((d.cell.x + 0.5) * cs, (d.cell.y + 0.5) * cs)
		draw_circle(c, cs * 0.34, Color(1.0, 0.87, 0.4, 0.22 * pulse + 0.12))
		draw_arc(c, cs * 0.34, 0, TAU, 24, Color(1.0, 0.87, 0.4, pulse), 4.0)
		var tri := PackedVector2Array([c + Vector2(0, -cs * 0.16),
			c + Vector2(cs * 0.13, cs * 0.08), c + Vector2(-cs * 0.13, cs * 0.08)])
		draw_colored_polygon(tri, Color(1.0, 0.92, 0.55, pulse))


# --- the date + scheduled set-pieces (WO-7.1/7.3, ported) ----------------------

func _refresh_date() -> void:
	var e := Campaign.current_event()
	_date_label.text = "Week %d — %s" % [Campaign.week, e.label if e != null else "The year is done"]
	_maybe_play_set_piece(e)


func _maybe_play_set_piece(e: CalendarEventDef) -> void:
	if e != null and e.kind == CalendarEventDef.Kind.HOLIDAY \
			and not bool(Campaign.flags.get("festival_seen", false)):
		Campaign.flags["festival_seen"] = true
		Campaign.flags["cooking_unlocked"] = true
		_play_dialogue("res://data/dialogue/festival_founding.json")
	elif e == null and Campaign.last_result == "victory" \
			and not bool(Campaign.flags.get("feast_seen", false)):
		Campaign.flags["feast_seen"] = true
		_play_dialogue("res://data/dialogue/party_victory_feast.json")


# --- room functions (WO-6.2a/b, 7.2, ported handler-for-handler) ----------------

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
		"fn_fish":
			_start_fishing()
		"fn_rest":
			_rest_week()
		"fn_cook":
			_open_cooking()


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
	var e := Campaign.current_event()
	if e == null or e.kind != CalendarEventDef.Kind.BATTLE:
		_toast("No mission this week — the year has its own pace.")
		_menu_context = ""
		return
	_menu.open("War Room — " + e.label, ["Deploy", "Stand down"], _menu_pos())


func _do_mission(index: int) -> void:
	_close_menu()
	if index == 0:
		var e := Campaign.current_event()
		if e == null:
			return
		var scene := ChapterRegistry.scene_for(e.chapter_id, Campaign.house_id)
		if scene == "":
			_toast("That chapter isn't authored yet.")
			return
		Campaign.deploy()
		get_tree().change_scene_to_file(scene)


func _rest_week() -> void:
	Campaign.advance_week()
	_refresh_date()
	var e := Campaign.current_event()
	if e != null and e.kind == CalendarEventDef.Kind.HOLIDAY:
		_toast("It's %s! The whole castle is celebrating." % e.label)
	else:
		_toast("A week passes at Vael...")


func _open_hall_archive() -> void:
	_menu_context = "hall"
	_hall_entries = _support_state.unlocked_conversations_for_unit("kai")
	if _hall_entries.is_empty():
		_toast("No bonds strong enough yet — fight beside your housemates.")
		_menu_context = ""
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
		_ui.add_child(_stats_panel)
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


func _start_fishing() -> void:
	if _fishing != null:
		return
	_fishing = FishingGame.new()
	_fishing.finished.connect(_on_fishing_done)
	_ui.add_child(_fishing)


func _on_fishing_done(result: Dictionary) -> void:
	if result["caught"]:
		var fish: String = result["fish"]
		_toast("Caught a %s! (x%d)" % [fish, int(Campaign.fish_log.get(fish, 1))])
	else:
		_toast("...it got away.")
	_fishing.queue_free()
	_fishing = null


func _open_cooking() -> void:
	var key := "cooked_week_%d" % Campaign.week
	if bool(Campaign.flags.get(key, false)):
		_toast("The pits are cold until next week.")
		return
	_menu_context = "cooking"
	var labels: Array = []
	for def in _roster_defs:
		if def.id != "kai":
			labels.append(def.display_name)
	_menu.open("Fire-pit Cooking — with whom?", labels, _menu_pos())


func _do_cook(index: int) -> void:
	var partners: Array = []
	for def in _roster_defs:
		if def.id != "kai":
			partners.append(def)
	var partner: UnitDef = partners[index]
	Campaign.flags["cooked_week_%d" % Campaign.week] = true
	var result := _support_state.add_points("kai", partner.id, 8)
	Campaign.support_save = _support_state.save_state()
	_close_menu()
	if result.get("ranked_up", false):
		_toast("Cooking with %s — bond deepened to %s!" % [partner.display_name, result["new_rank"]])
	else:
		_toast("Cooking with %s — the fire does its quiet work." % partner.display_name)


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
		"cooking":
			_do_cook(index)
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
	_ui.add_child(_dialogue)
	_dialogue.event_triggered.connect(_on_dialogue_event)
	_dialogue.finished.connect(func():
		_dialogue.queue_free()
		_dialogue = null)
	_dialogue.play(DialogueScript.from_file(path))


func _on_dialogue_event(event_name: String, params: Dictionary) -> void:
	match event_name:
		"unlock_school":
			Campaign.flags["school_" + str(params.get("school", ""))] = true
		"set_flag":
			Campaign.flags[str(params.get("flag", ""))] = true
