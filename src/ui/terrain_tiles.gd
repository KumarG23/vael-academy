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

## Atlas set names per map base family (chapter.base_terrain, maps v2):
## field maps build on grass, indoor battles on stone floor. The base type
## itself has no overlay set — it IS the fill.
const SETS_BY_BASE := {
	Terrain.Type.PLAINS: {
		Terrain.Type.WATER: "grass_water",
		Terrain.Type.PATH: "grass_path",
		Terrain.Type.FOREST: "grass_forest",
		Terrain.Type.MOUNTAIN: "grass_mountain",
		Terrain.Type.FORT: "grass_fortstone",
		Terrain.Type.WALL: "grass_wall",
		Terrain.Type.FLOWERS: "grass_flowers",
	},
	Terrain.Type.FLOOR: {
		Terrain.Type.WATER: "floor_pool",
		Terrain.Type.CARPET: "floor_carpet",
		Terrain.Type.WALL: "floor_wall",
	},
}
## Pass order: ground washes (water/path/carpet) first, features next, walls
## last so they read as built ON the land.
const PASS_ORDER: Array = [Terrain.Type.WATER, Terrain.Type.PATH,
	Terrain.Type.FLOWERS, Terrain.Type.CARPET, Terrain.Type.FOREST,
	Terrain.Type.MOUNTAIN, Terrain.Type.FORT, Terrain.Type.WALL]
## Single-tile decor drawn on the cell after the wang passes (no wang set):
## type -> texture filename. The cell under it shows the base fill.
const DECOR_FOR_TERRAIN := {
	Terrain.Type.SPRING: "spring_tile.png",
	Terrain.Type.PILLAR: "pillar_tile.png",
}

var _grid: Grid
var _chapter: ChapterDef
var _atlases := {}      # set name -> Texture2D
var _wang := {}         # set name -> {sig(int) -> Vector2i(col,row)}
var _decor := {}        # Terrain.Type -> Texture2D
var _base_region: Rect2
var _base_set_name := ""
var _effect_time: float = 0.0


## When false, the authored scenery props (chapter.decor) are NOT drawn here —
## the owner draws them in a layer ABOVE its walls (the castle does this so
## furniture against a wall isn't hidden behind it). Terrain-feature decor
## (springs/pillars) still renders here.
var draw_props := true


func setup(grid: Grid, chapter: ChapterDef) -> void:
	_grid = grid
	_chapter = chapter
	_load_assets()
	texture_filter = TEXTURE_FILTER_NEAREST
	_effect_time = 0.0
	set_process(draw_props and _has_animated_props())
	queue_redraw()


func _has_animated_props() -> bool:
	if _chapter == null:
		return false
	for prop: MapDecor in _chapter.decor:
		if prop != null and prop.effect_texture_at(0.0) != null:
			return true
	return false


func _process(delta: float) -> void:
	if not draw_props:
		return
	_effect_time += delta
	queue_redraw()


func is_active() -> bool:
	return not _atlases.is_empty()


## Whether this terrain type is rendered by loaded art (wang atlas or decor
## tile) for this chapter's base family. Types without art keep the battle
## view's tint fallback (convention: code never waits on art).
func covers(t: int) -> bool:
	if t == _base_terrain() or t == Terrain.Type.SITE:
		return true  # SITE: invisible blocker — the prop IS its art
	if _decor.has(t):
		return true
	var sets: Dictionary = SETS_BY_BASE.get(_base_terrain(), {})
	return sets.has(t) and _atlases.has(sets[t])


func _base_terrain() -> int:
	return _chapter.base_terrain if _chapter != null else Terrain.Type.PLAINS


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
	_decor.clear()
	_wang = load_wang_maps(TILESET_DIR + "/wang_maps.json")
	if _wang.is_empty():
		return
	for set_name in _wang:
		var p := "%s/%s_atlas.png" % [TILESET_DIR, set_name]
		if ResourceLoader.exists(p):
			_atlases[set_name] = load(p)
	if _atlases.is_empty():
		return
	for t in DECOR_FOR_TERRAIN:
		var dp := "%s/%s" % [TILESET_DIR, DECOR_FOR_TERRAIN[t]]
		if ResourceLoader.exists(dp):
			_decor[t] = load(dp)
	# base fill = the all-base tile (sig 0 = no overlay) of the family's
	# first available set
	var base_set := ""
	for set_name in SETS_BY_BASE.get(_base_terrain(), {}).values():
		if _atlases.has(set_name):
			base_set = set_name
			break
	if base_set == "":
		_atlases.clear()  # no art for this base family -> full tint fallback
		return
	var pos: Vector2i = _wang[base_set][0]
	_base_region = Rect2(pos.x * TILE, pos.y * TILE, TILE, TILE)
	_base_set_name = base_set


func _draw() -> void:
	if _grid == null or _chapter == null or not is_active():
		return
	var cs := float(_grid.cell_size)
	var base_tex: Texture2D = _atlases[_base_set_name]
	# base fill (grass or floor), cell-aligned
	for y in range(_chapter.height):
		for x in range(_chapter.width):
			draw_texture_rect_region(base_tex,
				Rect2(x * cs, y * cs, cs, cs), _base_region)
	# overlay passes on the dual grid (junctions: (width+1) x (height+1)),
	# each drawn tile offset by -half a cell so corners meet cell centers
	var sets: Dictionary = SETS_BY_BASE.get(_base_terrain(), {})
	for overlay in PASS_ORDER:
		var set_name: String = sets.get(overlay, "")
		if set_name == "" or not _atlases.has(set_name):
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
	# decor pass: single-tile terrain features (springs, pillars) on the base
	# fill, then authored scenery props (maps v3) — all sorted by anchor row so
	# lower items overlap upper ones naturally. Taller-than-a-tile decor keeps
	# its base on the cell and rises above it.
	var items: Array = []
	for y in range(_chapter.height):
		for x in range(_chapter.width):
			var t := _chapter.get_terrain(x, y)
			if _decor.has(t):
				items.append({"tex": _decor[t], "cell": Vector2i(x, y), "off": Vector2.ZERO})
	if draw_props:
		for d in _chapter.decor:
			if d != null and d.texture != null:
				items.append({"tex": d.texture, "cell": d.cell, "off": d.offset, "prop": d})
	items.sort_custom(func(a, b): return a["cell"].y < b["cell"].y)
	for it in items:
		var tex: Texture2D = it["tex"]
		var cell: Vector2i = it["cell"]
		var scale := cs / float(TILE)
		var w := tex.get_width() * scale
		var h := tex.get_height() * scale
		draw_texture_rect(tex, Rect2(cell.x * cs + (cs - w) * 0.5 + it["off"].x,
			cell.y * cs + cs - h + it["off"].y, w, h), false)

		if it.has("prop"):
			var prop: MapDecor = it["prop"]
			var effect: Texture2D = prop.effect_texture_at(_effect_time)
			if effect != null:
				var anchor := Vector2(cell.x * cs + cs * 0.5, cell.y * cs + cs) + prop.offset
				draw_texture_rect(effect, Rect2(anchor + prop.effect_offset * scale,
					effect.get_size() * scale), false)
