extends SceneTree
## AW-66: the Town of Vael (M10, TOWN_OF_VAEL.md) — hub-and-spoke on the castle
## toolkit: the Square (hub), the Market (working shops), the Castle Gate
## (sealed, story), the Cathedral, and the Riverside (tavern/playhouse/pier).
## Patches the campus gatehouse with the town road door. Idempotent-ish: rooms
## are regenerated wholesale; the campus patch guards on an existing door.

const T := Terrain.Type
const BLD := "res://assets/art/pixellab/buildings/vael"
var ch: ChapterDef
var room: CastleRoomDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(ch.height, y1 + 1)):
		for x in range(max(0, x0), min(ch.width, x1 + 1)):
			ch.set_terrain(x, y, t)


func _decor(path: String, x: int, y: int, solid_box := Rect2i(0, 0, 0, 0)) -> void:
	if not ResourceLoader.exists(path):
		push_warning("missing: " + path)
		return
	var d := MapDecor.new()
	d.texture = load(path)
	d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)
	for by in range(solid_box.position.y, solid_box.position.y + solid_box.size.y):
		for bx in range(solid_box.position.x, solid_box.position.x + solid_box.size.x):
			if ch.in_bounds(bx, by):
				ch.set_terrain(bx, by, T.SITE)


func _bld(name: String, x: int, y: int, solid_box := Rect2i(0, 0, 0, 0)) -> void:
	_decor("%s/%s.png" % [BLD, name], x, y, solid_box)


func _prop(name: String, x: int, y: int, solid := false) -> void:
	var path := "res://assets/art/pixellab/props/%s.png" % name
	if not ResourceLoader.exists(path):
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
	ch.set_terrain(cx, cy, T.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(cx, cy)
	d.to_room = to_room
	d.spawn_cell = Vector2i(sx, sy)
	d.label = label
	room.doors.append(d)


func _point(id: String, label: String, x: int, y: int, dialogue := "", npc := "") -> void:
	var p := CastlePoint.new()
	p.id = id
	p.label = label
	p.cell = Vector2i(x, y)
	p.dialogue = dialogue
	p.npc_unit = npc
	room.points.append(p)


func _new_room(id: String, disp: String, w: int, h: int) -> void:
	ch = ChapterDef.new()
	ch.id = "castle_" + id
	ch.display_name = disp
	ch.base_terrain = T.PLAINS
	ch.width = w
	ch.height = h
	ch.fill(T.PLAINS)
	room = CastleRoomDef.new()
	room.id = id
	room.display_name = disp
	room.chapter = ch


func _save() -> void:
	print("%s err=%d decor=%d doors=%d" % [room.id,
		ResourceSaver.save(room, "res://data/castle_v2/%s.tres" % room.id),
		ch.decor.size(), room.doors.size()])


func _initialize() -> void:
	_build_square()
	_build_market()
	_build_castle_gate()
	_build_cathedral()
	_build_riverside()
	_patch_campus()
	quit()


func _build_square() -> void:
	_new_room("vael_square", "Vael — Town Square", 34, 24)
	_fill(4, 4, 29, 19, T.PATH)                      # the paved square
	_fill(16, 1, 18, 4, T.PATH)                      # north road under the gate
	_bld("city_gate", 17, 3, Rect2i(13, 1, 8, 2))    # arch over the north road (sides solid)
	ch.set_terrain(17, 1, T.PATH)
	ch.set_terrain(17, 2, T.PATH)
	_bld("fountain_grand", 17, 13, Rect2i(15, 11, 4, 3))
	_bld("statue_king", 17, 7, Rect2i(17, 7, 1, 1))
	_bld("townhouse_a", 6, 8, Rect2i(4, 5, 5, 4))
	_bld("townhouse_b", 27, 8, Rect2i(25, 5, 5, 4))
	_bld("townhouse_c", 6, 20, Rect2i(4, 17, 5, 4))
	_bld("townhouse_a", 27, 20, Rect2i(25, 17, 5, 4))
	for l in [[12, 10], [22, 10], [12, 17], [22, 17]]:
		_prop("street_lamp", l[0], l[1])
	_prop("notice_board", 20, 8)
	_prop("bench_stone", 14, 15)
	_prop("bench_stone", 20, 15)
	_point("notice_board", "The town notice board", 20, 9, "res://data/dialogue/vael_notice_board.json")
	_point("townsfolk_gossip", "Listen to the townsfolk", 14, 16, "res://data/dialogue/vael_gossip.json")
	_door(17, 1, "campus", 21, 29, "◀ The Academy Road")
	_door(1, 12, "vael_market", 23, 9, "▶ The Market")
	_door(32, 12, "vael_cathedral", 3, 10, "▶ Chantry Square")
	_door(26, 1, "vael_castle_gate", 13, 17, "▶ The King's Castle")
	_door(17, 22, "vael_riverside", 15, 2, "▶ The Riverside")
	_save()


func _build_market() -> void:
	_new_room("vael_market", "Vael — The Market", 26, 18)
	_fill(2, 4, 23, 14, T.PATH)
	_bld("smithy", 5, 6, Rect2i(3, 3, 5, 4))
	_bld("shop_goods", 13, 6, Rect2i(11, 3, 5, 4))
	_bld("shop_magic", 21, 6, Rect2i(19, 3, 5, 4))
	_bld("market_stall_a", 8, 11, Rect2i(7, 10, 2, 2))
	_bld("market_stall_b", 16, 11, Rect2i(15, 10, 2, 2))
	_prop("crates", 3, 12)
	_prop("barrels", 22, 12)
	_prop("cart", 12, 14)
	_point("fn_shop_smith", "The Smithy", 5, 8)
	_point("fn_shop_goods", "Reach & Barrel — Goods", 13, 8)
	_point("fn_shop_magic", "The Arcane Bookshop", 21, 8)
	_door(25, 9, "vael_square", 3, 12, "◀ Town Square")
	_save()


func _build_castle_gate() -> void:
	_new_room("vael_castle_gate", "Vael — The King's Castle", 26, 20)
	_fill(11, 8, 15, 19, T.PATH)                      # the approach avenue
	_bld("kings_castle", 13, 8, Rect2i(7, 2, 13, 7))  # the castle dominates the north
	for b in [[9, 10], [17, 10]]:
		_prop("banner_pair", b[0], b[1])
	for l in [[10, 13], [16, 13]]:
		_prop("street_lamp", l[0], l[1])
	# the gates are SEALED — royal guards turn students away (story-gated)
	_point("castle_guard_west", "Speak with the royal guard", 11, 9,
		"res://data/dialogue/vael_castle_guard.json", "tm_armor")
	_point("castle_guard_east", "Speak with the royal guard", 15, 9,
		"res://data/dialogue/vael_castle_guard.json", "tm_armor")
	_door(13, 19, "vael_square", 26, 2, "◀ Town Square")
	_save()


func _build_cathedral() -> void:
	_new_room("vael_cathedral", "Vael — The Grand Chantry", 24, 20)
	_fill(9, 8, 14, 19, T.PATH)
	_fill(8, 15, 15, 17, T.PATH)
	_bld("cathedral", 11, 8, Rect2i(6, 1, 11, 8))
	for f in [[7, 16], [16, 16]]:
		ch.set_terrain(f[0], f[1], T.FLOWERS)
	_prop("statue_founder", 6, 12, true)
	_prop("statue_founder", 17, 12, true)
	_point("chantry_candles", "Light a candle", 10, 9,
		"res://data/dialogue/vael_candles.json")
	_point("chantry_scripture", "Read the carved scripture", 13, 9,
		"res://data/dialogue/vael_scripture.json")
	_door(1, 10, "vael_square", 30, 12, "◀ Town Square")
	_save()


func _build_riverside() -> void:
	_new_room("vael_riverside", "Vael — The Riverside", 30, 18)
	_fill(0, 14, 29, 17, T.WATER)                     # the river along the south
	_fill(2, 3, 27, 12, T.PATH)
	_fill(13, 12, 16, 14, T.PATH)                     # the pier stem
	_bld("tavern", 6, 7, Rect2i(3, 2, 7, 6))
	_bld("playhouse", 23, 7, Rect2i(20, 2, 7, 6))
	_bld("rowboat", 20, 15, Rect2i(0, 0, 0, 0))
	_bld("rowboat", 9, 15, Rect2i(0, 0, 0, 0))
	_prop("barrels", 11, 9)
	_prop("street_lamp", 15, 8)
	_point("fn_tavern", "The Gilded Stag — share a meal", 6, 9)
	_point("playhouse_sign", "The playhouse bill", 23, 9,
		"res://data/dialogue/vael_playhouse.json")
	_point("fn_fish", "Fish off the pier", 14, 13)
	_door(15, 1, "vael_square", 17, 21, "◀ Town Square")
	_save()


## The campus gatehouse finally opens onto the town road.
func _patch_campus() -> void:
	var p := "res://data/castle_v2/campus.tres"
	var rm: CastleRoomDef = load(p)
	for d in rm.doors:
		if d.to_room == "vael_square":
			print("campus already roads to Vael")
			return
	var cch: ChapterDef = rm.chapter
	cch.set_terrain(21, 29, Terrain.Type.PATH)
	cch.set_terrain(22, 29, Terrain.Type.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(22, 29)
	d.to_room = "vael_square"
	d.spawn_cell = Vector2i(17, 3)
	d.label = "▶ The Town of Vael"
	rm.doors.append(d)
	print("campus patched err=%d" % ResourceSaver.save(rm, p))
