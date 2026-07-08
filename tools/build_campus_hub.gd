extends SceneTree
## AW-41: hub-and-spoke campus. The central campus is a clean symmetric QUAD whose
## edge GATES lead to their own themed sub-area maps — the three house dorms (each
## in its colours) and the Sealed Grove — plus the existing Waterside. Nothing is
## piled on one map. House-distinct *building art* is a later PixelLab batch; the
## per-house colour/terrain/layout theming lands here.

const T := Terrain.Type
var ch: ChapterDef
var room: CastleRoomDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(ch.height, y1 + 1)):
		for x in range(max(0, x0), min(ch.width, x1 + 1)):
			ch.set_terrain(x, y, t)


func _decor(path: String, x: int, y: int, solid := false) -> void:
	if not ResourceLoader.exists(path):
		return
	var d := MapDecor.new()
	d.texture = load(path)
	d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)
	if solid and ch.in_bounds(x, y) and ch.get_terrain(x, y) != T.WATER:
		ch.set_terrain(x, y, T.SITE)


func _prop(name: String, x: int, y: int, solid := false) -> void:
	_decor("res://assets/art/pixellab/props/%s.png" % name, x, y, solid)


func _bld(tex: String, ax: int, sx0: int, sx1: int, sy0: int, sy1: int) -> void:
	_decor("res://assets/art_review/campus_v2/%s.png" % tex, ax, sy1)
	for y in range(sy0, sy1 + 1):
		for x in range(sx0, sx1 + 1):
			if ch.in_bounds(x, y):
				ch.set_terrain(x, y, T.SITE)


func _door(cx: int, cy: int, to_room: String, sx: int, sy: int, label: String) -> void:
	ch.set_terrain(cx, cy, T.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(cx, cy); d.to_room = to_room
	d.spawn_cell = Vector2i(sx, sy); d.label = label
	room.doors.append(d)


func _point(id: String, label: String, x: int, y: int, dialogue := "", npc := "", flag := "") -> void:
	var p := CastlePoint.new()
	p.id = id; p.label = label; p.cell = Vector2i(x, y)
	p.dialogue = dialogue; p.npc_unit = npc; p.requires_flag = flag
	room.points.append(p)


func _new_room(id: String, disp: String, w: int, h: int, base: int) -> void:
	ch = ChapterDef.new()
	ch.id = "castle_" + id; ch.display_name = disp; ch.base_terrain = base
	ch.width = w; ch.height = h; ch.fill(base)
	room = CastleRoomDef.new()
	room.id = id; room.display_name = disp; room.chapter = ch


func _frame() -> void:  # a forest border around the current room
	_fill(0, 0, ch.width - 1, 1, T.FOREST); _fill(0, ch.height - 2, ch.width - 1, ch.height - 1, T.FOREST)
	_fill(0, 0, 1, ch.height - 1, T.FOREST); _fill(ch.width - 2, 0, ch.width - 1, ch.height - 1, T.FOREST)


func _initialize() -> void:
	_build_hub()
	# dorm_hall is the shared interior for now; Emberwing's building enters it, and
	# it returns there (split into 3 house interiors is a follow-on).
	var dhc := _dorm_hall_door_cell()
	# house, title, accent terrain, courtyard feature prop, students, back-spawn, interior-entry
	_build_dorm("emberwing_dorm", "Emberwing Quarter", T.EMBERS, "fireplace",
		[["kael", "student_chat_1"], ["dain", "student_chat_2"]], 43, 16, dhc)
	_build_dorm("tidemark_dorm", "Tidemark Quarter", T.SPRING, "well",
		[["osric", "student_chat_1"], ["fenn", "student_chat_2"]], 2, 16, Vector2i(-1, -1))
	_build_dorm("thornrook_dorm", "Thornrook Quarter", T.FLOWERS, "tree_big",
		[["thessaly", "student_chat_1"], ["marlow", "student_chat_2"]], 21, 24, Vector2i(-1, -1))
	_build_grove()
	_patch_dorm_hall()
	quit()


func _dorm_hall_door_cell() -> Vector2i:
	var p := "res://data/castle_v2/dorm_hall.tres"
	if ResourceLoader.exists(p):
		var rm: CastleRoomDef = load(p)
		if not rm.doors.is_empty():
			return rm.doors[0].cell
	return Vector2i(2, 4)


func _patch_dorm_hall() -> void:
	var p := "res://data/castle_v2/dorm_hall.tres"
	if not ResourceLoader.exists(p):
		return
	var rm: CastleRoomDef = load(p)
	for d in rm.doors:
		if d.to_room == "campus":
			d.to_room = "emberwing_dorm"
			d.spawn_cell = Vector2i(14, 8)  # below the Emberwing dorm's front door
	ResourceSaver.save(rm, p)
	print("dorm_hall re-aimed to emberwing_dorm")


func _build_hub() -> void:
	_new_room("campus", "The Campus", 46, 32, T.PLAINS)
	var cx := 22
	_frame()
	_fill(cx - 1, 2, cx, 29, T.PATH)          # N–S promenade
	_fill(2, 15, 43, 16, T.PATH)              # E–W promenade
	_fill(17, 12, 27, 19, T.CARPET)           # plaza
	_decor("res://assets/art_review/campus_v2/fountain_plaza.png", cx - 1, 16, true)
	for s in [[18, 13], [26, 13], [18, 18], [26, 18]]:
		_prop("statue_founder", s[0], s[1], true)
	for b in [[20, 12], [24, 12], [20, 19], [24, 19]]:
		ch.set_terrain(b[0], b[1], T.FLOWERS)
	_prop("bench_stone", 19, 16); _prop("bench_stone", 25, 16)
	_bld("great_hall_v2", cx - 1, cx - 4, cx + 3, 3, 6); _fill(cx - 1, 7, cx, 11, T.PATH)
	_bld("library_v2", 7, 5, 11, 3, 6); _fill(8, 7, 8, 14, T.PATH)
	_bld("classroom_hall", 37, 33, 41, 3, 6); _fill(38, 7, 38, 14, T.PATH)
	_bld("gatehouse_v2", cx - 1, cx - 3, cx + 2, 26, 28)
	# the gates to the sub-areas
	_door(1, 16, "tidemark_dorm", 26, 10, "▶ Tidemark Quarter")
	_door(44, 16, "emberwing_dorm", 3, 10, "▶ Emberwing Quarter")
	_door(cx - 1, 25, "thornrook_dorm", 3, 10, "▶ Thornrook Quarter")
	_fill(6, 16, 6, 27, T.PATH); _door(6, 28, "grove", 10, 2, "▶ The Sealed Grove")
	_fill(39, 16, 39, 27, T.PATH); _door(39, 28, "waterside", 12, 9, "▶ The Waterside")
	# academic-hall doors
	_door(8, 7, "library", 9, 10, "The Library Tower")
	_door(38, 7, "classroom", 10, 9, "The Classrooms")
	_door(cx, 7, "entrance", 11, 11, "The Great Hall")
	_door(38, 12, "training", 2, 6, "The Training Grounds")  # NE, off the classroom stub
	for y in range(4, 29, 4):
		_prop("street_lamp", cx - 3, y); _prop("street_lamp", cx + 2, y)
	for xy in [[5, 5], [40, 5], [5, 25], [40, 25], [12, 22], [33, 22]]:
		_prop("tree_big", xy[0], xy[1], true)
	_point("fn_deploy", "Mission Board", cx, 20)
	_point("maren_chat", "Talk to Warden Maren", 24, 20, "res://data/dialogue/castle_maren.json", "maren")
	print("hub err=%d doors=%d" % [ResourceSaver.save(room, "res://data/castle_v2/campus.tres"), room.doors.size()])
	var respawn := {"entrance": Vector2i(cx, 8), "library": Vector2i(8, 8),
		"classroom": Vector2i(38, 8), "waterside": Vector2i(39, 27), "training": Vector2i(38, 13)}
	for rid in respawn:
		var p := "res://data/castle_v2/%s.tres" % rid
		if ResourceLoader.exists(p):
			var rm: CastleRoomDef = load(p)
			for d in rm.doors:
				if d.to_room == "campus":
					d.spawn_cell = respawn[rid]
			ResourceSaver.save(rm, p)


## One themed house quarter — same layout, house-specific terrain + feature.
func _build_dorm(id: String, disp: String, accent: int, feature: String, students: Array, back_x: int, back_y: int, interior_entry: Vector2i) -> void:
	_new_room(id, disp, 30, 22, T.PLAINS)
	_frame()
	_fill(2, 10, 27, 11, T.PATH)      # the avenue in from the campus gate
	_fill(14, 5, 15, 11, T.PATH)      # up to the dorm
	_bld("dormitory_v2", 14, 10, 19, 3, 6)
	_fill(11, 13, 18, 17, T.CARPET)   # courtyard
	for e in [[11, 13], [18, 13], [11, 17], [18, 17], [14, 15]]:
		ch.set_terrain(e[0], e[1], accent)   # the house's magical courtyard tiles
	if feature == "tree_big":
		_prop("tree_big", 14, 15, true)
	else:
		_prop(feature, 14, 15, true)
	_prop("statue_founder", 8, 14, true)
	for b in [[12, 7], [17, 7], [6, 10], [22, 10]]:
		_prop("banner_pair", b[0], b[1])
	for l in [[10, 12], [19, 12], [10, 18], [19, 18]]:
		_prop("street_lamp", l[0], l[1])
	for tx in [[4, 5], [25, 5], [4, 17], [25, 16]]:
		_prop("tree_big", tx[0], tx[1], true)
	_prop("bench_stone", 12, 12); _prop("bench_stone", 17, 12)
	# the gate back to the campus is on whichever edge faces the hub
	# Tidemark sits west of the hub so you enter/leave via its EAST edge; the
	# others enter from the WEST. (Gates are portals — the geography is cosmetic.)
	if id == "tidemark_dorm":
		_door(28, 10, "campus", back_x, back_y, "◀ To the Campus")
	else:
		_door(1, 10, "campus", back_x, back_y, "◀ To the Campus")
	# the dorm building's front door leads inside (shared dorm_hall for now)
	if interior_entry != Vector2i(-1, -1):
		_door(14, 7, "dorm_hall", interior_entry.x, interior_entry.y, "Enter the Dormitory")
	_point(id + "_rest", "Rest at the dormitory", 14, 15)
	var sx := 20
	for s in students:
		_point("walk_" + s[0], "Chat with a student", sx, 14,
			"res://data/dialogue/%s.json" % s[1], s[0])
		sx = 9
	print("%s err=%d" % [id, ResourceSaver.save(room, "res://data/castle_v2/%s.tres" % id)])


## The Sealed Grove — an accessible wood with the First Crown standing stone.
func _build_grove() -> void:
	_new_room("grove", "The Sealed Grove", 26, 24, T.FOREST)
	# clearings of grass carved through the wood, a winding path to the stone
	_fill(8, 2, 17, 21, T.PLAINS)
	_fill(2, 10, 23, 12, T.PLAINS)
	_fill(9, 2, 10, 20, T.PATH)
	# scatter dense trees through the wooded frame
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for y in range(2, 22):
		for x in range(2, 24):
			if ch.get_terrain(x, y) == T.FOREST and rng.randf() < 0.35:
				_prop("tree_big", x, y, true)
	# the First Crown standing stone in a mossy clearing at the heart
	_fill(11, 14, 15, 18, T.PLAINS)
	_prop("rocks", 13, 16, true)
	_point("first_crown_stone", "The First Crown Stone", 13, 17, "res://data/dialogue/lore_wardstones.json")
	_prop("stump", 11, 8); _prop("bush", 16, 6); _prop("bush", 12, 19)
	for f in [[10, 5], [15, 9], [11, 12]]:
		ch.set_terrain(f[0], f[1], T.FLOWERS)
	_door(9, 1, "campus", 6, 27, "◀ To the Campus")
	print("grove err=%d" % ResourceSaver.save(room, "res://data/castle_v2/grove.tres"))
