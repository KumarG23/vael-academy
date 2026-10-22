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
## Ambient walkers (points whose id starts "walker_"): {sprite, home, target,
## wait} — they pace their little patch of campus and make the place breathe.
var _walkers: Array = []
var _camera: Camera2D
## Interior rooms get a tall back wall ABOVE row 0 the camera may reveal, so
## props against the top wall (bookshelves/statues run 2+ cells tall at 4×
## scale) are never clipped by the map's top edge. 0 for outdoor rooms.
var _ceiling := 0.0
var _ui: CanvasLayer
var _prompt: Label
var _date_label: Label
var _toast_label: Label
var _title_card: AreaTitleCard
var _toast_left := 0.0
var _dialogue: DialogueScene = null
var _journal: AcademyJournal = null  # AW-39: the J-key book UI
var _editor: CampusEditor = null     # AW-44: the ` visual room editor
var _occluder: Node2D = null         # AW-47: y-sort occlusion overlay
var _nearest_point: CastlePoint = null
var _door_pulse := 0.0
## Doors re-arm only after the avatar leaves a door cell — spawning beside
## (or on) a doorway can never bounce you straight back (the dorm loop bug).
var _door_armed := false

# room functions (v1 handlers, unchanged names — tests ride on these)
var _music: AudioStreamPlayer
var _menu: ChoiceMenu
var _menu_context := ""
var _roster_defs: Array[UnitDef] = []
var _support_state: SupportState
var _hall_entries: Array = []
var _stats_panel: UnitStatsPanel = null
var _fishing: FishingGame = null
var _quiz: QuizScene = null          # AW-54: the classroom lesson overlay

## AW-54: each house learns under its own head (CHARACTER_BIBLE canon).
const HOUSE_TEACHERS := {
	"emberwing": {"id": "callan", "name": "Professor Callan"},
	"tidemark": {"id": "maren", "name": "Warden Maren"},
	"thornrook": {"id": "alaric", "name": "Keeper Alaric"},
}
## Teacher reactions per score tier — DRAFT lines in each teacher's bible voice
## (Callan grizzled-warm, Maren immaculate-controlled, Alaric dry-patient);
## Neal tears apart at the co-write. Tiers: 100 / >=75 / >=50 / >0 / 0.
const TEACHER_REACTIONS := {
	"callan": [
		"A perfect slate. Ha! Half the officers I served under couldn't manage that. Here — I keep these for students worth the ink. Don't tell the quartermaster.",
		"Sharp work, kid. You listen better than you let on. Keep this up and I'll run out of things to teach you — that's the goal, mind.",
		"Passing. Passing is fine. Passing also gets people killed at the margins, so let's tighten it up, eh?",
		"You're guessing. I know guessing when I see it — I've BEEN the guesser. Books first, bravado second. Again next week.",
		"Not one. Not ONE. I've seen you fight, so I know the wits are in there — put them in a chair with a book before I chain the two together.",
	],
	"maren": [
		"Flawless. Precision of thought precedes precision of action — you have just proven the doctrine's first page. Take this; it is not a gift, it is an expectation.",
		"Very good. Nearly exact. The gap between nearly and exact is where battles are lost — close it.",
		"Adequate. The academy does not aspire to adequate, and I suspect neither do you.",
		"This will not do. Discipline of the mind is the first discipline. The library is open every evening; I expect you in it.",
		"Zero. I have graded four decades of students and a zero still manages to disappoint me freshly. You will study, and we will repeat this.",
	],
	"alaric": [
		"Every answer, exact. Curious — most minds skim; yours retains. That deserves something from the deeper shelves. Handle it better than the last borrower did.",
		"Well read. Mostly. The margins of your errors are more interesting than your correct answers — come find me if you want to know why.",
		"Half-remembered is half-true, and half-true is how rumors start wars. Read closer.",
		"Mm. You've been walking past the shelves, not through them. The library rewards the slow — slow down.",
		"Remarkable, in its way — a clean zero requires its own consistency. The books are not decorative, boy. Begin with the thin ones.",
	],
}
## The spellbook ladder (SPELLBOOKS.md): a perfect exam earns one, opening a
## school of magic for Kai. First-come order; each awards once.
const SPELLBOOK_LADDER := [
	{"flag": "spellbook_ember", "school": "ember", "weapon": "res://data/weapons/fire.tres", "label": "a scorched spellbook — the EMBER school opens to Kai"},
	{"flag": "spellbook_gale", "school": "gale", "weapon": "res://data/weapons/gale.tres", "label": "a wind-cut spellbook — the GALE school opens to Kai"},
	{"flag": "spellbook_tide", "school": "tide", "weapon": "res://data/weapons/tide.tres", "label": "a salt-stained spellbook — the TIDE school opens to Kai"},
]


func _ready() -> void:
	_load_rooms()
	Campaign.begin_hub_visit()
	_roster_defs = Roster.player_units()
	_support_state = SupportRegistry.build_state()
	_support_state.apply_save_state(Campaign.support_save)
	_tiles = TerrainTiles.new()
	_tiles.show_behind_parent = true  # castle draws walls/props/markers above
	_tiles.draw_props = false         # props drawn in _draw, ABOVE the walls
	add_child(_tiles)
	_avatar = AnimatedSprite2D.new()
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar.scale = Vector2.ONE * AVATAR_SCALE
	_avatar.sprite_frames = _build_avatar_frames("kai")
	add_child(_avatar)
	# AW-47: y-sort occlusion overlay — redraws props above the actors when they
	# stand behind them (drawn above the world via z_index; logic in draw_occluders)
	_occluder = load("res://src/castle/occluder_overlay.gd").new()
	_occluder.castle = self
	_occluder.z_index = 20
	add_child(_occluder)
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
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.75))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_toast_label.add_theme_constant_override("outline_size", 7)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 260, 60)
	_toast_label.custom_minimum_size = Vector2(520, 0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	_ui.add_child(_toast_label)
	_title_card = AreaTitleCard.new()  # AW-71: "— The Sealed Grove —" on arrival
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_title_card)
	_menu = ChoiceMenu.new()
	var house: HouseDef = load("res://data/houses/%s.tres" % Campaign.house_id)
	if house != null:
		_menu.accent = house.secondary_color
	_menu.chosen.connect(_on_menu_chosen)
	_menu.cancelled.connect(_close_menu)
	_ui.add_child(_menu)
	_editor = CampusEditor.new()  # AW-44: the in-game visual room editor (` to toggle)
	add_child(_editor)
	_editor.setup(self)
	_start_music()
	var target := next_room if next_room != "" else START_ROOM
	var spawn := next_spawn
	next_room = ""
	next_spawn = Vector2i(-1, -1)
	enter_room(target, spawn)
	_refresh_date()


## WO-9.3 (first slice): campus background music — one looping bed for the
## whole castle scene, so it carries across every room. Convention-based:
## plays whatever lives at assets/audio/music/campus_chill.mp3.
func _start_music() -> void:
	# AW-36: the campus bed runs through the AudioManager autoload, which owns the
	# single music voice across scenes (battle swaps to the battle theme). AW-47:
	# enter_room refines this to the room's own theme when one exists.
	AudioManager.play_music("res://assets/audio/music/campus_chill.mp3")


## Per-room music (AW-47): drop a file at assets/audio/music/rooms/<room_id>.{ogg,
## mp3,wav} to give an area its own theme; otherwise the shared campus bed plays.
## play_music no-ops on an unchanged track, so wandering bed-rooms won't restart it.
func _music_for_room(room_id: String) -> String:
	for ext in ["ogg", "mp3", "wav"]:
		var p := "res://assets/audio/music/rooms/%s.%s" % [room_id, ext]
		if ResourceLoader.exists(p):
			return p
	return "res://assets/audio/music/campus_chill.mp3"


func _load_rooms() -> void:
	var dir := DirAccess.open(ROOM_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r: CastleRoomDef = load("%s/%s" % [ROOM_DIR, f])
			if r != null and r.id != "":
				_rooms[r.id] = r


## AW-60: what everyone wears on campus — party formalwear on festival weeks,
## the school uniform otherwise. resolve_sprite_dir falls back to the battle
## set for anyone whose variant art doesn't exist yet, so this is safe cast-wide.
func _campus_variant() -> String:
	var e := Campaign.current_event()
	if e != null and e.kind == CalendarEventDef.Kind.HOLIDAY:
		return "party"
	return "school"


## 4-direction avatar (WO-9.2): walk_f* = east (flip for west), walk_s_f*/
## walk_n_f* per the WO-4.7 sprite convention. Missing sets fall back east.
func _build_avatar_frames(unit_id: String) -> SpriteFrames:
	var dir := Unit.resolve_sprite_dir(unit_id, _campus_variant())
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
	AudioManager.play_music(_music_for_room(room_id))  # AW-47: per-area theme
	_grid = room.chapter.make_grid()
	_ceiling = float(_grid.cell_size) * 1.6 if room.chapter.base_terrain == Terrain.Type.FLOOR else 0.0
	_tiles.setup(_grid, room.chapter)
	var cell := spawn
	if cell == Vector2i(-1, -1):
		cell = Vector2i(room.chapter.width / 2, room.chapter.height / 2)
	_avatar.position = _grid.cell_center(cell)
	_door_armed = false
	_spawn_npcs()
	_setup_camera()
	queue_redraw()
	if _title_card != null:
		_title_card.show_title(room.display_name)  # AW-71: name the place
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
	# the vertical extent runs from -_ceiling (top of the back wall) to map.y
	var top := -_ceiling
	var span := map.y - top
	out.y = clampf(focus.y, top + half.y, map.y - half.y) if span > half.y * 2.0 else (top + map.y) * 0.5
	return out


func _spawn_npcs() -> void:
	for n in _npc_sprites:
		n.queue_free()
	_npc_sprites.clear()
	_walkers.clear()
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
		if p.id.begins_with("walker_"):
			_walkers.append({"sprite": npc, "home": p.cell, "point": p,
				"target": npc.position, "wait": randf_range(0.5, 2.5)})


## The campus breathes: walkers drift a couple of cells around home, pause,
## drift again. Their interaction point follows them.
func _tick_walkers(delta: float) -> void:
	for w in _walkers:
		var spr: AnimatedSprite2D = w["sprite"]
		if w["wait"] > 0.0:
			w["wait"] -= delta
			if spr.animation != "idle":
				spr.play("idle")
			if w["wait"] <= 0.0:
				var home: Vector2i = w["home"]
				var cand := home + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
				if room.chapter.in_bounds(cand.x, cand.y) 						and not _terrain_db.is_impassable(room.chapter.get_terrain(cand.x, cand.y)):
					w["target"] = _grid.cell_center(cand)
			continue
		var to: Vector2 = w["target"] - spr.position
		if to.length() < 6.0:
			w["wait"] = randf_range(1.5, 4.0)
			continue
		var step := to.normalized() * (WALK_SPEED * 0.35) * delta
		spr.position += step
		spr.flip_h = step.x < 0.0
		if spr.animation != "walk":
			spr.play("walk")
		var p: CastlePoint = w["point"]
		p.cell = _grid.world_to_cell(spr.position)  # the chat follows them


func _point_available(p: CastlePoint) -> bool:
	return p.requires_flag == "" or bool(Campaign.flags.get(p.requires_flag, false))


func busy() -> bool:
	return _dialogue != null or _menu_context != "" or _fishing != null or _journal != null \
		or _quiz != null or (_editor != null and _editor.active)


func _process(delta: float) -> void:
	_door_pulse += delta
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast_label.visible = false
	queue_redraw()  # door markers pulse
	if _occluder != null:
		_occluder.queue_redraw()  # AW-47: keep occlusion in step with the avatar
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
	_tick_walkers(delta)
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
	var on_door := false
	for d in room.doors:
		if d.cell == cell:
			on_door = true
			if _door_armed and _rooms.has(d.to_room):
				AudioManager.play_sfx("door")  # AW-36
				enter_room(d.to_room, d.spawn_cell)
				return
	if not on_door:
		_door_armed = true


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
	# AW-44: backtick/tilde toggles the visual room editor; while it's on, it eats
	# all input (no walking / journal / interacting).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		if _editor != null:
			_editor.toggle()
			get_viewport().set_input_as_handled()
		return
	if _editor != null and _editor.active:
		if _editor.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	# AW-39: J opens the Academy Journal from anywhere in the castle.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		if _journal == null and not busy():
			_open_journal()
			get_viewport().set_input_as_handled()
		return
	if busy() or room == null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cursor_confirm"):
		# AW-49: mark the input handled BEFORE acting — activate_nearest can change
		# the scene (fn_arena), which pulls this node out of the tree mid-call; a
		# get_viewport() after that returns null and crashed the arena entry.
		get_viewport().set_input_as_handled()
		activate_nearest()
	elif event.is_action_pressed("ui_cancel"):
		_open_system_menu()


func _open_journal() -> void:
	AudioManager.play_sfx("confirm")
	_journal = AcademyJournal.new()
	_journal.closed.connect(func() -> void: _journal = null)
	_ui.add_child(_journal)


func activate_nearest() -> void:
	if _nearest_point == null:
		return
	var p := _nearest_point
	spot_activated.emit(p.id)
	if p.id.begins_with("fn_"):
		_open_function(p.id)
	elif p.dialogue != "" and FileAccess.file_exists(p.dialogue):
		# AW-54: reading is studying — lore you've actually read unlocks its quiz
		# questions (exploration rewarded; see data/quizzes/bank_v1.json req_flag).
		Campaign.flags["read_" + p.id] = true
		_play_dialogue(p.dialogue)


## Door arches glow so nobody hunts walls (Neal's playtest note). Indoor WALL
## cells are drawn here too (no indoor wall atlas yet — the tileset service
## kept failing on it; flat stone reads fine at CT fidelity).
func _draw() -> void:
	if room == null or _grid == null:
		return
	var cs := float(_grid.cell_size)
	if room.chapter.base_terrain == Terrain.Type.FLOOR:
		# the tall back wall filling the ceiling headroom above row 0, so props
		# leaning against the top wall (2+ cells tall) read as being IN the room.
		if _ceiling > 0.0:
			var mapw := room.chapter.width * cs
			draw_rect(Rect2(0, -_ceiling, mapw, _ceiling + 1.0), Color(0.19, 0.16, 0.22), true)
			draw_rect(Rect2(0, -_ceiling, mapw, cs * 0.14), Color(0.30, 0.26, 0.34), true)
			# faint vertical courses so the wall reads as masonry, not a void
			var course := Color(0.15, 0.13, 0.18, 0.7)
			var col := cs
			while col < mapw:
				draw_line(Vector2(col, -_ceiling), Vector2(col, 0), course, 2.0)
				col += cs
			draw_rect(Rect2(0, -cs * 0.12, mapw, cs * 0.12), Color(0.33, 0.29, 0.36), true)
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
	# authored props draw ABOVE the walls/ceiling (so shelves against the back
	# wall aren't hidden behind it), y-sorted so lower props overlap higher ones
	var props := room.chapter.decor.duplicate()
	props.sort_custom(func(a, b): return a.cell.y < b.cell.y)
	for d: MapDecor in props:
		if d == null or d.texture == null:
			continue
		_draw_prop(self, d, _prop_rect(d, cs), true)
	var pulse := 0.5 + 0.3 * sin(_door_pulse * 3.2)
	for d in room.doors:
		var c := Vector2((d.cell.x + 0.5) * cs, (d.cell.y + 0.5) * cs)
		draw_circle(c, cs * 0.34, Color(1.0, 0.87, 0.4, 0.22 * pulse + 0.12))
		draw_arc(c, cs * 0.34, 0, TAU, 24, Color(1.0, 0.87, 0.4, pulse), 4.0)
		var tri := PackedVector2Array([c + Vector2(0, -cs * 0.16),
			c + Vector2(cs * 0.13, cs * 0.08), c + Vector2(-cs * 0.13, cs * 0.08)])
		draw_colored_polygon(tri, Color(1.0, 0.92, 0.55, pulse))
		if d.label != "":
			var font := ThemeDB.fallback_font
			draw_string_outline(font, c + Vector2(-150, -cs * 0.55), d.label,
				HORIZONTAL_ALIGNMENT_CENTER, 300, 30, 8, Color(0.1, 0.08, 0.05, 0.9))
			draw_string(font, c + Vector2(-150, -cs * 0.55), d.label,
				HORIZONTAL_ALIGNMENT_CENTER, 300, 30, Color(1.0, 0.94, 0.7, 0.55 + pulse * 0.4))


# --- prop drawing + y-sort occlusion (AW-46/AW-47) ------------------------------

## Bottom-anchored screen rect for a decor prop (authored at 32px/tile).
func _prop_rect(d: MapDecor, cs: float) -> Rect2:
	var scale := cs / 32.0
	var w: float = d.texture.get_width() * scale
	var h: float = d.texture.get_height() * scale
	return Rect2(d.cell.x * cs + (cs - w) * 0.5 + d.offset.x,
		d.cell.y * cs + cs - h + d.offset.y, w, h)


## Draws one scenery prop onto `canvas`. `aura` adds the Wardtree's pulsing
## ground-glow (base pass only; the occlusion redraw passes false).
func _draw_prop(canvas: CanvasItem, d: MapDecor, rect: Rect2, aura: bool) -> void:
	if d.texture.resource_path.contains("great_wardtree"):
		# AW-46: the Sealed Grove's Wardtree breathes — a green aura + emerald shimmer.
		var t := 0.5 + 0.5 * sin(_door_pulse * 1.5)
		if aura:
			var ctr := Vector2(rect.position.x + rect.size.x * 0.5,
				rect.position.y + rect.size.y * 0.44)
			canvas.draw_circle(ctr, rect.size.x * (0.60 + 0.10 * t), Color(0.34, 1.0, 0.5, 0.06 + 0.08 * t))
			canvas.draw_circle(ctr, rect.size.x * (0.42 + 0.06 * t), Color(0.6, 1.0, 0.72, 0.06 + 0.09 * t))
		canvas.draw_texture_rect(d.texture, rect, false,
			Color(1, 1, 1).lerp(Color(0.72, 1.0, 0.8), 0.28 * t))
	else:
		canvas.draw_texture_rect(d.texture, rect, false)


## AW-47: an actor stands BEHIND a prop when its feet are above the prop's base
## (it's on the prop's north side) and its body overlaps the prop's footprint.
func _actor_behind_prop(actor_pos: Vector2, d: MapDecor, cs: float) -> bool:
	var prop_feet := float(d.cell.y + 1) * cs
	var feet := actor_pos.y + cs * 0.5
	if prop_feet <= feet:
		return false  # actor is level with / below the prop — it's in front
	var ar := Rect2(actor_pos.x - cs * 0.5, actor_pos.y - cs * 0.6, cs, cs * 1.1)
	return _prop_rect(d, cs).intersects(ar)


## AW-47: called by the occluder overlay (drawn above the actors) — redraws every
## prop an actor is standing behind, so you pass UNDER trees/buildings, not over.
func draw_occluders(canvas: CanvasItem) -> void:
	if room == null or _grid == null:
		return
	var cs := float(_grid.cell_size)
	var actors: Array = [_avatar]
	actors.append_array(_npc_sprites)
	for d: MapDecor in room.chapter.decor:
		if d == null or d.texture == null:
			continue
		for a in actors:
			if a == null or not a.visible:
				continue
			if _actor_behind_prop(a.position, d, cs):
				_draw_prop(canvas, d, _prop_rect(d, cs), false)
				break


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
		Campaign.add_conduct(3)  # AW-54: attended the festival
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
		"fn_arena":
			if bool(Campaign.flags.get("arena_used_this_week", false)):
				_toast("The Arena's magic is spent — it reopens next week.")
			else:
				Campaign.deploy()
				# AW-49: deferred — swapping scenes synchronously inside an input
				# callback de-trees this node mid-call (the arena-entry crash).
				get_tree().change_scene_to_file.call_deferred("res://scenes/battle/arena.tscn")
		"fn_class":
			_start_class()
		"fn_shop_smith", "fn_shop_goods", "fn_shop_magic":
			_open_shop(fn)
		"fn_tavern":
			_open_tavern()


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_left = 2.6


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
		BattleView.next_prep = true  # AW-74: missions open on preparations
		get_tree().change_scene_to_file.call_deferred(scene)


## AW-64: the report-card chest, scaled to rank (GRADING_SYSTEM.md §4).
const RANK_REWARD_GOLD := {"S": 400, "A": 250, "B": 150, "C": 80, "D": 40}
## DRAFT ceremony lines per teacher per rank — in bible voice; co-write polishes.
const CEREMONY_LINES := {
	"callan": {
		"S": "Top of the year. TOP of the year! I've commanded soldiers twice your age with half your marks — don't you dare get comfortable about it.",
		"A": "Distinguished. That's the academy's word — mine is 'proud', and I don't spend it often.",
		"B": "Accomplished. Solid, dependable, room to climb. The climb's the fun part, kid.",
		"C": "Passing. You and I both know the margins got lucky. Next term we make luck unnecessary.",
		"D": "Faltering. I've been where you're standing, so hear me: this is a floor, not a verdict. Up we go.",
	},
	"maren": {
		"S": "Ascendant. The doctrine asks for excellence and you have answered it precisely. The academy notes it. So do I.",
		"A": "Distinguished. Nearly exact. You know my feelings on 'nearly' — but today, accept the commendation.",
		"B": "Accomplished. Adequate plus effort. The next rank requires discipline you have not yet shown me.",
		"C": "Passing. The academy passes you; I reserve judgment. Structure your weeks better.",
		"D": "Faltering. This will be corrected. Report to the library each evening — consider it doctrine.",
	},
	"alaric": {
		"S": "Every column, exact. Curious minds usually scatter; yours gathers. The deep shelves will be expecting you.",
		"A": "Distinguished. The errors you did make were interesting ones — that matters more than you know.",
		"B": "Accomplished. A sturdy shelf, if not yet a full one. Keep filling it.",
		"C": "Passing. Read slower. Half-understood pages start wars — and worse, bad essays.",
		"D": "Faltering. The books are patient, boy — more patient than the faculty. Begin again with the thin ones.",
	},
}


func _rest_week() -> void:
	# AW-76 (Codex finding #2): a battle week doesn't pass by sleeping through
	# it — winning the mission is what advances the calendar (Campaign.capture).
	var now := Campaign.current_event()
	if now != null and now.kind == CalendarEventDef.Kind.BATTLE:
		_toast("%s awaits — the year holds its breath until you answer it." % now.label)
		return
	var sem_before := Campaign.semester
	Campaign.advance_week()
	if Campaign.semester != sem_before:
		_play_report_card()  # AW-64: the term closed — the ceremony, not a toast
		_refresh_date()      # a set piece on the new week queues after it
		return
	_refresh_date()
	var e := Campaign.current_event()
	if e != null and e.kind == CalendarEventDef.Kind.HOLIDAY:
		_toast("It's %s! The whole castle is celebrating." % e.label)
	else:
		_toast("A week passes at Vael...")


## AW-64: the end-of-semester Report Card — your house's teacher delivers the
## rank in their own voice, and the reward chest lands (gold; a rare seal at S).
func _play_report_card() -> void:
	if Campaign.report_cards.is_empty():
		return
	var rc: Dictionary = Campaign.report_cards[-1]
	var rank := str(rc["rank"])
	var t := _teacher()
	var line: String = CEREMONY_LINES[t["id"]].get(rank, "The term is done.")
	var expr := "happy" if rank in ["S", "A"] else ("neutral" if rank == "B" else ("worried" if rank == "C" else "angry"))
	var gold: int = RANK_REWARD_GOLD.get(rank, 50)
	Campaign.flags["gold"] = int(Campaign.flags.get("gold", 0)) + gold
	var reward_text := "Kai received %d gold for the term." % gold
	if rank == "S" and Campaign.grant_item("kai", "res://data/items/promotion_seal.tres"):
		reward_text += "  And for an Ascendant year — a Promotion Seal."
	var steps: Array = [
		{"speaker": t["name"], "side": "right", "portrait": t["id"], "expression": expr,
			"text": "Semester %d closes. Your standing: %s — %s (%d)." % [int(rc["semester"]), rank, str(rc["rank_name"]), int(rc["score"])]},
		{"speaker": t["name"], "side": "right", "portrait": t["id"], "expression": expr, "text": line},
		{"speaker": t["name"], "side": "right", "portrait": t["id"], "text": reward_text},
	]
	# AW-74: word of a graded cadet travels — a traveling merchant starts
	# following the missions from the first term's close. (Co-write may move
	# this unlock onto a story beat later.)
	if not bool(Campaign.flags.get("merchant_unlocked", false)):
		Campaign.flags["merchant_unlocked"] = true
		steps.append({"speaker": t["name"], "side": "right", "portrait": t["id"],
			"text": "One more thing — a merchant has been asking after the cadet corps. Expect his cart at your next deployment."})
	_play_dialogue_json(JSON.stringify(steps))


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
	var path := str(entry.get("path", ""))
	var script := DialogueScript.from_file(path)
	# WO-4.2: the archive lists authored slots, but an unwritten or malformed file
	# is not a watched scene. Keep it available instead of silently consuming it.
	if not script.is_playable():
		_toast("That conversation isn't ready to play yet.")
		return
	_close_menu()
	_play_script(script, func():
		_support_state.mark_viewed(str(entry["pair_id"]), str(entry["rank"]))
		Campaign.support_save = _support_state.save_state()
		_open_hall_archive())


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
	if Campaign.house_locked:
		_toast("Your oath is sworn: House %s, for this year and always." % Campaign.house_id.capitalize())
		return
	_menu_context = "house"
	var labels: Array = []
	for id in ["emberwing", "tidemark", "thornrook"]:
		var house: HouseDef = load("res://data/houses/%s.tres" % id)
		var mark := "  *" if id == Campaign.house_id else ""
		labels.append("%s — the %s%s" % [house.display_name, house.banner_animal, mark])
	_menu.open("Swear to a House", labels, _menu_pos())


func _choose_house(index: int) -> void:
	Campaign.set_house(["emberwing", "tidemark", "thornrook"][index])
	Campaign.house_locked = true  # FE3H rule: the oath binds for the playthrough
	_roster_defs = Roster.player_units()
	_close_menu()
	_toast("Sworn to House %s — for this year and always." % Campaign.house_id.capitalize())


# --- AW-66: the Vael shops + the Gilded Stag tavern -------------------------------

## Shop stock (TOWN_OF_VAEL.md §2). Purchases land in Kai's persisted kit.
const SHOP_STOCK := {
	"fn_shop_smith": {"title": "The Smithy", "wares": [
		{"label": "Iron Sword", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_sword.tres"},
		{"label": "Iron Lance", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_lance.tres"},
		{"label": "Iron Axe", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_axe.tres"},
		{"label": "Iron Bow", "cost": 90, "kind": "weapon", "path": "res://data/weapons/iron_bow.tres"},
	]},
	"fn_shop_goods": {"title": "Reach & Barrel — Goods", "wares": [
		{"label": "Vulnerary", "cost": 60, "kind": "item", "path": "res://data/items/vulnerary.tres"},
		{"label": "Promotion Seal", "cost": 600, "kind": "item", "path": "res://data/items/promotion_seal.tres"},
	]},
}
const SPELLBOOK_PRICE := 900  # SPELLBOOKS.md: "really expensive" — the gold chase
const TAVERN_MEAL_COST := 20

var _shop_wares: Array = []
var _shop_fn := ""  # AW-70: remembered so a purchase can reopen the stall


func gold() -> int:
	return int(Campaign.flags.get("gold", 0))


func _open_shop(fn: String) -> void:
	_menu_context = "shop"
	_shop_fn = fn
	if fn == "fn_shop_magic":
		# the arcane bookshop stocks one spellbook per school Kai hasn't learned
		_shop_wares = []
		for award in SPELLBOOK_LADDER:
			if not bool(Campaign.flags.get(award["flag"], false)):
				_shop_wares.append({"label": "Spellbook of %s" % str(award["school"]).capitalize(),
					"cost": SPELLBOOK_PRICE, "kind": "spellbook", "award": award})
		if _shop_wares.is_empty():
			_toast("The shelves are bare — Kai has learned every school they sell.")
			_menu_context = ""
			return
	else:
		_shop_wares = (SHOP_STOCK[fn]["wares"] as Array).duplicate()
	var title: String = SHOP_STOCK.get(fn, {}).get("title", "The Arcane Bookshop")
	var labels: Array = []
	for w in _shop_wares:
		labels.append("%s — %dg" % [w["label"], w["cost"]])
	_menu.open("%s   (purse: %dg)" % [title, gold()], labels, _menu_pos())


func _do_shop(index: int) -> void:
	var w: Dictionary = _shop_wares[index]
	_close_menu()
	var cost := int(w["cost"])
	if gold() < cost:
		_toast("Not enough gold — the shopkeep smiles politely.")
		return
	var ok := false
	match str(w["kind"]):
		"weapon":
			ok = Campaign.grant_weapon("kai", str(w["path"]))
		"item":
			ok = Campaign.grant_item("kai", str(w["path"]))
		"spellbook":
			var award: Dictionary = w["award"]
			ok = Campaign.grant_weapon("kai", str(award["weapon"]))
			if ok:
				Campaign.flags[award["flag"]] = true
				Campaign.flags["school_" + str(award["school"])] = true
	if not ok:
		_toast("Kai's pack is full — clear a slot first.")
		return
	Campaign.flags["gold"] = gold() - cost
	AudioManager.play_sfx("confirm")
	_toast("Bought %s. (%dg left)" % [w["label"], gold()])
	_open_shop(_shop_fn)  # AW-70: browsing continues — buy more without re-entering


## The Gilded Stag: share a meal with a housemate — bond over stew (FE3H-style).
func _open_tavern() -> void:
	var key := "tavern_week_%d" % Campaign.week
	if bool(Campaign.flags.get(key, false)):
		_toast("The Stag's kitchen is closed to students until next week.")
		return
	if gold() < TAVERN_MEAL_COST:
		_toast("A meal for two runs %dg — the purse says no." % TAVERN_MEAL_COST)
		return
	_menu_context = "tavern"
	var labels: Array = []
	for def in _roster_defs:
		if def.id != "kai":
			labels.append(def.display_name + _rank_tag(def.id))
	_menu.open("The Gilded Stag — share a meal? (%dg)" % TAVERN_MEAL_COST, labels, _menu_pos())


## AW-70: show where each bond stands right in the partner list.
func _rank_tag(partner_id: String) -> String:
	var r := _support_state.rank_for_units("kai", partner_id)
	return "   [%s]" % r if r != "" else ""


func _do_tavern(index: int) -> void:
	var partners: Array = []
	for def in _roster_defs:
		if def.id != "kai":
			partners.append(def)
	var partner: UnitDef = partners[index]
	_close_menu()
	Campaign.flags["tavern_week_%d" % Campaign.week] = true
	Campaign.flags["gold"] = gold() - TAVERN_MEAL_COST
	Campaign.add_conduct(2)
	var result := _support_state.add_points("kai", partner.id, 8)
	Campaign.support_save = _support_state.save_state()
	if result.get("ranked_up", false):
		EventBus.support_rank_up.emit(str(result["pair_id"]), str(result["new_rank"]))
		_toast("Stew, stories, and something more — bond with %s deepens to %s!" % [partner.display_name, result["new_rank"]])
	else:
		_toast("A warm meal with %s — the Stag does its quiet work." % partner.display_name)


# --- AW-54: the classroom lesson (quiz -> teacher reaction -> grade) -------------

func _teacher() -> Dictionary:
	return HOUSE_TEACHERS.get(Campaign.house_id, HOUSE_TEACHERS["emberwing"])


func _start_class() -> void:
	var key := "class_week_%d" % Campaign.week
	if bool(Campaign.flags.get(key, false)):
		_toast("%s has dismissed the class until next week." % _teacher()["name"])
		return
	if _quiz != null:
		return
	var questions := QuizScene.pick_questions(QuizScene.QUESTIONS_PER_LESSON, Campaign.flags)
	if questions.is_empty():
		_toast("The lesson hall is quiet today.")
		return
	_quiz = QuizScene.new()
	_quiz.finished.connect(_on_quiz_done)
	_ui.add_child(_quiz)
	_quiz.start(questions)


func _on_quiz_done(correct: int, total: int) -> void:
	Campaign.flags["class_week_%d" % Campaign.week] = true
	var pct := roundi(100.0 * correct / maxf(1.0, float(total)))
	Campaign.record_quiz(pct)
	Campaign.add_conduct(2)  # showing up to class is conduct too
	_quiz.queue_free()
	_quiz = null
	# the teacher reacts — right house, right voice, scaled to the score
	var t := _teacher()
	var lines: Array = TEACHER_REACTIONS[t["id"]]
	var tier := 0 if pct >= 100 else (1 if pct >= 75 else (2 if pct >= 50 else (3 if pct > 0 else 4)))
	# AW-63: the teacher WEARS the reaction — emotion portraits per score tier
	var expr: String = ["happy", "happy", "neutral", "worried", "angry"][tier]
	var steps: Array = [{"speaker": t["name"], "side": "right", "portrait": t["id"],
		"expression": expr, "text": "%s  (Score: %d%%)" % [lines[tier], pct]}]
	# a perfect slate earns a spellbook (SPELLBOOKS.md) — one school at a time
	if pct >= 100:
		var award := _next_spellbook()
		if not award.is_empty():
			# a full pack must not eat the book: the award stays pending (unflagged)
			# so the next perfect lesson — or the bookshop — can still deliver it
			if Campaign.grant_weapon("kai", award["weapon"]):
				Campaign.flags[award["flag"]] = true
				Campaign.flags["school_" + str(award["school"])] = true  # WO-8.2: the school opens
				steps.append({"speaker": t["name"], "side": "right", "portrait": t["id"],
					"text": "Kai received %s!" % award["label"]})
			else:
				steps.append({"speaker": t["name"], "side": "right", "portrait": t["id"],
					"text": "Kai's pack is full — clear a slot first."})
		else:
			Campaign.flags["gold"] = int(Campaign.flags.get("gold", 0)) + 60
			steps.append({"speaker": t["name"], "side": "right", "portrait": t["id"],
				"text": "The faculty's spellbook shelf stands empty — take a 60-gold commendation instead."})
	_play_dialogue_json(JSON.stringify(steps))
	_refresh_date()


func _next_spellbook() -> Dictionary:
	for award in SPELLBOOK_LADDER:
		if not bool(Campaign.flags.get(award["flag"], false)) \
				and ResourceLoader.exists(award["weapon"]):
			return award
	return {}


func _start_fishing() -> void:
	if _fishing != null:
		return
	_fishing = FishingGame.new()
	_fishing.finished.connect(_on_fishing_done)
	_ui.add_child(_fishing)


func _on_fishing_done(result: Dictionary) -> void:
	if result["caught"]:
		var fish: String = result["fish"]
		Campaign.add_conduct(2)  # AW-54: trying the school's life feeds Conduct
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
			labels.append(def.display_name + _rank_tag(def.id))
	_menu.open("Fire-pit Cooking — with whom?", labels, _menu_pos())


func _do_cook(index: int) -> void:
	var partners: Array = []
	for def in _roster_defs:
		if def.id != "kai":
			partners.append(def)
	var partner: UnitDef = partners[index]
	Campaign.flags["cooked_week_%d" % Campaign.week] = true
	Campaign.add_conduct(2)  # AW-54
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
		"shop":
			_do_shop(index)
		"tavern":
			_do_tavern(index)
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
			get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")


func _play_dialogue(path: String, on_complete := Callable()) -> bool:
	return _play_script(DialogueScript.from_file(path), on_complete)


## AW-54: play dialogue built at runtime (teacher reactions) — same plumbing.
func _play_dialogue_json(json_text: String, on_complete := Callable()) -> bool:
	return _play_script(DialogueScript.from_json(json_text), on_complete)


## Scripts started while another is on screen wait their turn (the term's report
## card and the Founding Festival can both land on one rest) — never stacked.
var _dialogue_queue: Array[Dictionary] = []


## Start (or queue) a playable script. Returns false without starting when the
## script is missing/malformed/empty, so bookkeeping callers never consume a
## conversation that could not actually play. `on_complete` runs after this
## script — not a queued neighbour — finishes.
func _play_script(script: DialogueScript, on_complete := Callable()) -> bool:
	if not script.is_playable():
		var why := script.error if script.error != "" else "empty script"
		push_warning("castle dialogue skipped: %s" % why)
		return false
	if _dialogue != null:
		_dialogue_queue.append({"script": script, "on_complete": on_complete})
		return true
	var scene := DialogueScene.new()
	_dialogue = scene
	_ui.add_child(scene)
	scene.event_triggered.connect(_on_dialogue_event)
	scene.heart_gate = _heart_available  # AW-57: ♥ options gate on the bond
	scene.finished.connect(func():
		scene.queue_free()
		if _dialogue != scene:
			return  # a late repeat signal never advances someone else's turn
		_dialogue = null
		if on_complete.is_valid():
			on_complete.call()
		if not _dialogue_queue.is_empty():
			var next: Dictionary = _dialogue_queue.pop_front()
			_play_script(next["script"], next["on_complete"]))
	scene.play(script)
	return true


## AW-57: may a ♥ option for `uid` be offered to Kai right now? Needs an A-rank
## bond on a romance-eligible chain, and a heart that's still free (one love —
## Neal's rule; a taken heart or an already-given consent hides the option).
func _heart_available(uid: String) -> bool:
	if _support_state.is_romanced("kai"):
		return false
	var chain := _support_state.chain_for_units("kai", uid)
	if chain == null or not chain.romance_eligible:
		return false
	if bool(_support_state.consents.get(chain.pair_id(), false)):
		return false
	var rank := _support_state.rank_for_units("kai", uid)
	return chain.rank_index(rank) >= chain.rank_index("A")


func _on_dialogue_event(event_name: String, params: Dictionary) -> void:
	match event_name:
		"unlock_school":
			Campaign.flags["school_" + str(params.get("school", ""))] = true
		"set_flag":
			Campaign.flags[str(params.get("flag", ""))] = true
		"conduct":
			# AW-66: quiet-good-deed beats (chantry candles) feed the Conduct mark
			Campaign.add_conduct(int(params.get("points", 1)))
		"bond":
			# AW-57 (Neal): saying the right thing deepens the bond — campus chats
			# carry {"event":"bond","params":{"with":"liora","points":8}} steps.
			var who := str(params.get("with", ""))
			var result := _support_state.add_points("kai", who, int(params.get("points", 5)))
			Campaign.support_save = _support_state.save_state()
			if result.get("ranked_up", false):
				EventBus.support_rank_up.emit(str(result["pair_id"]), str(result["new_rank"]))
				_toast("Your bond with %s deepens — rank %s!" % [who.capitalize(), result["new_rank"]])
		"romance":
			# AW-57: the ♥ choice was taken — consent locks; if the bond's already
			# deep enough, the romance rank blossoms right here.
			var beloved := str(params.get("with", ""))
			var res := _support_state.consent_romance("kai", beloved)
			Campaign.support_save = _support_state.save_state()
			if res.get("ranked_up", false):
				EventBus.support_rank_up.emit(str(res["pair_id"]), SupportChainDef.ROMANCE_RANK)
				_toast("Your heart is set — %s, always. ♥" % beloved.capitalize())
			elif not res.is_empty():
				_toast("Something unspoken settles between you two. ♥")
