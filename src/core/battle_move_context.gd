class_name BattleMoveContext
extends Pathfinder.MoveContext
## Concrete MoveContext binding the pure Pathfinder to a chapter's terrain, a unit's
## movement type, and current occupancy. Kept dependency-light: it takes a plain
## occupancy dictionary rather than reaching into Unit nodes, so it stays testable.

var _chapter: ChapterDef
var _terrain_db: TerrainDB
var _movement_type: ClassDef.MovementType
## Vector2i cell -> team int. Enemy-occupied cells block movement; the moving
## unit's own cell and allied cells are passable but not stoppable (caller filters).
var _occupancy: Dictionary
var _mover_team: int


func _init(
	chapter: ChapterDef,
	terrain_db: TerrainDB,
	movement_type: ClassDef.MovementType,
	occupancy: Dictionary = {},
	mover_team: int = 0,
) -> void:
	_chapter = chapter
	_terrain_db = terrain_db
	_movement_type = movement_type
	_occupancy = occupancy
	_mover_team = mover_team


func in_bounds(cell: Vector2i) -> bool:
	return _chapter.in_bounds(cell.x, cell.y)


func enter_cost(cell: Vector2i) -> int:
	var type := _chapter.get_terrain(cell.x, cell.y)
	var info := _terrain_db.get_info(type)
	if info == null or info.impassable:
		return Pathfinder.INF_COST
	if info.blocks_armored_mounted and _is_rough_blocked():
		return Pathfinder.INF_COST
	return info.move_cost


## Enemy units block passage; own/allied units do not (they can be moved through).
func is_blocked(cell: Vector2i) -> bool:
	if not _occupancy.has(cell):
		return false
	return int(_occupancy[cell]) != _mover_team


## True if a reachable cell may be stopped on: unoccupied, or occupied only by the
## mover itself. Allied-occupied cells are passable but not valid stopping points.
func can_stop_on(cell: Vector2i, origin: Vector2i) -> bool:
	if cell == origin:
		return true
	return not _occupancy.has(cell)


func _is_rough_blocked() -> bool:
	return (
		_movement_type == ClassDef.MovementType.ARMORED
		or _movement_type == ClassDef.MovementType.MOUNTED
	)
