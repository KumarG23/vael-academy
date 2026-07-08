extends SceneTree
## AW-46: the Sealed Grove was rendering GREY — its base terrain was FOREST, but
## the tile renderer only has atlases for PLAINS and FLOOR bases (SETS_BY_BASE),
## so a FOREST-based room draws no grass and no overlays. Fix: rebuild the grove
## on a GRASS (PLAINS) base with FOREST painted as an overlay (grass_forest wang),
## then fill it with life — varied trees, wildflower meadows, glowing mushrooms,
## ferns — and a colossal pulsing world-tree (the Wardtree) at its sacred heart.

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
		push_warning("missing prop: " + name); return
	var d := MapDecor.new()
	d.texture = load(path); d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)
	if solid and ch.in_bounds(x, y):
		ch.set_terrain(x, y, T.SITE)


func _point(id: String, label: String, x: int, y: int, dialogue := "") -> void:
	var p := CastlePoint.new()
	p.id = id; p.label = label; p.cell = Vector2i(x, y); p.dialogue = dialogue
	room.points.append(p)


func _initialize() -> void:
	_build_grove()
	quit()


func _build_grove() -> void:
	ch = ChapterDef.new()
	ch.id = "castle_grove"; ch.display_name = "The Sealed Grove"
	ch.base_terrain = T.PLAINS          # GRASS base — the fix for the grey floor
	ch.width = 26; ch.height = 24; ch.fill(T.PLAINS)
	room = CastleRoomDef.new()
	room.id = "grove"; room.display_name = "The Sealed Grove"; room.chapter = ch

	# a dense wooded ring painted as FOREST overlay (grass_forest wang carpet)
	_fill(0, 0, 25, 2, T.FOREST); _fill(0, 20, 25, 23, T.FOREST)
	_fill(0, 0, 2, 23, T.FOREST); _fill(23, 0, 25, 23, T.FOREST)
	# a soft winding path in from the top gate down to the sacred heart
	_fill(9, 1, 10, 12, T.PATH)
	_fill(7, 12, 18, 13, T.PATH)
	# the central sacred clearing (grass) where the Wardtree stands
	_fill(8, 9, 17, 19, T.PLAINS)
	# wildflower meadows scattered through the wood-edges
	for m in [[4, 5, 6, 8], [19, 5, 21, 8], [4, 15, 6, 18], [19, 15, 21, 18], [11, 6, 14, 8]]:
		_fill(m[0], m[1], m[2], m[3], T.FLOWERS)

	# --- the wooded ring: a real mix of trees (Neal's ask) ---
	var trees := [
		["pine_tree", 3, 2], ["magic_tree", 6, 2], ["blossom_tree", 14, 2],
		["pine_tree", 18, 2], ["tree_big", 21, 2],
		["willow_tree", 2, 6], ["pine_tree", 2, 11], ["dead_tree", 2, 16],
		["tree_big", 23, 6], ["magic_tree", 23, 11], ["pine_tree", 23, 17],
		["blossom_tree", 4, 21], ["willow_tree", 9, 22], ["pine_tree", 16, 22],
		["dead_tree", 21, 21], ["magic_tree", 6, 19],
	]
	for t in trees:
		_prop(t[0], t[1], t[2], true)

	# --- undergrowth: flowers, glowing mushrooms, ferns (the "and stuff") ---
	var foliage := [
		["flowers_wild", 5, 6], ["flowers_wild", 20, 6], ["flowers_wild", 5, 16],
		["flowers_wild", 20, 16], ["flowers_wild", 12, 7], ["flowers_wild", 15, 6],
		["fern_bush", 7, 10], ["fern_bush", 18, 11], ["fern_bush", 8, 18],
		["fern_bush", 17, 18], ["fern_bush", 5, 12],
		["mushrooms_glow", 10, 17], ["mushrooms_glow", 15, 17], ["mushrooms_glow", 9, 8],
		["mushrooms_glow", 16, 8], ["bush", 7, 6], ["bush", 19, 19], ["stump", 6, 15],
	]
	for f in foliage:
		_prop(f[0], f[1], f[2], false)

	# --- the heart: the colossal pulsing Wardtree (glow added in castle_scene) ---
	_prop("great_wardtree", 12, 16, false)
	for y in range(15, 17):        # its trunk is solid
		for x in range(11, 15):
			ch.set_terrain(x, y, T.SITE)
	# the First Crown stone nestled in its roots (the lore point)
	_prop("rocks", 12, 18, true)
	_point("first_crown_stone", "The First Crown Stone", 13, 18,
		"res://data/dialogue/lore_wardstones.json")
	# a ring of light at the tree's feet
	for mg in [[10, 18], [14, 18], [9, 16], [16, 16]]:
		_prop("mushrooms_glow", mg[0], mg[1], false)

	# the gate back to the campus (unchanged: campus spawns you at row 2)
	ch.set_terrain(9, 1, T.PATH)
	var d := CastleDoor.new()
	d.cell = Vector2i(9, 1); d.to_room = "campus"
	d.spawn_cell = Vector2i(6, 27); d.label = "◀ To the Campus"
	room.doors.append(d)
	print("grove err=%d decor=%d" % [ResourceSaver.save(room, "res://data/castle_v2/grove.tres"), ch.decor.size()])
