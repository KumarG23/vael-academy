extends SceneTree
## AW-40: the grand campus — a massive, explorable magic-school grounds. Procedural
## terrain (grass, a forest border, the Sealed Grove, a lake), tree-lined avenues,
## a central plaza with the whispering fountain + Founders' Statues, all the
## academic halls, THREE house dorms in their colours, lore landmarks, and heavy
## foliage. Reuses the existing interior rooms; re-aims their return doors.

const W := 68
const H := 50
const T_PLAINS := Terrain.Type.PLAINS
const T_FOREST := Terrain.Type.FOREST
const T_PATH := Terrain.Type.PATH
const T_FLOWERS := Terrain.Type.FLOWERS
const T_WATER := Terrain.Type.WATER
const T_CARPET := Terrain.Type.CARPET
const T_SITE := Terrain.Type.SITE

var ch: ChapterDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(H, y1 + 1)):
		for x in range(max(0, x0), min(W, x1 + 1)):
			ch.set_terrain(x, y, t)


func _hpath(y: int, x0: int, x1: int, wide := 1) -> void:
	for dy in range(wide):
		_fill(x0, y + dy, x1, y + dy, T_PATH)


func _vpath(x: int, y0: int, y1: int, wide := 1) -> void:
	for dx in range(wide):
		_fill(x + dx, y0, x + dx, y1, T_PATH)


func _decor(path: String, x: int, y: int, solid := false) -> void:
	if not ResourceLoader.exists(path):
		return
	var d := MapDecor.new()
	d.texture = load(path)
	d.cell = Vector2i(x, y)
	var cw := int(ceil((d.texture as Texture2D).get_width() / 32.0))
	if cw % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)
	if solid and ch.in_bounds(x, y) and ch.get_terrain(x, y) != T_WATER:
		ch.set_terrain(x, y, T_SITE)


func _prop(name: String, x: int, y: int, solid := false) -> void:
	_decor("res://assets/art/pixellab/props/%s.png" % name, x, y, solid)


func _building(tex: String, ax: int, ay: int, sx0: int, sx1: int, sy0: int, sy1: int) -> void:
	_decor("res://assets/art_review/campus_v2/%s.png" % tex, ax, ay)
	for y in range(sy0, sy1 + 1):
		for x in range(sx0, sx1 + 1):
			if ch.in_bounds(x, y):
				ch.set_terrain(x, y, T_SITE)


func _tree(x: int, y: int) -> void:
	_prop("tree_big", x, y, true)


func _door(cell: Vector2i, to_room: String, spawn: Vector2i, label: String) -> void:
	ch.set_terrain(cell.x, cell.y, T_PATH)
	var d := CastleDoor.new()
	d.cell = cell
	d.to_room = to_room
	d.spawn_cell = spawn
	d.label = label
	_room.doors.append(d)


var _room: CastleRoomDef


func _point(id: String, label: String, x: int, y: int, dialogue := "", npc := "", flag := "") -> void:
	var p := CastlePoint.new()
	p.id = id
	p.label = label
	p.cell = Vector2i(x, y)
	p.dialogue = dialogue
	p.npc_unit = npc
	p.requires_flag = flag
	_room.points.append(p)


func _initialize() -> void:
	ch = ChapterDef.new()
	ch.id = "castle_campus"
	ch.display_name = "The Campus"
	ch.base_terrain = T_PLAINS
	ch.width = W
	ch.height = H
	ch.fill(T_PLAINS)
	_room = CastleRoomDef.new()
	_room.id = "campus"
	_room.display_name = "The Campus"
	_room.chapter = ch

	# ---- terrain -------------------------------------------------------------
	# forest border (2 thick) all around — the enclosing woods
	_fill(0, 0, W - 1, 1, T_FOREST)
	_fill(0, H - 2, W - 1, H - 1, T_FOREST)
	_fill(0, 0, 1, H - 1, T_FOREST)
	_fill(W - 2, 0, W - 1, H - 1, T_FOREST)
	# the Sealed Grove — dense wood, SW
	_fill(2, 34, 15, 47, T_FOREST)
	# the lake (Waterside) — NE
	_fill(52, 32, 63, 45, T_WATER)
	_fill(50, 34, 51, 44, T_PLAINS)  # a grassy shore

	# grand avenues: a cross through the middle, tree-lined
	_vpath(33, 2, H - 3, 3)      # main north-south promenade
	_hpath(24, 2, W - 3, 3)      # main east-west promenade
	# a ring boulevard around the central plaza
	_hpath(18, 22, 45)
	_hpath(31, 22, 45)
	_vpath(22, 18, 31)
	_vpath(45, 18, 31)

	# central plaza — carpeted, with the whispering fountain
	_fill(28, 20, 40, 29, T_CARPET)
	_decor("res://assets/art_review/campus_v2/fountain_plaza.png", 33, 24, true)
	# Founders' Statues — the four founding lines around the fountain
	for s in [[29, 21], [39, 21], [29, 28], [39, 28]]:
		_prop("statue_founder", s[0], s[1], true)
	# flower beds + benches ringing the plaza
	for f in [[31, 20], [37, 20], [31, 29], [37, 29]]:
		ch.set_terrain(f[0], f[1], T_FLOWERS)
	for b in [[30, 24], [40, 24], [34, 20], [34, 29]]:
		_prop("bench_stone", b[0], b[1])

	# ---- buildings -----------------------------------------------------------
	# academic halls along the north
	_building("great_hall_v2", 29, 6, 29, 38, 4, 8)      # dining / great hall (centre-north)
	_building("library_v2", 8, 7, 7, 14, 4, 8)           # Library Tower (NW)
	_building("classroom_hall", 50, 6, 48, 58, 4, 8)     # Classrooms (NE)
	# three house dorms, one per wing, in their colours
	_building("dormitory_v2", 4, 24, 3, 12, 22, 26)      # Tidemark dorm (W)
	_building("dormitory_v2", 54, 24, 52, 62, 22, 26)    # Emberwing dorm (E)
	_building("dormitory_v2", 27, 40, 26, 35, 38, 42)    # Thornrook dorm (S)
	# training yard (far E, below the classroom) + the south gate to Vael town
	_building("gatehouse_v2", 30, 46, 30, 37, 45, 48)

	# ---- doors (to the existing interiors) -----------------------------------
	_door(Vector2i(33, 9), "entrance", Vector2i(11, 11), "The Great Hall")
	_door(Vector2i(10, 9), "library", Vector2i(9, 10), "The Library Tower")
	_door(Vector2i(53, 9), "classroom", Vector2i(10, 9), "The Classrooms")
	_door(Vector2i(8, 27), "dorm_hall", Vector2i(2, 4), "Tidemark Dormitory")
	_door(Vector2i(58, 27), "dorm_hall", Vector2i(2, 4), "Emberwing Dormitory")
	_door(Vector2i(31, 43), "dorm_hall", Vector2i(2, 4), "Thornrook Dormitory")
	_door(Vector2i(48, 30), "training", Vector2i(2, 6), "The Training Grounds")
	_door(Vector2i(51, 38), "waterside", Vector2i(12, 9), "The Waterside")

	# house banners flanking each dorm door
	for b in [[7, 26], [9, 26], [57, 26], [59, 26], [30, 42], [32, 42]]:
		_prop("banner_pair", b[0], b[1])

	# ---- lore landmarks ------------------------------------------------------
	# the First Crown standing stone, deep in the Sealed Grove
	_prop("rocks", 7, 41, true)
	_point("first_crown_stone", "The First Crown Stone", 8, 42,
		"res://data/dialogue/lore_wardstones.json")
	# a quiet reading nook by the lake
	_prop("bench", 50, 40)
	# the notice board / mission board on the plaza, + Warden Maren
	_point("fn_deploy", "Mission Board", 34, 30)
	_point("maren_chat", "Talk to Warden Maren", 36, 26, "res://data/dialogue/castle_maren.json", "maren")

	# ---- heavy foliage: tree-lined avenues, groves, scattered oaks -----------
	# line the north-south promenade with alternating trees + lamps
	for y in range(4, H - 3, 3):
		_tree(30, y)
		_prop("street_lamp", 37, y + 1)
	# line the east-west promenade
	for x in range(6, W - 3, 4):
		if ch.get_terrain(x, 21) == T_PLAINS:
			_tree(x, 21)
		if ch.get_terrain(x, 28) == T_PLAINS:
			_prop("street_lamp", x, 28)
	# fill the Sealed Grove with dense trees
	for gx in range(3, 15, 2):
		for gy in range(35, 47, 2):
			if ch.get_terrain(gx, gy) == T_FOREST and randf() < 0.7:
				_tree(gx, gy)
	# a hedge maze corner (NE, below the classrooms) + scattered oaks everywhere
	for h in range(46, 60, 2):
		_prop("hedge", h, 12)
	# scattered oaks + bushes across the open lawns
	var rng := RandomNumberGenerator.new()
	rng.seed = 704
	var oaks := 0
	while oaks < 46:
		var x := rng.randi_range(3, W - 4)
		var y := rng.randi_range(3, H - 4)
		if ch.get_terrain(x, y) == T_PLAINS and not _near_path(x, y):
			if rng.randf() < 0.6:
				_tree(x, y)
			else:
				_prop("bush", x, y)
			oaks += 1
	# flower meadows in a couple of open corners
	_fill(4, 4, 7, 6, T_FLOWERS)
	_fill(60, 46, 63, 47, T_FLOWERS)

	# ---- NPCs: students gathered near their house dorms ----------------------
	_point("walk_kael", "Chat with a student", 55, 28, "res://data/dialogue/student_chat_1.json", "kael")
	_point("walk_dain", "Chat with a student", 12, 28, "res://data/dialogue/student_chat_2.json", "dain")
	_point("walk_thessaly", "Chat with a student", 29, 44, "res://data/dialogue/student_chat_1.json", "thessaly")
	_point("walk_liora", "Chat with a student", 38, 22, "res://data/dialogue/student_chat_2.json", "liora")
	_point("walk_fenn", "Chat with a student", 45, 25, "res://data/dialogue/student_chat_1.json", "fenn")

	var err := ResourceSaver.save(_room, "res://data/castle_v2/campus.tres")
	print("grand campus %dx%d saved err=%d  decor=%d doors=%d points=%d" % [W, H, err, ch.decor.size(), _room.doors.size(), _room.points.size()])

	# re-aim the interior rooms' return doors at the new campus door cells
	var respawn := {
		"entrance": Vector2i(33, 10), "library": Vector2i(10, 10), "classroom": Vector2i(53, 10),
		"dorm_hall": Vector2i(8, 28), "training": Vector2i(48, 31), "waterside": Vector2i(51, 39),
	}
	for rid in respawn:
		var p := "res://data/castle_v2/%s.tres" % rid
		if not ResourceLoader.exists(p):
			continue
		var rm: CastleRoomDef = load(p)
		for d in rm.doors:
			if d.to_room == "campus":
				d.spawn_cell = respawn[rid]
		ResourceSaver.save(rm, p)
	print("interiors re-aimed")
	quit()


func _near_path(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if ch.in_bounds(x + dx, y + dy) and ch.get_terrain(x + dx, y + dy) == T_PATH:
				return true
	return false
