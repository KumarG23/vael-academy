class_name Terrain
extends RefCounted
## Namespace for terrain type identifiers used across grid/combat systems.
##
## The numeric values are persisted in ChapterDef terrain arrays and saves —
## DO NOT reorder or renumber without a migration.

enum Type {
	PLAINS = 0,
	FOREST = 1,
	MOUNTAIN = 2,
	FORT = 3,
	WALL = 4,
	WATER = 5,
}
