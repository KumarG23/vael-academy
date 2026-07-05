class_name TerrainDB
extends Resource
## Maps terrain types to their movement/combat modifiers.
##
## The default table is the authoritative §3 terrain data. Numbers are the genre:
## implement exactly here, tune later via a saved .tres, not by editing formulas.

## Terrain.Type (int) -> TerrainInfo.
@export var entries: Dictionary = {}


## Builds the §3 terrain table. This is the single source of terrain numbers.
static func create_default() -> TerrainDB:
	var db := TerrainDB.new()
	db.entries = {
		Terrain.Type.PLAINS: TerrainInfo.new("Plains", 1, 0, 0),
		Terrain.Type.FOREST: TerrainInfo.new("Forest", 2, 1, 20),
		Terrain.Type.MOUNTAIN: TerrainInfo.new("Mountain", 4, 2, 30, false, 0.0, true),
		Terrain.Type.FORT: TerrainInfo.new("Fort", 2, 2, 20, false, 0.10, false),
		Terrain.Type.WALL: TerrainInfo.new("Wall", 0, 0, 0, true),
		Terrain.Type.WATER: TerrainInfo.new("Water", 0, 0, 0, true),
		Terrain.Type.PATH: TerrainInfo.new("Road", 1, 0, 0),
		Terrain.Type.FLOOR: TerrainInfo.new("Floor", 1, 0, 0),
		Terrain.Type.PILLAR: TerrainInfo.new("Pillar", 2, 1, 20),
		Terrain.Type.CARPET: TerrainInfo.new("Carpet", 1, 0, 0),
		Terrain.Type.SPRING: TerrainInfo.new("Healing Spring", 1, 0, 10, false, 0.15),
		Terrain.Type.FLOWERS: TerrainInfo.new("Meadow", 1, 0, 0),
		Terrain.Type.SITE: TerrainInfo.new("Village", 0, 0, 0, true),
	}
	return db


func get_info(type: Terrain.Type) -> TerrainInfo:
	return entries.get(type, null)


func move_cost(type: Terrain.Type) -> int:
	var info: TerrainInfo = entries.get(type, null)
	return info.move_cost if info != null else 1


func defense(type: Terrain.Type) -> int:
	var info: TerrainInfo = entries.get(type, null)
	return info.defense if info != null else 0


func avoid(type: Terrain.Type) -> int:
	var info: TerrainInfo = entries.get(type, null)
	return info.avoid if info != null else 0


func is_impassable(type: Terrain.Type) -> bool:
	var info: TerrainInfo = entries.get(type, null)
	return info.impassable if info != null else true
