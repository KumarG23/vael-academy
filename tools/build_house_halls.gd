extends SceneTree
## AW-65: the school's interiors grow up (Neal's oldest open asks):
##   1. The Great Hall (`entrance`) becomes a HOGWARTS DINING HALL — long house
##      tables, a head table, fireplaces, banners. Doors/spawns/Oath Wall stay
##      exactly where other rooms expect them.
##   2. The shared `dorm_hall` splits into THREE house halls (emberwing_hall /
##      tidemark_hall / thornrook_hall), each themed, bedded, with fn_rest, and
##      wired to its own quarter. dorm_hall.tres is deleted by the caller.

const T := Terrain.Type
var ch: ChapterDef
var room: CastleRoomDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(ch.height, y1 + 1)):
		for x in range(max(0, x0), min(ch.width, x1 + 1)):
			ch.set_terrain(x, y, t)


func _prop(name: String, x: int, y: int, solid := false) -> void:
	var path := "res://assets/art/pixellab/props/%s.png" % name
	if not ResourceLoader.exists(path):
		push_warning("missing prop: " + name)
		return
	var d := MapDecor.new()
	d.texture = load(path)
	d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)
	if solid and ch.in_bounds(x, y):
		ch.set_terrain(x, y, T.SITE)


func _door(cx: int, cy: int, to_room: String, sx: int, sy: int, label: String) -> void:
	var d := CastleDoor.new()
	d.cell = Vector2i(cx, cy)
	d.to_room = to_room
	d.spawn_cell = Vector2i(sx, sy)
	d.label = label
	room.doors.append(d)


func _point(id: String, label: String, x: int, y: int, dialogue := "") -> void:
	var p := CastlePoint.new()
	p.id = id
	p.label = label
	p.cell = Vector2i(x, y)
	p.dialogue = dialogue
	room.points.append(p)


func _initialize() -> void:
	_build_great_hall()
	_build_house_hall("emberwing_hall", "Emberwing Hall", "emberwing_dorm", "bed_ember",
		T.EMBERS, "fireplace")
	_build_house_hall("tidemark_hall", "Tidemark Hall", "tidemark_dorm", "bed_tide",
		T.SPRING, "well")
	_build_house_hall("thornrook_hall", "Thornrook Hall", "thornrook_dorm", "bed_thorn",
		T.FLOWERS, "bookshelf")
	_rewire_quarters()
	quit()


## The Great Hall — refurnished in place: same id/size, same door cells and
## spawn targets, the Oath Wall stays at (4,2).
func _build_great_hall() -> void:
	room = load("res://data/castle_v2/entrance.tres")
	ch = room.chapter
	ch.decor.clear()
	ch.fill(T.PLAINS)  # interiors store open floor as PLAINS (render fill = FLOOR)
	# the hall's wall ring (door cells stay open below)
	for x in range(ch.width):
		ch.set_terrain(x, 0, T.WALL)
		ch.set_terrain(x, ch.height - 1, T.WALL)
	for y in range(ch.height):
		ch.set_terrain(0, y, T.WALL)
		ch.set_terrain(ch.width - 1, y, T.WALL)
	for dc in [[11, 12], [0, 6], [21, 6]]:
		ch.set_terrain(dc[0], dc[1], T.PLAINS)
	# head table across the top, flanked by founder statues, banners above
	for x in [8, 10, 12, 14]:
		_prop("long_table", x, 2, true)
	_prop("statue_founder", 6, 2, true)
	_prop("statue_founder", 16, 2, true)
	_prop("banner_pair", 9, 1)
	_prop("banner_pair", 13, 1)
	# three long house tables per side, a grand central aisle to the head table
	for y in [5, 9]:
		for x in [3, 5, 7]:
			_prop("long_table", x, y, true)
		for x in [14, 16, 18]:
			_prop("long_table", x, y, true)
	# benches flanking the table rows (walkable seating clutter)
	for y in [4, 8]:
		for x in [4, 6, 15, 17]:
			_prop("bench", x, y)
	# hearths, sideboard clutter
	_prop("fireplace", 1, 3, true)
	_prop("fireplace", 20, 3, true)
	_prop("barrels", 1, 11)
	_prop("crates", 20, 11)
	_prop("notice_board", 2, 11)
	print("great hall err=%d decor=%d" % [ResourceSaver.save(room, "res://data/castle_v2/entrance.tres"), ch.decor.size()])


## One house dormitory hall: beds along the back wall, the house's magical
## feature, its accent terrain, fn_rest, and the door back to its quarter.
func _build_house_hall(id: String, disp: String, quarter: String, bed: String,
		accent: int, feature: String) -> void:
	ch = ChapterDef.new()
	ch.id = "castle_" + id
	ch.display_name = disp
	ch.base_terrain = T.FLOOR
	ch.width = 16
	ch.height = 10
	ch.fill(T.PLAINS)
	room = CastleRoomDef.new()
	room.id = id
	room.display_name = disp
	room.chapter = ch
	# beds along the back wall
	for x in [2, 5, 8, 11]:
		_prop(bed, x, 2, true)
	# the house feature + accent tiles at the hall's heart
	_prop(feature, 14, 3, true)
	for a in [[3, 5], [8, 5], [13, 6]]:
		ch.set_terrain(a[0], a[1], accent)
	_prop("banner_pair", 6, 1)
	_prop("bookshelf", 14, 6, true)
	_prop("crates", 1, 8)
	_prop("notice_board", 15, 8)
	_point("fn_rest", "Rest until next week", 7, 6)
	_door(7, 9, quarter, 14, 8, "◀ To the Quarter")
	print("%s err=%d" % [id, ResourceSaver.save(room, "res://data/castle_v2/%s.tres" % id)])


## Every quarter's dorm building now opens into ITS OWN hall.
func _rewire_quarters() -> void:
	var map := {
		"emberwing_dorm": "emberwing_hall",
		"tidemark_dorm": "tidemark_hall",
		"thornrook_dorm": "thornrook_hall",
	}
	for qid in map:
		var q: CastleRoomDef = load("res://data/castle_v2/%s.tres" % qid)
		var hall: String = map[qid]
		var had := false
		for d in q.doors:
			if d.to_room == "dorm_hall" or d.to_room == hall:
				d.to_room = hall
				d.spawn_cell = Vector2i(7, 8)  # just inside the hall door
				d.label = "Enter the Dormitory"
				had = true
		if not had:
			var d := CastleDoor.new()
			d.cell = Vector2i(14, 7)  # the building's front door (below the facade)
			d.to_room = hall
			d.spawn_cell = Vector2i(7, 8)
			d.label = "Enter the Dormitory"
			q.doors.append(d)
			q.chapter.set_terrain(14, 7, Terrain.Type.PATH)
		print("%s -> %s err=%d" % [qid, hall, ResourceSaver.save(q, "res://data/castle_v2/%s.tres" % qid)])
