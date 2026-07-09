extends SceneTree
## AW-67: walk-in interiors for Vael — the goods shop, smithy, arcane bookshop,
## the Gilded Stag's taproom, and the Chantry nave. Shopkeepers stand at their
## counters (fn point + npc sprite in one), and the shop/tavern/candle points
## MOVE INSIDE; the exteriors become doors.

const T := Terrain.Type
const BLD := "res://assets/art/pixellab/props"
var ch: ChapterDef
var room: CastleRoomDef


func _prop(name: String, x: int, y: int, solid := false) -> void:
	var path := "%s/%s.png" % [BLD, name]
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
	ch.set_terrain(cx, cy, T.PLAINS)
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
	ch.base_terrain = T.FLOOR
	ch.width = w
	ch.height = h
	ch.fill(T.PLAINS)
	for x in range(w):
		ch.set_terrain(x, 0, T.WALL)
		ch.set_terrain(x, h - 1, T.WALL)
	for y in range(h):
		ch.set_terrain(0, y, T.WALL)
		ch.set_terrain(w - 1, y, T.WALL)
	room = CastleRoomDef.new()
	room.id = id
	room.display_name = disp
	room.chapter = ch


func _save() -> void:
	print("%s err=%d" % [room.id, ResourceSaver.save(room, "res://data/castle_v2/%s.tres" % room.id)])


func _initialize() -> void:
	_goods_shop()
	_smithy()
	_magic_shop()
	_tavern()
	_chantry()
	_rewire_exteriors()
	quit()


func _goods_shop() -> void:
	_new_room("vael_goods_shop", "Reach & Barrel", 14, 10)
	for x in [2, 5, 8, 11]:
		_prop("stocked_shelf", x, 2, true)
	_prop("shop_counter", 7, 4, true)
	_prop("crates", 2, 7)
	_prop("barrels", 11, 7)
	# Marta stands behind her counter; talking to her IS the shop
	_point("fn_shop_goods", "Reach & Barrel — browse the goods", 7, 3,
		"res://data/dialogue/vael_marta.json", "marta")
	_door(7, 9, "vael_market", 13, 8, "◀ The Market")
	_save()


func _smithy() -> void:
	_new_room("vael_smithy", "Bram's Forge", 14, 10)
	_prop("forge_anvil", 3, 3, true)
	for x in [8, 11]:
		_prop("weapon_rack", x, 2, true)
	_prop("shop_counter", 7, 4, true)
	_prop("barrels", 2, 7)
	_point("fn_shop_smith", "The Smithy — buy arms", 7, 3,
		"res://data/dialogue/vael_bram.json", "bram")
	_door(7, 9, "vael_market", 5, 8, "◀ The Market")
	_save()


func _magic_shop() -> void:
	_new_room("vael_magic_shop", "The Arcane Bookshop", 14, 10)
	for x in [2, 5, 8, 11]:
		_prop("bookshelf", x, 2, true)
	_prop("stocked_shelf", 12, 5, true)
	_prop("shop_counter", 7, 4, true)
	for c in [[3, 6], [10, 6]]:
		ch.set_terrain(c[0], c[1], T.CARPET)
	_point("fn_shop_magic", "The Arcane Bookshop — rare spellbooks", 7, 3,
		"res://data/dialogue/vael_sylvie.json", "sylvie")
	_door(7, 9, "vael_market", 21, 8, "◀ The Market")
	_save()


func _tavern() -> void:
	_new_room("vael_tavern", "The Gilded Stag", 18, 12)
	_prop("bar_counter", 13, 3, true)
	_prop("fireplace", 2, 3, true)
	for t in [[5, 6], [10, 6], [5, 9], [10, 9]]:
		_prop("long_table", t[0], t[1], true)
	for b in [[4, 5], [6, 5], [9, 5], [11, 5], [4, 8], [6, 8]]:
		_prop("bench", b[0], b[1])
	_prop("barrels", 16, 6)
	_point("fn_tavern", "Odo — order a meal for two", 13, 2,
		"res://data/dialogue/vael_odo.json", "odo")
	_door(9, 11, "vael_riverside", 6, 9, "◀ The Riverside")
	_save()


func _chantry() -> void:
	_new_room("vael_chantry", "The Grand Chantry — Nave", 16, 14)
	_prop("altar", 7, 3, true)
	for y in [6, 8, 10]:
		_prop("pew", 4, y, true)
		_prop("pew", 10, y, true)
	for c in [[2, 3], [12, 3]]:
		ch.set_terrain(c[0], c[1], T.CARPET)
	_point("chantry_candles", "Light a candle", 4, 4,
		"res://data/dialogue/vael_candles.json")
	_point("chantry_scripture", "Read the carved scripture", 11, 4,
		"res://data/dialogue/vael_scripture.json")
	_point("enna_chat", "Speak with Prioress Enna", 8, 4,
		"res://data/dialogue/vael_enna.json", "enna")
	_door(7, 13, "vael_cathedral", 11, 10, "◀ Chantry Square")
	_save()


## The exterior fn points become DOORS into the interiors.
func _rewire_exteriors() -> void:
	# market: drop the three fn points, add three doors at the shopfronts
	var m: CastleRoomDef = load("res://data/castle_v2/vael_market.tres")
	for pt: CastlePoint in m.points.duplicate():
		if pt.id.begins_with("fn_shop_"):
			m.points.erase(pt)
	var has := {}
	for d in m.doors:
		has[d.to_room] = true
	var mch: ChapterDef = m.chapter
	for spec in [[5, 7, "vael_smithy", "The Smithy"], [13, 7, "vael_goods_shop", "Reach & Barrel"],
			[21, 7, "vael_magic_shop", "The Arcane Bookshop"]]:
		if has.has(spec[2]):
			continue
		mch.set_terrain(spec[0], spec[1], Terrain.Type.PATH)
		var d := CastleDoor.new()
		d.cell = Vector2i(spec[0], spec[1])
		d.to_room = str(spec[2])
		d.spawn_cell = Vector2i(7, 8)
		d.label = str(spec[3])
		m.doors.append(d)
	print("market err=%d" % ResourceSaver.save(m, "res://data/castle_v2/vael_market.tres"))
	# riverside: fn_tavern point -> a door into the taproom
	var r: CastleRoomDef = load("res://data/castle_v2/vael_riverside.tres")
	for pt: CastlePoint in r.points.duplicate():
		if pt.id == "fn_tavern":
			r.points.erase(pt)
	var rhas := false
	for d in r.doors:
		if d.to_room == "vael_tavern":
			rhas = true
	if not rhas:
		r.chapter.set_terrain(6, 8, Terrain.Type.PATH)
		var d := CastleDoor.new()
		d.cell = Vector2i(6, 8)
		d.to_room = "vael_tavern"
		d.spawn_cell = Vector2i(9, 10)
		d.label = "The Gilded Stag"
		r.doors.append(d)
	print("riverside err=%d" % ResourceSaver.save(r, "res://data/castle_v2/vael_riverside.tres"))
	# cathedral square: candle/scripture move inside; a door into the nave
	var c: CastleRoomDef = load("res://data/castle_v2/vael_cathedral.tres")
	for pt: CastlePoint in c.points.duplicate():
		if pt.id in ["chantry_candles", "chantry_scripture"]:
			c.points.erase(pt)
	var chas := false
	for d in c.doors:
		if d.to_room == "vael_chantry":
			chas = true
	if not chas:
		c.chapter.set_terrain(11, 9, Terrain.Type.PATH)
		var d := CastleDoor.new()
		d.cell = Vector2i(11, 9)
		d.to_room = "vael_chantry"
		d.spawn_cell = Vector2i(7, 12)
		d.label = "Enter the Chantry"
		c.doors.append(d)
	print("cathedral err=%d" % ResourceSaver.save(c, "res://data/castle_v2/vael_cathedral.tres"))
