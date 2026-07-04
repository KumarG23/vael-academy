class_name ChapterDef
extends Resource
## A chapter's map data. WO-0.2 scope: grid dimensions + logical terrain layer
## + optional backdrop. Objectives, deployed units, and dialogue attach in later
## work orders (WO-1.4, WO-4.1).

## Victory condition for the chapter (§6). ROUT: defeat every enemy. SEIZE: the
## lord occupies `seize_cell`. DEFEAT_BOSS: the unit with `boss_unit_id` falls
## (a full rout also wins — it necessarily includes the boss).
## Persisted in saves — append only, never renumber.
enum Objective { ROUT, SEIZE, DEFEAT_BOSS }

@export var id: String = ""
@export var display_name: String = ""
@export var objective: Objective = Objective.ROUT
## Tile the lord must seize for a SEIZE objective (ignored for ROUT).
@export var seize_cell: Vector2i = Vector2i(-1, -1)
## Unit id of the boss for a DEFEAT_BOSS objective (e.g. "serra").
@export var boss_unit_id: String = ""
## Non-lethal chapter (WO-4.1 Mock Battle): defeated units yield and retreat —
## flagged defeated, never permadead. Lord fall still loses the chapter.
@export var non_lethal: bool = false

@export_group("Forces (WO-4.1)")
## Authored enemy force. Empty => the battle scene's legacy demo spawn is used.
@export var enemy_spawns: Array[UnitSpawn] = []
## Player deploy cells keyed by unit id. Empty => Roster.deploy_cells() fallback.
@export var deploy_cells: Dictionary[String, Vector2i] = {}

@export_group("Dialogue (WO-4.1)")
## JSON dialogue paths (§4). "" => skipped.
@export var intro_dialogue: String = ""
@export var outro_dialogue: String = ""
## Plays once, the first time the boss enters combat.
@export var boss_quote_dialogue: String = ""
## Plays when the boss is defeated (yields), before the outro.
@export var boss_yield_dialogue: String = ""
@export var width: int = 20
@export var height: int = 15
## Row-major terrain grid, length == width * height, each value a Terrain.Type.
@export var terrain: PackedInt32Array = PackedInt32Array()
## Painted battlefield backdrop (AW-2). Null => flat placeholder color.
@export var backdrop: Texture2D = null


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_terrain(x: int, y: int) -> Terrain.Type:
	return terrain[y * width + x] as Terrain.Type


## Fills the terrain grid with a single type (helper for authoring/tests).
func fill(type: Terrain.Type) -> void:
	terrain = PackedInt32Array()
	terrain.resize(width * height)
	terrain.fill(int(type))


func set_terrain(x: int, y: int, type: Terrain.Type) -> void:
	terrain[y * width + x] = int(type)


## Builds a Grid matching this chapter's dimensions.
func make_grid() -> Grid:
	return Grid.new(width, height)
