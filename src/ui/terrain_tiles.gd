class_name TerrainTiles
extends Node2D
## AW-2a: pixel Wang-tile terrain rendering (the hybrid maps doctrine's
## battlefield half). Presentation only — reads the chapter's terrain grid,
## owns no game state. Convention-based like the sprite hook: renders when
## the atlases exist under assets/art/pixellab/tilesets/, otherwise stays
## inactive and the battle view's tint fallback shows.
##
## Dual-grid corner Wang: each drawn 32px tile sits on a cell-corner
## junction (offset half a cell) and is picked by which of its four
## corners touch the overlay terrain. Draw order: base grass everywhere,
## then one pass per overlay terrain type. Any overlay whose atlas is
## missing keeps the battle view's tint fallback (see `covers`).

const TILESET_DIR := "res://assets/art/pixellab/tilesets"
const TILE := 32

## Terrain.Type -> atlas set name (PLAINS intentionally absent: it's the base).
const SET_FOR_TERRAIN := {
	Terrain.Type.WATER: "grass_water",
	Terrain.Type.FOREST: "grass_forest",
	Terrain.Type.MOUNTAIN: "grass_mountain",
	Terrain.Type.FORT: "grass_fortstone",
	Terrain.Type.WALL: "grass_wall",
}
## Pass order: water first so land features overlap shorelines, not vice versa;
## walls last so they read as built ON the land.
const PASS_ORDER: Array = [Terrain.Type.WATER, Terrain.Type.FOREST,
	Terrain.Type.MOUNTAIN, Terrain.Type.FORT, Terrain.Type.WALL]

var _grid: Grid
var _chapter: ChapterDef
var _atlases := {}      # set name -> Texture2D
var _wang := {}         # set name -> {sig(int) -> Vector2i(col,row)}
var _grass_region: Rect2


func setup(grid: Grid, chapter: ChapterDef) -> void:
	_grid = grid
	_chapter = chapter
	_load_assets()
	texture_filter = TEXTURE_FILTER_NEAREST
	queue_redraw()


func is_active() -> bool:
	return not _atlases.is_empty()


## Whether this terrain type is rendered by a loaded atlas. Types without art
## keep the battle view's tint fallback (convention: code never waits on art).
func covers(t: int) -> bool:
	return SET_FOR_TERRAIN.has(t) and _atlases.has(SET_FOR_TERRAIN[t])


static func load_wang_maps(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for set_name in raw:
		var m := {}
		for sig in raw[set_name]:
			var pos: Array = raw[set_name][sig]
			m[int(sig)] = Vector2i(int(pos[0]), int(pos[1]))
		out[set_name] = m
	return out


## Corner signature for the junction whose NW logical cell is (x-1, y-1):
## bit 1=NW, 2=NE, 4=SW, 8=SE set when that cell's terrain == overlay.
## Out-of-bounds cells count as not-overlay.
static func junction_signature(chapter: ChapterDef, x: int, y: int, overlay: int) -> int:
	var sig := 0
	var cells := [
		[Vector2i(x - 1, y - 1), 1], [Vector2i(x, y - 1), 2],
		[Vector2i(x - 1, y), 4], [Vector2i(x, y), 8],
	]
	for c in cells:
		var p: Vector2i = c[0]
		if p.x >= 0 and p.y >= 0 and p.x < chapter.width and p.y < chapter.height:
			if chapter.get_terrain(p.x, p.y) == overlay:
				sig |= c[1]
	return sig


func _load_assets() -> void:
	_atlases.clear()
	_wang = load_wang_maps(TILESET_DIR + "/wang_maps.json")
	if _wang.is_empty():
		return
	for set_name in _wang:
		var p := "%s/%s_atlas.png" % [TILESET_DIR, set_name]
		if ResourceLoader.exists(p):
			_atlases[set_name] = load(p)
	if _atlases.is_empty():
		return
	# base grass = the all-grass tile of the forest set (sig 0 = no overlay)
	var grass_pos: Vector2i = _wang["grass_forest"][0]
	_grass_region = Rect2(grass_pos.x * TILE, grass_pos.y * TILE, TILE, TILE)


func _draw() -> void:
	if _grid == null or _chapter == null or not is_active():
		return
	var cs := float(_grid.cell_size)
	var scale := cs / float(TILE)
	var grass_tex: Texture2D = _atlases.get("grass_forest",
		_atlases[_atlases.keys()[0]])
	# base grass fill, cell-aligned
	for y in range(_chapter.height):
		for x in range(_chapter.width):
			draw_texture_rect_region(grass_tex,
				Rect2(x * cs, y * cs, cs, cs), _grass_region)
	# overlay passes on the dual grid (junctions: (width+1) x (height+1)),
	# each drawn tile offset by -half a cell so corners meet cell centers
	for overlay in PASS_ORDER:
		var set_name: String = SET_FOR_TERRAIN[overlay]
		if not _atlases.has(set_name):
			continue
		var tex: Texture2D = _atlases[set_name]
		var wmap: Dictionary = _wang[set_name]
		var map_rect := Rect2(Vector2.ZERO, _grid.pixel_size())
		for jy in range(_chapter.height + 1):
			for jx in range(_chapter.width + 1):
				var sig := junction_signature(_chapter, jx, jy, overlay)
				if sig == 0:
					continue
				var pos: Vector2i = wmap[sig]
				var dest := Rect2(jx * cs - cs * 0.5, jy * cs - cs * 0.5, cs, cs)
				var src := Rect2(pos.x * TILE, pos.y * TILE, TILE, TILE)
				# clip border junctions to the map rect (src trimmed to match)
				var clipped := dest.intersection(map_rect)
				if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
					continue
				if clipped != dest:
					var fx := (clipped.position.x - dest.position.x) / dest.size.x
					var fy := (clipped.position.y - dest.position.y) / dest.size.y
					src = Rect2(src.position.x + fx * TILE, src.position.y + fy * TILE,
						src.size.x * clipped.size.x / dest.size.x,
						src.size.y * clipped.size.y / dest.size.y)
				draw_texture_rect_region(tex, clipped, src)
