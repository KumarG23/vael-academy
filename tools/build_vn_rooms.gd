extends SceneTree
## AW-78: the three prologue VN backdrops as rooms — Oakstead's deep forest,
## the plain cave, and the sanctum. They live in data/vn_rooms/ (NOT castle_v2,
## so the castle's door-graph and terrain-guard tests never see them); the
## backdrop renderer injects them into a castle scene, hides the avatar, and
## screenshots. Composed for a 16:9 frame, dressed for mood, not for walking.

const T := Terrain.Type
var ch: ChapterDef
var room: CastleRoomDef


func _fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(max(0, y0), min(ch.height, y1 + 1)):
		for x in range(max(0, x0), min(ch.width, x1 + 1)):
			ch.set_terrain(x, y, t)


func _prop(name: String, x: int, y: int) -> void:
	var path := "res://assets/art/pixellab/props/%s.png" % name
	if not ResourceLoader.exists(path):
		push_warning("missing prop: " + name); return
	var d := MapDecor.new()
	d.texture = load(path); d.cell = Vector2i(x, y)
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	ch.decor.append(d)


func _start(id: String, disp: String, w: int, h: int, base: int) -> void:
	ch = ChapterDef.new()
	ch.id = id; ch.display_name = disp
	ch.base_terrain = base; ch.width = w; ch.height = h; ch.fill(base)
	room = CastleRoomDef.new()
	room.id = id; room.display_name = disp; room.chapter = ch


func _save(fname: String) -> void:
	print("%s err=%d decor=%d" % [fname, ResourceSaver.save(room, "res://data/vn_rooms/%s.tres" % fname), ch.decor.size()])


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/vn_rooms"))
	_forest(); _cave(); _sanctum()
	quit()


## Scene 1: deep woods, late afternoon — dense, layered, a place someone loves.
func _forest() -> void:
	_start("vn_forest", "The Deep Woods", 20, 12, T.PLAINS)
	_fill(0, 0, 19, 1, T.FOREST); _fill(0, 10, 19, 11, T.FOREST)
	_fill(0, 0, 1, 11, T.FOREST); _fill(18, 0, 19, 11, T.FOREST)
	# a faint foraging trail wandering through
	_fill(2, 6, 8, 7, T.PATH); _fill(8, 5, 13, 6, T.PATH); _fill(13, 4, 17, 5, T.PATH)
	# layered treeline — big canopies behind, variety in front
	for p in [["tree_big", 2, 3], ["pine_tree", 5, 2], ["tree_big", 8, 3], ["pine_tree", 12, 2],
			["tree_big", 15, 3], ["pine_tree", 18, 3], ["blossom_tree", 3, 9], ["tree_big", 7, 10],
			["pine_tree", 10, 9], ["tree_big", 13, 10], ["willow_tree", 17, 9], ["dead_tree", 4, 5],
			["pine_tree", 15, 7], ["tree_big", 19, 6]]:
		_prop(p[0], p[1], p[2])
	for p in [["fern_bush", 6, 8], ["fern_bush", 11, 7], ["mushrooms_glow", 9, 8],
			["flowers_wild", 4, 7], ["flowers_wild", 14, 8], ["fern_bush", 16, 4], ["rocks", 12, 8]]:
		_prop(p[0], p[1], p[2])
	_save("vn_forest")


## Scene 2a: inside the cave — dark stone, one throat of light behind.
func _cave() -> void:
	_start("vn_cave", "The Old Cave", 20, 12, T.FLOOR)
	# rough walls pressing in from every side
	_fill(0, 0, 19, 1, T.WALL); _fill(0, 10, 19, 11, T.WALL)
	_fill(0, 0, 2, 11, T.WALL); _fill(17, 0, 19, 11, T.WALL)
	_fill(3, 2, 5, 3, T.WALL); _fill(14, 8, 16, 9, T.WALL); _fill(4, 8, 6, 9, T.WALL)
	_fill(13, 2, 15, 3, T.WALL)
	for p in [["rocks", 7, 3], ["rocks", 12, 8], ["rocks", 5, 6], ["rocks", 15, 5], ["rubble", 9, 9], ["rubble", 11, 3]]:
		_prop(p[0], p[1], p[2])
	_save("vn_cave")


## Scene 2b: the sanctum — a round dark chamber, the core hanging at its heart.
func _sanctum() -> void:
	_start("vn_sanctum", "The Sanctum", 20, 12, T.FLOOR)
	_fill(0, 0, 19, 0, T.WALL); _fill(0, 11, 19, 11, T.WALL)
	_fill(0, 0, 1, 11, T.WALL); _fill(18, 0, 19, 11, T.WALL)
	# corner masses to round the chamber
	_fill(2, 1, 4, 2, T.WALL); _fill(15, 1, 17, 2, T.WALL)
	_fill(2, 9, 4, 10, T.WALL); _fill(15, 9, 17, 10, T.WALL)
	# (the core itself is drawn by the render rig, unmodulated, so its
	# hearthlight burns through the room's darkness)
	# a ring of old stones around it
	for p in [[6, 4], [12, 4], [6, 8], [12, 8], [9, 3], [9, 9]]:
		_prop("rocks", p[0], p[1])
	for p in [[7, 6], [11, 6]]:
		_prop("mushrooms_glow", p[0], p[1])
	_save("vn_sanctum")
