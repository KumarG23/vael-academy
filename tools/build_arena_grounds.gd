extends SceneTree
## AW-45: the Arena becomes its own themed sub-area (like the dorms), entered
## through a gate off the Training Grounds. Its centrepiece is the Trial Spire —
## a magic tower in all three house colours that glows green (PixelLab, replacing
## the scrapped colosseum). This tool:
##   1. builds the `arena_grounds` room (spire + forecourt + warden + gate back),
##   2. patches `training` with an east gate that leads here,
##   3. strips the old colosseum off the campus hub and greens over its footprint.

const T := Terrain.Type
var ch: ChapterDef
var room: CastleRoomDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(ch.height, y1 + 1)):
		for x in range(max(0, x0), min(ch.width, x1 + 1)):
			ch.set_terrain(x, y, t)


func _decor(path: String, x: int, y: int, solid := false) -> void:
	if not ResourceLoader.exists(path):
		push_warning("missing decor: " + path); return
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


func _door(cx: int, cy: int, to_room: String, sx: int, sy: int, label: String) -> void:
	ch.set_terrain(cx, cy, T.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(cx, cy); d.to_room = to_room
	d.spawn_cell = Vector2i(sx, sy); d.label = label
	room.doors.append(d)


func _point(id: String, label: String, x: int, y: int, dialogue := "", npc := "") -> void:
	var p := CastlePoint.new()
	p.id = id; p.label = label; p.cell = Vector2i(x, y)
	p.dialogue = dialogue; p.npc_unit = npc
	room.points.append(p)


func _new_room(id: String, disp: String, w: int, h: int, base: int) -> void:
	ch = ChapterDef.new()
	ch.id = "castle_" + id; ch.display_name = disp; ch.base_terrain = base
	ch.width = w; ch.height = h; ch.fill(base)
	room = CastleRoomDef.new()
	room.id = id; room.display_name = disp; room.chapter = ch


func _frame() -> void:
	_fill(0, 0, ch.width - 1, 1, T.FOREST); _fill(0, ch.height - 2, ch.width - 1, ch.height - 1, T.FOREST)
	_fill(0, 0, 1, ch.height - 1, T.FOREST); _fill(ch.width - 2, 0, ch.width - 1, ch.height - 1, T.FOREST)


func _initialize() -> void:
	_build_arena_grounds()
	_patch_training()
	_patch_campus()
	quit()


func _build_arena_grounds() -> void:
	_new_room("arena_grounds", "The Trial Spire", 22, 18, T.PLAINS)
	_frame()
	# a stone avenue up from the south gate to a paved forecourt at the tower's foot
	_fill(10, 13, 12, 16, T.PATH)
	_fill(8, 13, 14, 14, T.CARPET)
	# the Trial Spire (default art = spire_c; swap via the ` editor). It bottom-
	# anchors at row 12 and draws ~10 cells up, door facing south.
	_decor("res://assets/art/pixellab/buildings/arena_spire.png", 11, 12)
	for y in range(11, 13):        # the tower plinth is solid
		for x in range(9, 14):
			ch.set_terrain(x, y, T.SITE)
	ch.set_terrain(11, 13, T.PATH)  # but you can stand right at the door
	_point("fn_arena", "Enter the Trial Spire", 11, 13)
	# atmosphere — banners in the house colours, lamps, founder statues, a wood
	_prop("banner_pair", 8, 12); _prop("banner_pair", 14, 12)
	_prop("street_lamp", 8, 14); _prop("street_lamp", 14, 14)
	_prop("statue_founder", 5, 14, true); _prop("statue_founder", 17, 14, true)
	for tx in [[4, 4], [18, 4], [4, 10], [18, 10]]:
		_prop("tree_big", tx[0], tx[1], true)
	_prop("bench_stone", 9, 15); _prop("bench_stone", 13, 15)
	# the Trial Warden keeps the gate (dialogue is a draft for the co-write pass)
	_point("arena_warden", "The Trial Warden", 15, 15, "res://data/dialogue/arena_warden.json", "brenna")
	# the gate back to the Training Grounds
	_door(11, 17, "training", 18, 6, "◀ To the Training Grounds")
	print("arena_grounds err=%d doors=%d points=%d"
		% [ResourceSaver.save(room, "res://data/castle_v2/arena_grounds.tres"),
			room.doors.size(), room.points.size()])


func _patch_training() -> void:
	var p := "res://data/castle_v2/training.tres"
	if not ResourceLoader.exists(p):
		push_warning("no training.tres to patch"); return
	var rm: CastleRoomDef = load(p)
	var tch: ChapterDef = rm.chapter
	# already patched? don't stack a second gate
	for d in rm.doors:
		if d.to_room == "arena_grounds":
			print("training already routes to arena_grounds"); return
	# carve a corridor east to the new gate on the right edge (row 6)
	for x in range(13, tch.width):
		tch.set_terrain(x, 6, T.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(tch.width - 1, 6); d.to_room = "arena_grounds"
	d.spawn_cell = Vector2i(11, 15); d.label = "▶ The Trial Spire"
	rm.doors.append(d)
	# a signpost so the gate reads as "the arena is this way"
	var sp := CastlePoint.new()
	sp.id = "arena_sign"; sp.label = "To the Trial Spire"; sp.cell = Vector2i(tch.width - 3, 5)
	rm.points.append(sp)
	print("training patched err=%d" % ResourceSaver.save(rm, p))


func _patch_campus() -> void:
	var p := "res://data/castle_v2/campus.tres"
	if not ResourceLoader.exists(p):
		push_warning("no campus.tres to patch"); return
	var rm: CastleRoomDef = load(p)
	var cch: ChapterDef = rm.chapter
	# idempotency: the old colosseum layout is the only one with an fn_arena point.
	# Once that's gone the campus is already patched — don't stack a second garden.
	var has_old_arena := false
	for pt: CastlePoint in rm.points:
		if pt.id == "fn_arena":
			has_old_arena = true
	if not has_old_arena:
		print("campus already patched (no fn_arena point) — skipping")
		return
	# 1. drop the colosseum decor (erase in place — decor is a typed Array)
	for d: MapDecor in cch.decor.duplicate():
		if d.texture != null and d.texture.resource_path.contains("colosseum"):
			cch.decor.erase(d)
	# 2. green over its footprint (only the cells it had claimed as SITE)
	for y in range(23, 26):
		for x in range(7, 16):
			if cch.in_bounds(x, y) and cch.get_terrain(x, y) == T.SITE:
				cch.set_terrain(x, y, T.PLAINS)
	# 3. remove the old campus arena point
	for pt: CastlePoint in rm.points.duplicate():
		if pt.id == "fn_arena":
			rm.points.erase(pt)
	# 4. a small garden where it stood, so the lawn isn't bare
	for f in [[9, 24], [13, 24], [11, 25]]:
		cch.set_terrain(f[0], f[1], T.FLOWERS)
	_arena_campus_prop(cch, "tree_big", 8, 24, true)
	_arena_campus_prop(cch, "tree_big", 14, 24, true)
	_arena_campus_prop(cch, "bench_stone", 11, 26, false)
	print("campus patched err=%d decor=%d" % [ResourceSaver.save(rm, p), cch.decor.size()])


## campus decor helper (its own ChapterDef, not the tool's `ch`)
func _arena_campus_prop(cch: ChapterDef, name: String, x: int, y: int, solid: bool) -> void:
	var path := "res://assets/art/pixellab/props/%s.png" % name
	if not ResourceLoader.exists(path):
		return
	var d := MapDecor.new()
	d.texture = load(path); d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	cch.decor.append(d)
	if solid and cch.in_bounds(x, y):
		cch.set_terrain(x, y, T.SITE)
